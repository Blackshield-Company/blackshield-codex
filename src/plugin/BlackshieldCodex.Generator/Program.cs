using Modkit.Mutagen;
using Mutagen.Bethesda;
using Mutagen.Bethesda.Plugins;
using Mutagen.Bethesda.Skyrim;
using static BlackshieldCodex.Generator.Vanilla;

namespace BlackshieldCodex.Generator;

/// <summary>
/// Generates BlackshieldCodex.esp (ESL-flagged) and its SEQ file.
/// Usage: generator --out &lt;dir&gt; --ids &lt;formids.json&gt; --papyrus &lt;src/papyrus&gt; --masters &lt;masters/plugins&gt;
///        [--report &lt;file&gt;] [--records &lt;file&gt;]
/// </summary>
internal static class Program
{
    public const string PluginName = "BlackshieldCodex.esp";
    private static readonly SkyrimRelease Release = SkyrimRelease.SkyrimSE;

    private static int Main(string[] args)
    {
        string Arg(string name, string fallback)
        {
            var i = Array.IndexOf(args, name);
            return i >= 0 && i + 1 < args.Length ? args[i + 1] : fallback;
        }
        var outDir = Arg("--out", "build/plugin");
        var idsPath = Arg("--ids", "src/plugin/formids.json");
        var papyrusDir = Arg("--papyrus", "src/papyrus");
        var mastersDir = Arg("--masters", "masters/plugins");
        var buildDir = Path.GetDirectoryName(Path.GetFullPath(outDir))!;
        var reportPath = Arg("--report", Path.Combine(buildDir, "plugin-report.json"));
        var recordsPath = Arg("--records", Path.Combine(buildDir, "external-records.tsv"));
        if (Directory.Exists(outDir)) Directory.Delete(outDir, true);
        Directory.CreateDirectory(outDir);

        using var masters = new Masters(mastersDir);
        var modKey = ModKey.FromFileName(PluginName);
        var ids = new FormIdRegistry(idsPath, modKey);
        var mod = new SkyrimMod(modKey, Release);
        var builder = new Builder(mod, ids, masters);
        builder.Build();

        mod.ModHeader.Flags |= SkyrimModHeader.HeaderFlag.Small; // ESL-flagged ESP
        mod.ModHeader.Stats.Version = 1.7f;
        mod.ModHeader.Author = "synthalorian";
        mod.ModHeader.Description = "Blackshield Codex: optional links between Blackshield Company, Bounties of Oblivion, Contract Hunter, Steel Oath and Ember Smithing.";

        // Masters in the documented load order: Skyrim.esm, then the five first-wave plugins.
        var loadOrder = new[] { Skyrim }.Concat(Masters.Keys).ToArray();
        var outPath = Path.Combine(outDir, PluginName);
        mod.BeginWrite.ToPath(outPath).WithNoLoadOrder().WithMastersListOrdering(loadOrder).Write();
        ids.Save();
        foreach (var r in ids.Retired) Console.WriteLine($"[generate] note: retired EditorID kept reserved: {r}");
        Console.WriteLine($"[generate] wrote {outPath}");

        int seq;
        using (var written = SkyrimMod.CreateFromBinaryOverlay(outPath, Release)) seq = SeqFile.Write(outDir, written);
        Console.WriteLine($"[generate] SEQ: {seq} start-game-enabled quest(s)");

        File.WriteAllLines(recordsPath, new[] { "plugin\teditor_id\ttype\tuse" }
            .Concat(builder.ReadRecords.Select(r => $"{r.Plugin}\t{r.EditorId}\t{r.Type}\t{r.Use}")));
        Console.WriteLine($"[generate] {builder.ReadRecords.Count} first-wave records read or linked, list in {recordsPath}");

        var allowed = new HashSet<ModKey>(loadOrder);
        var errors = PluginValidator.Validate(outPath, new PapyrusIndex(papyrusDir), allowed, reportPath, null, masters.Mods);
        using (var written = SkyrimMod.CreateFromBinaryOverlay(outPath, Release))
        {
            var actual = written.ModHeader.MasterReferences.Select(m => m.Master).ToList();
            if (!actual.SequenceEqual(loadOrder))
            {
                Console.WriteLine($"[validate] ERROR: masters are [{string.Join(", ", actual)}], expected [{string.Join(", ", loadOrder)}]");
                errors++;
            }
            else Console.WriteLine($"[validate] masters: {string.Join(", ", actual)}");
        }
        return errors == 0 ? 0 : 1;
    }
}
