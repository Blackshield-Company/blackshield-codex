using Mutagen.Bethesda;
using Mutagen.Bethesda.Plugins;
using Mutagen.Bethesda.Plugins.Records;
using Mutagen.Bethesda.Skyrim;

namespace BlackshieldCodex.Generator;

/// <summary>
/// The five first-wave plugins, read from the copies vendored in masters/plugins (the released
/// 0.1.0 files). They are only used at build time: to look records up by EditorID, to copy the
/// Blackshield gear as the base for the new variants, and to check every link into them.
/// </summary>
internal sealed class Masters : IDisposable
{
    public static readonly string[] Files =
    {
        "BlackshieldCompany.esp", "BountiesOfOblivion.esp", "ContractHunter.esp", "SteelOath.esp", "EmberSmithing.esp",
    };

    public IReadOnlyList<ISkyrimModDisposableGetter> Mods { get; }
    private readonly Dictionary<string, IMajorRecordGetter> _byEditorId = new(StringComparer.OrdinalIgnoreCase);

    public Masters(string dir)
    {
        var mods = new List<ISkyrimModDisposableGetter>();
        foreach (var f in Files)
        {
            var path = Path.Combine(dir, f);
            if (!File.Exists(path)) throw new FileNotFoundException($"master copy missing: {path}");
            var mod = SkyrimMod.CreateFromBinaryOverlay(path, SkyrimRelease.SkyrimSE);
            if (!mod.ModHeader.Flags.HasFlag(SkyrimModHeader.HeaderFlag.Small))
                Console.WriteLine($"[masters] note: {f} is not ESL-flagged");
            foreach (var r in mod.EnumerateMajorRecords().Where(r => r.FormKey.ModKey == mod.ModKey && r.EditorID != null))
                if (!_byEditorId.TryAdd(r.EditorID!, r)) throw new InvalidOperationException($"EditorID {r.EditorID} in more than one master");
            mods.Add(mod);
        }
        Mods = mods;
    }

    public static IEnumerable<ModKey> Keys => Files.Select(f => ModKey.FromFileName(f));

    public T Get<T>(string editorId) where T : class, IMajorRecordGetter
    {
        if (!_byEditorId.TryGetValue(editorId, out var r)) throw new KeyNotFoundException($"no record {editorId} in the first-wave masters");
        return r as T ?? throw new InvalidCastException($"{editorId} is a {r.GetType().Name}, expected {typeof(T).Name}");
    }

    public FormKey Key<T>(string editorId) where T : class, IMajorRecordGetter => Get<T>(editorId).FormKey;

    public void Dispose()
    {
        foreach (var m in Mods) m.Dispose();
    }
}
