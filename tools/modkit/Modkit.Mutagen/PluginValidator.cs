using System.Text.Json;
using Mutagen.Bethesda;
using Mutagen.Bethesda.Plugins;
using Mutagen.Bethesda.Plugins.Records;
using Mutagen.Bethesda.Skyrim;

namespace Modkit.Mutagen;

/// <summary>
/// Re-reads a written plugin from disk and checks what can be checked without
/// the game: record counts, FormID ranges for ESL, unique EditorIDs, masters,
/// unresolved links, and every script attachment against the Papyrus sources.
/// </summary>
public static class PluginValidator
{
    /// <param name="expectedUnfilled">
    /// Script properties that are left unfilled on purpose, as "EditorID:Script.Property".
    /// They are reported as expected instead of as warnings; stale entries are warned about.
    /// </param>
    /// <summary>The vanilla script type a script attached to this record must extend.</summary>
    private static string[] ExpectedScriptBases(IMajorRecordGetter r) => r switch
    {
        IQuestGetter => new[] { "Quest" },
        IMagicEffectGetter => new[] { "ActiveMagicEffect" },
        INpcGetter => new[] { "Actor", "ObjectReference" },
        IPerkGetter => new[] { "Perk" },
        IDialogResponsesGetter => new[] { "TopicInfo" },
        _ => new[] { "ObjectReference" }, // books, armor, weapons, misc items, containers, activators ...
    };

    public static int Validate(string pluginPath, PapyrusIndex papyrus, IReadOnlySet<ModKey> allowedMasters, string reportPath,
        IReadOnlySet<string>? expectedUnfilled = null, IReadOnlyList<ISkyrimModGetter>? masterPlugins = null)
    {
        var errors = new List<string>();
        var warnings = new List<string>();
        var expected = new List<string>();
        var unusedExpected = new HashSet<string>(expectedUnfilled ?? new HashSet<string>(), StringComparer.OrdinalIgnoreCase);
        using var mod = SkyrimMod.CreateFromBinaryOverlay(pluginPath, SkyrimRelease.SkyrimSE);
        var records = mod.EnumerateMajorRecords().ToList();
        var own = records.Where(r => r.FormKey.ModKey == mod.ModKey).ToList();
        var overrides = records.Count - own.Count;

        bool esl = mod.ModHeader.Flags.HasFlag(SkyrimModHeader.HeaderFlag.Small);
        if (esl)
        {
            if (own.Count > 2048) errors.Add($"ESL flag set but {own.Count} new records (max 2048)");
            foreach (var r in own.Where(r => r.FormKey.ID < 0x800 || r.FormKey.ID > 0xFFF))
                errors.Add($"ESL FormID out of range: {r.EditorID} {r.FormKey}");
        }

        foreach (var dup in own.GroupBy(r => r.EditorID ?? "").Where(g => g.Count() > 1))
            errors.Add($"duplicate EditorID '{dup.Key}' x{dup.Count()}");
        foreach (var r in own.Where(r => string.IsNullOrEmpty(r.EditorID)))
            errors.Add($"record without EditorID: {r.FormKey}");

        var masters = mod.ModHeader.MasterReferences.Select(m => m.Master).ToList();
        foreach (var m in masters.Where(m => !allowedMasters.Contains(m)))
            errors.Add($"unexpected master: {m}");

        var ownKeys = own.Select(r => r.FormKey).ToHashSet();
        // Masters whose files are at hand (not Skyrim.esm): every link into them must resolve to a
        // record of a fitting type in that very file.
        var masterRecords = new Dictionary<FormKey, IMajorRecordGetter>();
        foreach (var mm in masterPlugins ?? Array.Empty<ISkyrimModGetter>())
        {
            if (!masters.Contains(mm.ModKey)) warnings.Add($"master file {mm.ModKey} was supplied but is not a master of the plugin");
            foreach (var r in mm.EnumerateMajorRecords().Where(r => r.FormKey.ModKey == mm.ModKey)) masterRecords[r.FormKey] = r;
        }
        var checkedMasters = (masterPlugins ?? Array.Empty<ISkyrimModGetter>()).Select(m => m.ModKey).ToHashSet();
        int links = 0, masterLinks = 0;
        foreach (var r in records)
        {
            foreach (var l in r.EnumerateFormLinks())
            {
                if (l.IsNull) continue;
                links++;
                var mk = l.FormKey.ModKey;
                if (mk == mod.ModKey && !ownKeys.Contains(l.FormKey))
                    errors.Add($"{r.EditorID}: dangling link to {l.FormKey}");
                else if (mk != mod.ModKey && !masters.Contains(mk))
                    errors.Add($"{r.EditorID}: link to {l.FormKey} whose plugin is not a master");
                else if (checkedMasters.Contains(mk))
                {
                    masterLinks++;
                    if (!masterRecords.TryGetValue(l.FormKey, out var target))
                        errors.Add($"{r.EditorID}: link to {l.FormKey}, which does not exist in {mk}");
                    else if (!l.Type.IsAssignableFrom(target.GetType()))
                        errors.Add($"{r.EditorID}: link to {target.EditorID} ({l.FormKey}) expects {l.Type.Name}, found {target.GetType().Name}");
                }
            }
        }

        int scripts = 0, props = 0;
        void CheckScripts(IMajorRecordGetter owner, IEnumerable<IScriptEntryGetter> entries, string[] allowedBases, string? where = null)
        {
            foreach (var s in entries)
            {
                scripts++;
                if (!papyrus.HasScript(s.Name)) { errors.Add($"{owner.EditorID}: script '{s.Name}' has no .psc source"); continue; }
                var vbase = papyrus.VanillaBase(s.Name);
                if (vbase == null || !allowedBases.Contains(vbase, StringComparer.OrdinalIgnoreCase))
                    errors.Add($"{owner.EditorID}{where}: script '{s.Name}' extends {vbase ?? "nothing"}, expected {string.Join(" or ", allowedBases)}");
                var filled = s.Properties.Select(p => p.Name).ToHashSet(StringComparer.OrdinalIgnoreCase);
                foreach (var decl in papyrus.Properties(s.Name).Where(d => !d.HasDefault && !filled.Contains(d.Name)))
                {
                    var key = $"{owner.EditorID}:{s.Name}.{decl.Name}";
                    if (unusedExpected.Remove(key)) expected.Add(key);
                    else warnings.Add($"{owner.EditorID}: {s.Name}.{decl.Name} is declared but not filled (None/0 at runtime)");
                }
                foreach (var p in s.Properties)
                {
                    props++;
                    var decl = papyrus.GetProperty(s.Name, p.Name);
                    if (decl == null) { errors.Add($"{owner.EditorID}: {s.Name}.{p.Name} is not declared in the source"); continue; }
                    var t = decl.Type.ToLowerInvariant();
                    bool ok = p switch
                    {
                        IScriptObjectListPropertyGetter => decl.IsArray && t is not ("int" or "float" or "bool" or "string"),
                        IScriptObjectPropertyGetter => !decl.IsArray && t is not ("int" or "float" or "bool" or "string"),
                        IScriptIntPropertyGetter => !decl.IsArray && t == "int",
                        IScriptFloatPropertyGetter => !decl.IsArray && t == "float",
                        IScriptBoolPropertyGetter => !decl.IsArray && t == "bool",
                        _ => true,
                    };
                    if (!ok) errors.Add($"{owner.EditorID}: {s.Name}.{p.Name} kind mismatch (declared {decl.Type}{(decl.IsArray ? "[]" : "")}, filled as {p.GetType().Name})");
                    if (p is IScriptObjectPropertyGetter op && op.Object.IsNull) errors.Add($"{owner.EditorID}: {s.Name}.{p.Name} is empty");
                }
            }
        }
        foreach (var r in records)
        {
            if (r is IHaveVirtualMachineAdapterGetter vm && vm.VirtualMachineAdapter != null)
                CheckScripts(r, vm.VirtualMachineAdapter.Scripts, ExpectedScriptBases(r));
            if (r is IQuestGetter qv && qv.VirtualMachineAdapter is { } qa)
                foreach (var fa in qa.Aliases)
                {
                    var aliasId = fa.Property.Alias;
                    var alias = qv.Aliases.FirstOrDefault(x => x.ID == aliasId);
                    if (alias == null || fa.Property.Object.FormKey != qv.FormKey)
                    {
                        errors.Add($"{qv.EditorID}: alias scripts attached to missing alias {aliasId}");
                        continue;
                    }
                    var bases = alias.Type == QuestAlias.TypeEnum.Location ? new[] { "LocationAlias" } : new[] { "ReferenceAlias" };
                    CheckScripts(r, fa.Scripts, bases, $" alias {alias.Name}");
                }
        }

        // Dialogue fragments: the INFO's fragment file must be one of its scripts, and the fragment
        // function must exist in that script's source with the (ObjectReference akSpeakerRef) signature.
        int fragments = 0;
        foreach (var info in records.OfType<IDialogResponsesGetter>())
        {
            if (info.VirtualMachineAdapter?.ScriptFragments is not { } sf) continue;
            if (!info.VirtualMachineAdapter.Scripts.Any(x => string.Equals(x.Name, sf.FileName, StringComparison.OrdinalIgnoreCase)))
                errors.Add($"{info.EditorID ?? info.FormKey.ToString()}: fragment file '{sf.FileName}' is not among the INFO's scripts");
            foreach (var f in new[] { sf.OnBegin, sf.OnEnd }.Where(f => f != null))
            {
                fragments++;
                var pars = papyrus.FunctionParams(f!.ScriptName, f.FragmentName);
                if (pars == null) errors.Add($"{info.FormKey}: fragment {f.ScriptName}.{f.FragmentName} is not declared in the source");
                else if (!pars.StartsWith("ObjectReference ", StringComparison.OrdinalIgnoreCase) || pars.Contains(','))
                    errors.Add($"{info.FormKey}: fragment {f.ScriptName}.{f.FragmentName}({pars}) must take a single ObjectReference");
            }
        }

        // Dialogue structure.
        int infos = 0, responses = 0;
        var ownTopics = mod.DialogTopics.ToDictionary(t => t.FormKey);
        foreach (var t in mod.DialogTopics)
        {
            if (t.Quest.IsNull) errors.Add($"{t.EditorID}: topic has no quest");
            if (t.Category == DialogTopic.CategoryEnum.Topic && t.Branch.IsNull) errors.Add($"{t.EditorID}: player topic is not in a branch");
            foreach (var info in t.Responses)
            {
                infos++;
                var where = $"{t.EditorID} INFO {info.FormKey.ID:X3}";
                if (info.Responses.Count == 0) errors.Add($"{where}: no responses");
                if (info.Conditions.Count == 0) warnings.Add($"{where}: no conditions (every NPC can say it)");
                for (int i = 0; i < info.Responses.Count; i++)
                {
                    responses++;
                    var r = info.Responses[i];
                    if (r.ResponseNumber != i + 1) errors.Add($"{where}: response {i} is numbered {r.ResponseNumber}, expected {i + 1}");
                    var len = r.Text?.String?.Length ?? 0;
                    if (len == 0) errors.Add($"{where}: response {i + 1} has no text");
                    if (len > 149) errors.Add($"{where}: response {i + 1} is {len} characters (the Creation Kit allows 149)");
                }
                foreach (var l in info.LinkTo)
                    if (ownTopics.TryGetValue(l.FormKey, out var lt) && lt.Quest.FormKey != t.Quest.FormKey)
                        errors.Add($"{where}: links to {lt.EditorID}, which belongs to another quest");
            }
        }
        foreach (var b in mod.DialogBranches)
        {
            if (b.StartingTopic.IsNull || !ownTopics.TryGetValue(b.StartingTopic.FormKey, out var st)) { errors.Add($"{b.EditorID}: branch has no starting topic in this plugin"); continue; }
            if (st.Branch.FormKey != b.FormKey) errors.Add($"{b.EditorID}: starting topic {st.EditorID} points at another branch");
            if (st.Quest.FormKey != b.Quest.FormKey) errors.Add($"{b.EditorID}: starting topic {st.EditorID} belongs to another quest");
        }

        // SEQ file for Start Game Enabled quests, next to the plugin.
        var pluginDir = Path.GetDirectoryName(Path.GetFullPath(pluginPath))!;
        var seqIds = SeqFile.FormIds(mod);
        var seqPath = SeqFile.PathFor(pluginDir, mod.ModKey.FileName.String);
        if (seqIds.Count > 0)
        {
            if (!File.Exists(seqPath)) errors.Add($"{seqIds.Count} Start Game Enabled quest(s) but no {Path.GetRelativePath(pluginDir, seqPath)}");
            else if (!File.ReadAllBytes(seqPath).AsSpan().SequenceEqual(SeqFile.Bytes(seqIds))) errors.Add($"{Path.GetFileName(seqPath)} does not list exactly the plugin's Start Game Enabled quests");
        }

        // Voice files: every response needs a file in at least one voice type folder, or it flashes past.
        int voiceFiles = 0;
        var voiceDir = Path.Combine(pluginDir, "Sound", "Voice", mod.ModKey.FileName.String);
        var questEdids = mod.Quests.ToDictionary(q => q.FormKey, q => q.EditorID ?? "");
        var present = Directory.Exists(voiceDir)
            ? Directory.EnumerateFiles(voiceDir, "*", SearchOption.AllDirectories).Select(f => Path.GetFileNameWithoutExtension(f)).ToHashSet(StringComparer.OrdinalIgnoreCase)
            : new HashSet<string>();
        if (Directory.Exists(voiceDir)) voiceFiles = Directory.EnumerateFiles(voiceDir, "*", SearchOption.AllDirectories).Count();
        foreach (var t in mod.DialogTopics)
            foreach (var info in t.Responses)
                foreach (var r in info.Responses)
                {
                    if (!questEdids.TryGetValue(t.Quest.FormKey, out var qe)) continue;
                    string stem;
                    try { stem = SilentVoice.Stem(qe, t.EditorID ?? "", info.FormKey.ID, r.ResponseNumber); }
                    catch (InvalidOperationException ex) { errors.Add($"{t.EditorID}: {ex.Message}"); continue; }
                    if (!present.Contains(stem)) errors.Add($"{t.EditorID} INFO {info.FormKey.ID:X3} response {r.ResponseNumber}: no voice file {stem}.* under Sound/Voice/{mod.ModKey.FileName}/");
                }

        foreach (var stale in unusedExpected.OrderBy(x => x))
            warnings.Add($"expected-unfilled entry '{stale}' does not match an unfilled property (stale?)");

        // <Global=X> text tags: registered on the owning quest, never in NPC responses (see TextGlobals).
        errors.AddRange(TextGlobals.Check(mod));

        // Message boxes: the engine shows at most 10 buttons.
        foreach (var m in mod.Messages)
            if (m.MenuButtons.Count > 10) errors.Add($"{m.EditorID}: {m.MenuButtons.Count} buttons (max 10)");

        // Quest-specific sanity: alias ids referenced by objectives and properties exist.
        var tagRx = new System.Text.RegularExpressions.Regex(@"<(Alias|Global)=([^>.]+)[^>]*>");
        var globalIds = mod.Globals.ToDictionary(g => g.FormKey, g => g.EditorID ?? "");
        foreach (var q in mod.Quests)
        {
            var aliasIds = q.Aliases.Select(a => (int)a.ID).ToHashSet();
            // Text replacement tags must name an alias of this quest / a global listed in its Text Display Globals.
            var aliasNames = q.Aliases.Select(a => a.Name ?? "").ToHashSet(StringComparer.OrdinalIgnoreCase);
            var textGlobals = q.TextDisplayGlobals.Select(g => globalIds.TryGetValue(g.FormKey, out var e) ? e : g.FormKey.ToString()).ToHashSet(StringComparer.OrdinalIgnoreCase);
            var texts = q.Objectives.Select(o => (where: $"objective {o.Index}", text: o.DisplayText?.String ?? ""))
                .Concat(q.Stages.SelectMany(st => st.LogEntries.Select(le => (where: $"stage {st.Index} log", text: le.Entry?.String ?? ""))));
            foreach (var (where, text) in texts)
                foreach (System.Text.RegularExpressions.Match m in tagRx.Matches(text))
                {
                    var name = m.Groups[2].Value;
                    if (m.Groups[1].Value == "Alias" && !aliasNames.Contains(name))
                        errors.Add($"{q.EditorID}: {where} uses <Alias={name}> but the quest has no such alias");
                    if (m.Groups[1].Value == "Global" && !textGlobals.Contains(name))
                        errors.Add($"{q.EditorID}: {where} uses <Global={name}> but it is not in the quest's Text Display Globals");
                }
            foreach (var o in q.Objectives)
                foreach (var t in o.Targets)
                    if (!aliasIds.Contains(t.AliasID)) errors.Add($"{q.EditorID}: objective {o.Index} targets missing alias {t.AliasID}");
            foreach (var a in q.Aliases)
            {
                if (a.Location?.AliasID is int la && !aliasIds.Contains(la)) errors.Add($"{q.EditorID}: alias {a.Name} refers to missing alias {la}");
                if (a.CreateReferenceToObject is { } c && !aliasIds.Contains(c.AliasID)) errors.Add($"{q.EditorID}: alias {a.Name} creates at missing alias {c.AliasID}");
            }
            if (q.VirtualMachineAdapter != null)
                foreach (var s in q.VirtualMachineAdapter.Scripts)
                    foreach (var p in s.Properties.OfType<IScriptObjectPropertyGetter>())
                        if (p.Alias >= 0 && p.Object.FormKey == q.FormKey && !aliasIds.Contains(p.Alias))
                            errors.Add($"{q.EditorID}: {s.Name}.{p.Name} points at missing alias {p.Alias}");
            if (q.NextAliasID is uint next && aliasIds.Count > 0 && next <= aliasIds.Max())
                errors.Add($"{q.EditorID}: NextAliasID {next} must exceed the highest alias id {aliasIds.Max()}");
        }

        // Round trip: parse the plugin fully, write it back out and compare bytes.
        var roundTripDir = Directory.CreateTempSubdirectory("modkit-roundtrip-").FullName;
        var roundTrip = Path.Combine(roundTripDir, Path.GetFileName(pluginPath));
        try
        {
            var full = SkyrimMod.CreateFromBinary(pluginPath, SkyrimRelease.SkyrimSE);
            full.BeginWrite.ToPath(roundTrip).WithNoLoadOrder().WithMastersListOrdering(masters).Write(); // keep the header's master order
            if (!File.ReadAllBytes(roundTrip).AsSpan().SequenceEqual(File.ReadAllBytes(pluginPath)))
                errors.Add("round trip: re-written plugin differs from the original bytes");
        }
        finally { Directory.Delete(roundTripDir, true); }

        var report = new
        {
            plugin = Path.GetFileName(pluginPath),
            eslFlagged = esl,
            masters = masters.Select(m => m.FileName.String).ToArray(),
            newRecords = own.Count,
            overrides,
            formIdRange = own.Count == 0 ? "" : $"{own.Min(r => r.FormKey.ID):X3}-{own.Max(r => r.FormKey.ID):X3}",
            byType = own.GroupBy(r => r.Registration.ClassType.Name).OrderBy(g => g.Key).ToDictionary(g => g.Key, g => g.Count()),
            formLinks = links,
            dialogue = new { topics = mod.DialogTopics.Count, infos, responses, fragments, voiceFiles },
            seq = seqIds.Select(i => i.ToString("X8")).ToArray(),
            scriptAttachments = scripts,
            scriptProperties = props,
            records = own.OrderBy(r => r.FormKey.ID).Select(r => new { id = r.FormKey.ID.ToString("X6"), type = r.Registration.ClassType.Name, editorId = r.EditorID }).ToArray(),
            errors,
            warnings,
            expectedUnfilled = expected,
        };
        File.WriteAllText(reportPath, JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true }) + "\n");

        Console.WriteLine($"[validate] {report.plugin}: {own.Count} new records, {overrides} overrides, ESL={esl}, masters={string.Join(",", report.masters)}, FormIDs {report.formIdRange}");
        Console.WriteLine($"[validate] round trip (read, write, byte compare): {(errors.Any(e => e.StartsWith("round trip")) ? "FAILED" : "identical")}");
        Console.WriteLine($"[validate] {links} form links, {scripts} script attachments, {props} script properties checked");
        if (checkedMasters.Count > 0)
            Console.WriteLine($"[validate] {masterLinks} links into {checkedMasters.Count} supplied master file(s) resolved by FormID and type");
        if (infos > 0) Console.WriteLine($"[validate] dialogue: {mod.DialogTopics.Count} topics, {infos} infos, {responses} responses, {fragments} fragments, {voiceFiles} voice files");
        if (seqIds.Count > 0) Console.WriteLine($"[validate] SEQ: {string.Join(", ", seqIds.Select(i => i.ToString("X8")))}");
        if (expected.Count > 0) Console.WriteLine($"[validate] {expected.Count} script properties intentionally unfilled (listed in the report)");
        foreach (var w in warnings) Console.WriteLine($"[validate] WARN  {w}");
        foreach (var e in errors) Console.WriteLine($"[validate] ERROR {e}");
        return errors.Count;
    }
}
