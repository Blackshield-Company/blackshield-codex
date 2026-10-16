using System.Text.RegularExpressions;
using Mutagen.Bethesda.Plugins;
using Mutagen.Bethesda.Skyrim;

namespace Modkit.Mutagen;

/// <summary>
/// <c>&lt;Global=X&gt;</c> text replacement. The engine only expands the tag when X is listed in the
/// Text Display Globals (QTGL) of the quest that owns the text: the quest itself for its name, journal
/// and objectives, the topic's quest for player topic text and prompts, the message's owner quest for
/// message boxes. NPC response text (subtitles) is never expanded and shows the raw tag, so keep the
/// number in the player's prompt or topic text instead. <see cref="Register"/> adds every global
/// referenced by quest-owned text to its quest, so generators no longer have to keep the list by hand.
/// </summary>
public static class TextGlobals
{
    public static readonly Regex Tag = new(@"<Global(?:\.[A-Za-z]+)?=([^>.]+)[^>]*>", RegexOptions.Compiled);

    public static IEnumerable<string> Names(string? text)
        => string.IsNullOrEmpty(text) ? Enumerable.Empty<string>() : Tag.Matches(text).Select(m => m.Groups[1].Value);

    /// <summary>Quest-owned text that the engine runs text replacement on, as (owner quest, where, text).</summary>
    public static IEnumerable<(FormKey Quest, string Where, string? Text)> OwnedText(ISkyrimModGetter mod)
    {
        foreach (var q in mod.Quests)
        {
            yield return (q.FormKey, $"{q.EditorID} name", q.Name?.String);
            foreach (var o in q.Objectives) yield return (q.FormKey, $"{q.EditorID} objective {o.Index}", o.DisplayText?.String);
            foreach (var st in q.Stages)
                foreach (var le in st.LogEntries) yield return (q.FormKey, $"{q.EditorID} stage {st.Index} log", le.Entry?.String);
        }
        foreach (var t in mod.DialogTopics)
        {
            yield return (t.Quest.FormKey, $"DIAL {t.EditorID}", t.Name?.String);
            foreach (var info in t.Responses)
                yield return (t.Quest.FormKey, $"DIAL {t.EditorID} / INFO {info.EditorID} [{info.FormKey.ID:X6}] prompt", info.Prompt?.String);
        }
        foreach (var m in mod.Messages)
        {
            var owner = m.Quest.IsNull ? FormKey.Null : m.Quest.FormKey;
            yield return (owner, $"MESG {m.EditorID} title", m.Name?.String);
            yield return (owner, $"MESG {m.EditorID} text", m.Description.String);
        }
    }

    /// <summary>
    /// Adds each global named by a <c>&lt;Global=X&gt;</c> tag in quest-owned text to that quest's Text
    /// Display Globals. Throws when the global is not in the plugin or the text has no owning quest.
    /// Call it after the records are built, before the plugin is written. Returns the number added.
    /// </summary>
    public static int Register(SkyrimMod mod)
    {
        var globals = mod.Globals.Where(g => g.EditorID != null)
            .ToDictionary(g => g.EditorID!, g => g.FormKey, StringComparer.OrdinalIgnoreCase);
        var quests = mod.Quests.ToDictionary(q => q.FormKey);
        int added = 0;
        foreach (var (owner, where, text) in OwnedText(mod).ToList())
            foreach (var name in Names(text))
            {
                if (!globals.TryGetValue(name, out var g))
                    throw new InvalidOperationException($"{where}: <Global={name}> names no global in this plugin");
                if (!quests.TryGetValue(owner, out var q))
                    throw new InvalidOperationException($"{where}: <Global={name}> but the text has no owning quest in this plugin");
                if (q.TextDisplayGlobals.Any(x => x.FormKey == g)) continue;
                q.TextDisplayGlobals.Add(g.ToLink<IGlobalGetter>());
                added++;
            }
        return added;
    }

    /// <summary>
    /// Build check: every <c>&lt;Global=X&gt;</c> in quest-owned text must name a global of this plugin
    /// that is in the owning quest's Text Display Globals, and no NPC response text may use the tag.
    /// </summary>
    public static List<string> Check(ISkyrimModGetter mod)
    {
        var errors = new List<string>();
        var edids = mod.Globals.ToDictionary(g => g.FormKey, g => g.EditorID ?? "");
        var names = edids.Values.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var quests = mod.Quests.ToDictionary(q => q.FormKey);
        foreach (var (owner, where, text) in OwnedText(mod))
            foreach (var name in Names(text))
            {
                if (!names.Contains(name)) { errors.Add($"{where}: uses <Global={name}> but the plugin has no such global"); continue; }
                if (!quests.TryGetValue(owner, out var q)) { errors.Add($"{where}: uses <Global={name}> but has no owning quest in this plugin"); continue; }
                if (!q.TextDisplayGlobals.Any(g => string.Equals(edids.GetValueOrDefault(g.FormKey), name, StringComparison.OrdinalIgnoreCase)))
                    errors.Add($"{where}: uses <Global={name}> but it is not in the Text Display Globals of its quest {q.EditorID}");
            }
        foreach (var t in mod.DialogTopics)
            foreach (var info in t.Responses)
                foreach (var r in info.Responses)
                    foreach (var name in Names(r.Text?.String))
                        errors.Add($"DIAL {t.EditorID} / INFO {info.EditorID} [{info.FormKey.ID:X6}] response {r.ResponseNumber}: uses <Global={name}> in NPC response text, which the engine never expands; move the value to the prompt or topic text");
        return errors;
    }
}
