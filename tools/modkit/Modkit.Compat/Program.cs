using System.IO.Compression;
using System.Text;
using Mutagen.Bethesda;
using Mutagen.Bethesda.Plugins;
using Mutagen.Bethesda.Plugins.Records;
using Mutagen.Bethesda.Skyrim;

// Cross-mod compatibility check for the series.
//
//   dotnet run --project tools/modkit/Modkit.Compat -- [--report out.md] <A.zip|A.esp> <B.zip|B.esp> ...
//
// Loads every plugin together (from FOMOD archives, using what "00 Core" installs, or from loose
// .esp files) and checks:
//   * masters resolve inside the set (or are Skyrim.esm / Update.esm), and a load order exists
//   * FormIDs: ESL range, plugin-local uniqueness, and simulated runtime FormIDs for the whole
//     load order (FE xxx slots for ESL-flagged plugins) are unique; overrides of in-set masters
//     point at records that exist there
//   * EditorID collisions across plugins, and each plugin's EditorID prefix discipline
//   * duplicate Papyrus script names (VMAD attachments, alias scripts, dialogue fragments and the
//     .pex files the archives install)
//   * overlapping overrides of vanilla (or any shared) records
//   * global (GLOB) EditorID clashes
//   * installed file path collisions between archives (scripts, SEQ, voice files, ...)
// Exit code 0 = no errors.
var reportPath = "";
var inputs = new List<string>();
for (int i = 0; i < args.Length; i++)
{
    if (args[i] == "--report") reportPath = args[++i];
    else inputs.Add(args[i]);
}
if (inputs.Count == 0) { Console.Error.WriteLine("usage: Modkit.Compat [--report out.md] <zip|esp>..."); return 2; }

var baseMasters = new HashSet<ModKey> { ModKey.FromFileName("Skyrim.esm"), ModKey.FromFileName("Update.esm") };
var temp = Directory.CreateTempSubdirectory("modkit-compat-").FullName;
var plugins = new List<Plugin>();
try
{
    foreach (var input in inputs)
    {
        var files = new List<string>();
        string pluginPath;
        if (input.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
        {
            var dir = Path.Combine(temp, Path.GetFileNameWithoutExtension(input));
            using var z = ZipFile.OpenRead(input);
            foreach (var e in z.Entries.Where(e => e.FullName.StartsWith("00 Core/") && !e.FullName.EndsWith("/")))
            {
                var rel = e.FullName["00 Core/".Length..];
                files.Add(rel.Replace('\\', '/'));
                var dst = Path.Combine(dir, rel);
                Directory.CreateDirectory(Path.GetDirectoryName(dst)!);
                e.ExtractToFile(dst, true);
            }
            pluginPath = Directory.EnumerateFiles(dir, "*.es?").Single();
        }
        else
        {
            pluginPath = input;
            files.Add(Path.GetFileName(input));
        }
        var mod = SkyrimMod.CreateFromBinaryOverlay(pluginPath, SkyrimRelease.SkyrimSE);
        plugins.Add(new Plugin(Path.GetFileName(input), mod, files));
    }

    var errors = new List<string>();
    var warnings = new List<string>();
    var sb = new StringBuilder();
    sb.AppendLine("# Compatibility report").AppendLine();
    sb.AppendLine($"{plugins.Count} plugins loaded together with Mutagen {typeof(SkyrimMod).Assembly.GetName().Version}.").AppendLine();

    // --- Masters and load order ---------------------------------------------------------------
    var byKey = plugins.ToDictionary(p => p.Mod.ModKey);
    foreach (var p in plugins)
        foreach (var m in p.Masters.Where(m => !baseMasters.Contains(m) && !byKey.ContainsKey(m)))
            errors.Add($"{p.Name}: master {m} is not part of the set");
    var order = new List<Plugin>();
    var placed = new HashSet<ModKey>();
    while (order.Count < plugins.Count)
    {
        var next = plugins.FirstOrDefault(p => !placed.Contains(p.Mod.ModKey) && p.Masters.All(m => baseMasters.Contains(m) || placed.Contains(m) || !byKey.ContainsKey(m)));
        if (next == null) { errors.Add("circular masters"); break; }
        order.Add(next); placed.Add(next.Mod.ModKey);
    }

    sb.AppendLine("## Load order (simulated)").AppendLine();
    sb.AppendLine("| # | Plugin | ESL | Masters | New records | Overrides | Runtime FormIDs |").AppendLine("|---|---|---|---|---|---|---|");
    var runtime = new Dictionary<uint, string>();
    int fullIndex = 1; // 00 Skyrim.esm (Update.esm etc. would follow; only relative uniqueness matters)
    int lightIndex = 0;
    foreach (var p in order)
    {
        uint Runtime(uint id) => p.Esl ? 0xFE000000u | ((uint)lightIndex << 12) | (id & 0xFFF) : ((uint)fullIndex << 24) | (id & 0xFFFFFF);
        foreach (var r in p.Own)
        {
            var rt = Runtime(r.FormKey.ID);
            if (runtime.TryGetValue(rt, out var other)) errors.Add($"runtime FormID {rt:X8} collides: {p.Mod.ModKey} {r.EditorID} and {other}");
            else runtime[rt] = $"{p.Mod.ModKey} {r.EditorID}";
            if (p.Esl && (r.FormKey.ID < 0x800 || r.FormKey.ID > 0xFFF)) errors.Add($"{p.Name}: {r.EditorID} {r.FormKey} outside the ESL range 800-FFF");
        }
        foreach (var dup in p.Own.GroupBy(r => r.FormKey.ID).Where(g => g.Count() > 1))
            errors.Add($"{p.Name}: local FormID {dup.Key:X6} used {dup.Count()} times");
        var range = p.Own.Count == 0 ? "-" : $"{Runtime(p.Own.Min(r => r.FormKey.ID)):X8}-{Runtime(p.Own.Max(r => r.FormKey.ID)):X8}";
        sb.AppendLine($"| {order.IndexOf(p) + 1} | {p.Mod.ModKey} | {(p.Esl ? "yes" : "no")} | {string.Join(", ", p.Masters)} | {p.Own.Count} | {p.Overrides.Count} | {range} |");
        if (p.Esl) lightIndex++; else fullIndex++;
    }
    sb.AppendLine();
    sb.AppendLine($"{runtime.Count} new records; every simulated runtime FormID is unique.").AppendLine();

    // --- Overrides ------------------------------------------------------------------------------
    sb.AppendLine("## Overrides of existing records").AppendLine();
    var overrides = plugins.SelectMany(p => p.Overrides.Select(r => (p, r))).GroupBy(x => x.r.FormKey).ToList();
    if (overrides.Count == 0) sb.AppendLine("None. No plugin in the set overrides a vanilla record or another plugin's record.");
    foreach (var g in overrides)
    {
        var who = string.Join(", ", g.Select(x => x.p.Mod.ModKey.ToString()));
        if (g.Count() > 1) errors.Add($"{g.Key} is overridden by several plugins: {who}");
        sb.AppendLine($"- {g.Key} ({g.First().r.Registration.ClassType.Name} {g.First().r.EditorID}): {who}");
        if (byKey.TryGetValue(g.Key.ModKey, out var master) && !master.Own.Any(r => r.FormKey == g.Key))
            errors.Add($"{who} override {g.Key}, which does not exist in {g.Key.ModKey} (injected record?)");
    }
    sb.AppendLine();

    // --- EditorIDs --------------------------------------------------------------------------------
    sb.AppendLine("## EditorIDs and prefixes").AppendLine();
    var allEdids = plugins.SelectMany(p => p.Own.Select(r => (p, r))).Where(x => !string.IsNullOrEmpty(x.r.EditorID)).GroupBy(x => x.r.EditorID!, StringComparer.OrdinalIgnoreCase);
    int edidCount = 0;
    foreach (var g in allEdids)
    {
        edidCount++;
        var owners = g.Select(x => x.p.Mod.ModKey).Distinct().ToList();
        if (owners.Count > 1) errors.Add($"EditorID '{g.Key}' is defined by {string.Join(", ", owners)}");
    }
    sb.AppendLine("| Plugin | Prefix | EditorIDs | Off-prefix |").AppendLine("|---|---|---|---|");
    var prefixes = new Dictionary<string, Plugin>(StringComparer.OrdinalIgnoreCase);
    foreach (var p in plugins)
    {
        var prefix = p.Own.Select(r => r.EditorID ?? "").Where(e => e.Contains('_')).GroupBy(e => e[..(e.IndexOf('_') + 1)]).OrderByDescending(g => g.Count()).Select(g => g.Key).FirstOrDefault() ?? "";
        p.Prefix = prefix;
        var off = p.Own.Where(r => !(r.EditorID ?? "").StartsWith(prefix, StringComparison.Ordinal)).Select(r => r.EditorID ?? r.FormKey.ToString()).ToList();
        foreach (var o in off) warnings.Add($"{p.Name}: EditorID {o} does not use the plugin prefix {prefix}");
        if (prefixes.TryGetValue(prefix, out var clash)) errors.Add($"{p.Name} and {clash.Name} share the prefix {prefix}");
        else prefixes[prefix] = p;
        sb.AppendLine($"| {p.Mod.ModKey} | `{prefix}` | {p.Own.Count(r => !string.IsNullOrEmpty(r.EditorID))} | {off.Count} |");
    }
    sb.AppendLine().AppendLine($"{edidCount} EditorIDs across the set; collisions: {errors.Count(e => e.StartsWith("EditorID"))}.").AppendLine();

    // --- Globals ----------------------------------------------------------------------------------
    sb.AppendLine("## Globals").AppendLine();
    var globals = plugins.SelectMany(p => p.Mod.Globals.Where(g => g.FormKey.ModKey == p.Mod.ModKey).Select(g => (p, g))).ToList();
    foreach (var g in globals.GroupBy(x => x.g.EditorID ?? "", StringComparer.OrdinalIgnoreCase).Where(g => g.Count() > 1))
        errors.Add($"global '{g.Key}' is defined by {string.Join(", ", g.Select(x => x.p.Mod.ModKey))}");
    sb.AppendLine("| Plugin | Globals |").AppendLine("|---|---|");
    foreach (var p in plugins)
        sb.AppendLine($"| {p.Mod.ModKey} | {globals.Count(x => x.p == p)} |");
    sb.AppendLine().AppendLine($"{globals.Count} globals in total, no two with the same EditorID{(errors.Any(e => e.StartsWith("global")) ? " (see errors)" : "")}.").AppendLine();

    // --- Scripts ----------------------------------------------------------------------------------
    sb.AppendLine("## Papyrus scripts").AppendLine();
    var scriptOwners = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);
    foreach (var p in plugins)
    {
        foreach (var s in p.ScriptNames())
        {
            if (!scriptOwners.TryGetValue(s, out var set)) scriptOwners[s] = set = new HashSet<string>();
            set.Add(p.Mod.ModKey.ToString());
            if (!s.StartsWith(p.Prefix, StringComparison.OrdinalIgnoreCase)) warnings.Add($"{p.Name}: script {s} does not use the plugin prefix {p.Prefix}");
        }
    }
    foreach (var kv in scriptOwners.Where(kv => kv.Value.Count > 1))
        errors.Add($"script '{kv.Key}' is used/shipped by {string.Join(", ", kv.Value)}");
    sb.AppendLine("| Plugin | Scripts (attached + shipped .pex) |").AppendLine("|---|---|");
    foreach (var p in plugins) sb.AppendLine($"| {p.Mod.ModKey} | {p.ScriptNames().Count} |");
    sb.AppendLine().AppendLine($"{scriptOwners.Count} distinct script names; duplicates: {scriptOwners.Count(kv => kv.Value.Count > 1)}.").AppendLine();

    // --- Cross-plugin links -----------------------------------------------------------------------
    sb.AppendLine("## Links between plugins in the set").AppendLine();
    int crossLinks = 0;
    foreach (var p in plugins)
    {
        var targets = p.Mod.EnumerateMajorRecords().SelectMany(r => r.EnumerateFormLinks().Select(l => (r, l)))
            .Where(x => !x.l.IsNull && x.l.FormKey.ModKey != p.Mod.ModKey && byKey.ContainsKey(x.l.FormKey.ModKey)).ToList();
        foreach (var x in targets.GroupBy(x => x.l.FormKey))
        {
            crossLinks++;
            var target = byKey[x.Key.ModKey].Own.FirstOrDefault(r => r.FormKey == x.Key);
            if (target == null) errors.Add($"{p.Name}: links to {x.Key}, which does not exist in {x.Key.ModKey}");
            sb.AppendLine($"- {p.Mod.ModKey} -> {x.Key.ModKey}: {target?.Registration.ClassType.Name} {target?.EditorID ?? x.Key.ToString()}");
        }
    }
    if (crossLinks == 0) sb.AppendLine("None: the plugins do not reference each other's records.");
    sb.AppendLine();

    // --- Installed files --------------------------------------------------------------------------
    sb.AppendLine("## Installed files").AppendLine();
    var fileOwners = plugins.SelectMany(p => p.Files.Select(f => (p, f))).GroupBy(x => x.f, StringComparer.OrdinalIgnoreCase).ToList();
    foreach (var g in fileOwners.Where(g => g.Select(x => x.p).Distinct().Count() > 1))
        errors.Add($"file '{g.Key}' is installed by {string.Join(", ", g.Select(x => x.p.Name))}");
    sb.AppendLine($"{fileOwners.Count} distinct installed paths across {inputs.Count(i => i.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))} archives; collisions: {fileOwners.Count(g => g.Select(x => x.p).Distinct().Count() > 1)}.").AppendLine();

    // --- Result -------------------------------------------------------------------------------
    sb.AppendLine("## Result").AppendLine();
    sb.AppendLine(errors.Count == 0 ? "**PASS**: no errors." : $"**FAIL**: {errors.Count} error(s).");
    foreach (var e in errors) sb.AppendLine($"- ERROR: {e}");
    foreach (var w in warnings) sb.AppendLine($"- warning: {w}");

    if (reportPath != "") File.WriteAllText(reportPath, sb.ToString());
    Console.Write(sb.ToString());
    foreach (var p in plugins) p.Mod.Dispose();
    return errors.Count == 0 ? 0 : 1;
}
finally
{
    Directory.Delete(temp, true);
}

sealed class Plugin
{
    public Plugin(string name, ISkyrimModDisposableGetter mod, List<string> files)
    {
        Name = name;
        Mod = mod;
        Files = files;
        var all = mod.EnumerateMajorRecords().ToList();
        Own = all.Where(r => r.FormKey.ModKey == mod.ModKey).ToList();
        Overrides = all.Where(r => r.FormKey.ModKey != mod.ModKey).ToList();
        Masters = mod.ModHeader.MasterReferences.Select(m => m.Master).ToList();
        Esl = mod.ModHeader.Flags.HasFlag(SkyrimModHeader.HeaderFlag.Small);
    }
    public string Name { get; }
    public ISkyrimModDisposableGetter Mod { get; }
    public List<string> Files { get; }
    public List<IMajorRecordGetter> Own { get; }
    public List<IMajorRecordGetter> Overrides { get; }
    public List<ModKey> Masters { get; }
    public bool Esl { get; }
    public string Prefix { get; set; } = "";

    private HashSet<string>? _scripts;
    public HashSet<string> ScriptNames()
    {
        if (_scripts != null) return _scripts;
        _scripts = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var r in Mod.EnumerateMajorRecords())
        {
            if (r is IHaveVirtualMachineAdapterGetter vm && vm.VirtualMachineAdapter != null)
                foreach (var s in vm.VirtualMachineAdapter.Scripts) _scripts.Add(s.Name);
            if (r is IQuestGetter q && q.VirtualMachineAdapter != null)
                foreach (var a in q.VirtualMachineAdapter.Aliases) foreach (var s in a.Scripts) _scripts.Add(s.Name);
            if (r is IDialogResponsesGetter info && info.VirtualMachineAdapter?.ScriptFragments is { } f)
                _scripts.Add(f.FileName);
        }
        foreach (var f in Files.Where(f => f.StartsWith("Scripts/", StringComparison.OrdinalIgnoreCase) && f.EndsWith(".pex", StringComparison.OrdinalIgnoreCase)))
            _scripts.Add(Path.GetFileNameWithoutExtension(f));
        return _scripts;
    }
}
