using System.Text.Json;
using Mutagen.Bethesda.Plugins;

namespace Modkit.Mutagen;

/// <summary>
/// Stable FormID allocation. Every EditorID gets a FormID the first time it is
/// generated and keeps it forever (the mapping is committed to the repo), so
/// records never change FormID between releases and saves stay compatible.
/// IDs start at 0x800, which keeps the plugin valid as an ESL-flagged ESP.
/// </summary>
public sealed class FormIdRegistry
{
    public const uint FirstId = 0x800;
    public const uint LastEslId = 0xFFF;

    private readonly string _path;
    private readonly ModKey _modKey;
    private readonly SortedDictionary<string, uint> _ids;
    private readonly HashSet<string> _used = new(StringComparer.Ordinal);
    private uint _next;

    public FormIdRegistry(string path, ModKey modKey)
    {
        _path = path;
        _modKey = modKey;
        _ids = File.Exists(path)
            ? new SortedDictionary<string, uint>(
                JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(path))!
                    .ToDictionary(kv => kv.Key, kv => Convert.ToUInt32(kv.Value, 16)), StringComparer.Ordinal)
            : new SortedDictionary<string, uint>(StringComparer.Ordinal);
        _next = _ids.Count == 0 ? FirstId : _ids.Values.Max() + 1;
    }

    public FormKey Get(string editorId)
    {
        if (!_used.Add(editorId))
            throw new InvalidOperationException($"EditorID '{editorId}' requested twice");
        if (!_ids.TryGetValue(editorId, out var id))
        {
            id = _next++;
            _ids[editorId] = id;
        }
        return new FormKey(_modKey, id);
    }

    /// <summary>EditorIDs that have a reserved FormID but were not generated this run.</summary>
    public IEnumerable<string> Retired => _ids.Keys.Where(k => !_used.Contains(k));

    public uint MaxId => _ids.Count == 0 ? 0 : _ids.Values.Max();

    public void Save()
    {
        var json = JsonSerializer.Serialize(
            _ids.ToDictionary(kv => kv.Key, kv => kv.Value.ToString("X6")),
            new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(_path, json + "\n");
    }
}
