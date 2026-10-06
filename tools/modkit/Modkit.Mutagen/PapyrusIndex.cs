using System.Text.RegularExpressions;

namespace Modkit.Mutagen;

/// <summary>
/// Minimal .psc reader used to cross-check plugin script attachments against
/// the Papyrus sources: every attached script must exist and every filled
/// property must be declared with a compatible kind (object / int / float / bool / array).
/// </summary>
public sealed class PapyrusIndex
{
    public sealed record Prop(string Type, string Name, bool IsArray, bool HasDefault);

    private readonly Dictionary<string, Dictionary<string, Prop>> _scripts = new(StringComparer.OrdinalIgnoreCase);

    private static readonly Regex ScriptName = new(@"^\s*Scriptname\s+(\w+)(?:\s+extends\s+(\w+))?", RegexOptions.IgnoreCase | RegexOptions.Multiline);
    private readonly Dictionary<string, string> _extends = new(StringComparer.OrdinalIgnoreCase);
    private readonly Dictionary<string, Dictionary<string, string>> _functions = new(StringComparer.OrdinalIgnoreCase);
    private static readonly Regex FunctionDecl = new(@"^\s*(?:\w+(?:\[\])?\s+)?Function\s+(\w+)\s*\(([^)]*)\)", RegexOptions.IgnoreCase | RegexOptions.Multiline);
    private static readonly Regex PropertyDecl = new(@"^\s*(\w+)(\[\])?\s+Property\s+(\w+)(?!.*\bAutoReadOnly\b)(\s*=)?", RegexOptions.IgnoreCase | RegexOptions.Multiline);

    public PapyrusIndex(string sourceDir)
    {
        foreach (var file in Directory.EnumerateFiles(sourceDir, "*.psc"))
        {
            var text = File.ReadAllText(file);
            var m = ScriptName.Match(text);
            if (!m.Success) continue;
            var props = new Dictionary<string, Prop>(StringComparer.OrdinalIgnoreCase);
            foreach (Match p in PropertyDecl.Matches(text))
                props[p.Groups[3].Value] = new Prop(p.Groups[1].Value, p.Groups[3].Value, p.Groups[2].Success, p.Groups[4].Success);
            _scripts[m.Groups[1].Value] = props;
            if (m.Groups[2].Success) _extends[m.Groups[1].Value] = m.Groups[2].Value;
            var fns = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (Match f in FunctionDecl.Matches(text))
                fns[f.Groups[1].Value] = Regex.Replace(f.Groups[2].Value.Trim(), @"\s+", " ");
            _functions[m.Groups[1].Value] = fns;
        }
    }

    public bool HasScript(string name) => _scripts.ContainsKey(name);

    /// <summary>The parameter list of a function declared in the script itself (not inherited), or null.</summary>
    public string? FunctionParams(string script, string function)
        => _functions.TryGetValue(script, out var f) && f.TryGetValue(function, out var p) ? p : null;

    /// <summary>
    /// The first ancestor of <paramref name="script"/> that is not one of the mod's own scripts,
    /// i.e. the vanilla type it ultimately extends (Quest, ReferenceAlias, ActiveMagicEffect, ...).
    /// </summary>
    public string? VanillaBase(string script)
    {
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var cur = script;
        while (_extends.TryGetValue(cur, out var parent) && seen.Add(cur))
        {
            if (!_scripts.ContainsKey(parent)) return parent;
            cur = parent;
        }
        return null;
    }

    public Prop? GetProperty(string script, string prop)
        => _scripts.TryGetValue(script, out var props) && props.TryGetValue(prop, out var p) ? p : null;

    public IReadOnlyCollection<string> Scripts => _scripts.Keys;

    public IEnumerable<Prop> Properties(string script)
        => _scripts.TryGetValue(script, out var props) ? props.Values : Enumerable.Empty<Prop>();
}
