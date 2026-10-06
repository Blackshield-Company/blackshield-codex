using Mutagen.Bethesda.Skyrim;

namespace Modkit.Mutagen;

/// <summary>
/// The <c>SEQ/&lt;Plugin&gt;.seq</c> file. Since 1.7 the engine uses it to find the Start Game Enabled
/// quests a plugin adds; without it, dialogue and scenes in those quests may not work. It is a flat,
/// headerless array of little-endian uint32 FormIDs in the plugin's on-disk form: the high byte is the
/// plugin's own master-list index (= number of masters), the low bytes the local id. This is what
/// xEdit's "Create SEQ file" writes. It never contains runtime (FE xxx) ids, so it is load-order independent.
/// </summary>
public static class SeqFile
{
    public static List<uint> FormIds(ISkyrimModGetter mod)
    {
        uint self = (uint)mod.ModHeader.MasterReferences.Count << 24;
        return mod.Quests
            .Where(q => q.FormKey.ModKey == mod.ModKey && q.Flags.HasFlag(Quest.Flag.StartGameEnabled))
            .Select(q => self | q.FormKey.ID)
            .ToList();
    }

    public static string PathFor(string dataDir, string pluginFileName)
        => Path.Combine(dataDir, "SEQ", Path.ChangeExtension(pluginFileName, ".seq"));

    public static byte[] Bytes(IEnumerable<uint> ids) => ids.SelectMany(BitConverter.GetBytes).ToArray();

    /// <summary>Writes the file next to the plugin (dataDir/SEQ/x.seq). Writes nothing if there are no SGE quests.</summary>
    public static int Write(string dataDir, ISkyrimModGetter mod)
    {
        var ids = FormIds(mod);
        if (ids.Count == 0) return 0;
        var path = PathFor(dataDir, mod.ModKey.FileName.String);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllBytes(path, Bytes(ids));
        return ids.Count;
    }
}
