using System.Text;
using Mutagen.Bethesda.Plugins;
using Mutagen.Bethesda.Skyrim;

namespace Modkit.Mutagen;

/// <summary>
/// Silent voice files for unvoiced dialogue.
///
/// The engine plays a dialogue line for as long as its voice file lasts. Without a file the
/// subtitle flashes past in a fraction of a second, so every unvoiced response gets a silent
/// file whose length is scaled to the text. Files go where the engine looks for them:
/// <c>Sound/Voice/&lt;Plugin.esp&gt;/&lt;VoiceType&gt;/&lt;Quest&gt;_&lt;Topic&gt;_&lt;INFO FormID&gt;_&lt;response&gt;.wav</c>.
///
/// The files are uncompressed 16-bit PCM mono WAV, which the engine plays directly. Bethesda ships
/// voice as FUZ (xWMA audio + LIP lip-sync), but xWMA can only be produced with Microsoft's
/// Windows-only xWMAEncode and LIP files with the Creation Kit, so they are not generated here.
/// Silence compresses to almost nothing in the archive; on disk it costs ~86 KB per second.
/// Players running Fuz Ro D'oh are unaffected: it only steps in for lines that have no file.
/// </summary>
public static class SilentVoice
{
    public const int SampleRate = 44100;
    public const double WordsPerSecond = 2.6;
    public const double MinSeconds = 2.0, MaxSeconds = 12.0;

    public sealed record Line(string RelativePath, string VoiceType, string Speaker, string Text, double Seconds);

    /// <summary>Reading time for a subtitle: words / 2.6 per second + 1 s, clamped to 2-12 s, rounded to 0.1 s.</summary>
    public static double Seconds(string text)
    {
        var words = text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Length;
        return Math.Round(Math.Clamp(words / WordsPerSecond + 1.0, MinSeconds, MaxSeconds), 1, MidpointRounding.AwayFromZero);
    }

    /// <summary>
    /// The engine's voice file stem. The quest EditorID is cut to 10 characters and the topic EditorID to
    /// 15 (25 together); to keep this unambiguous we require both to already fit, and fail otherwise.
    /// The FormID is the plugin-local id with a 00 load-order byte (00000801 for an ESL-range record).
    /// </summary>
    public static string Stem(string questEditorId, string topicEditorId, uint localId, int responseNumber)
    {
        if (questEditorId.Length > 10)
            throw new InvalidOperationException($"quest EditorID '{questEditorId}' is longer than 10 characters; voice file names would be truncated");
        if (topicEditorId.Length > 15)
            throw new InvalidOperationException($"topic EditorID '{topicEditorId}' is longer than 15 characters; voice file names would be truncated");
        return $"{questEditorId}_{topicEditorId}_{localId & 0x00FFFFFF:X8}_{responseNumber}";
    }

    /// <param name="speakersFor">For each topic, the (voice type, speaker label) pairs that can say its lines.</param>
    public static List<Line> Plan(ISkyrimModGetter mod, Func<IDialogTopicGetter, IEnumerable<(string VoiceType, string Speaker)>> speakersFor)
    {
        var quests = mod.Quests.ToDictionary(q => q.FormKey, q => q.EditorID ?? "");
        var plugin = mod.ModKey.FileName.String;
        var lines = new List<Line>();
        foreach (var topic in mod.DialogTopics)
        {
            if (topic.Quest.IsNull || !quests.TryGetValue(topic.Quest.FormKey, out var questEdid))
                throw new InvalidOperationException($"topic {topic.EditorID} has no quest in this plugin");
            var speakers = speakersFor(topic).ToList();
            if (speakers.Count == 0) throw new InvalidOperationException($"topic {topic.EditorID}: no voice type given");
            foreach (var info in topic.Responses)
                foreach (var r in info.Responses)
                {
                    var stem = Stem(questEdid, topic.EditorID ?? "", info.FormKey.ID, r.ResponseNumber);
                    var text = r.Text?.String ?? "";
                    foreach (var (vt, speaker) in speakers)
                        lines.Add(new Line($"Sound/Voice/{plugin}/{vt}/{stem}.wav", vt, speaker, text, Seconds(text)));
                }
        }
        return lines;
    }

    /// <summary>Writes the planned files under <paramref name="dataDir"/> (the folder that holds the plugin).</summary>
    public static void Write(string dataDir, IEnumerable<Line> lines)
    {
        foreach (var l in lines)
        {
            var path = Path.Combine(dataDir, l.RelativePath.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllBytes(path, Wav(l.Seconds));
        }
    }

    /// <summary>A silent 16-bit PCM mono WAV of the given length.</summary>
    public static byte[] Wav(double seconds)
    {
        int samples = (int)Math.Round(seconds * SampleRate);
        int dataBytes = samples * 2;
        using var ms = new MemoryStream(44 + dataBytes);
        using var w = new BinaryWriter(ms, Encoding.ASCII);
        w.Write("RIFF"u8); w.Write(36 + dataBytes); w.Write("WAVE"u8);
        w.Write("fmt "u8); w.Write(16); w.Write((short)1); w.Write((short)1);
        w.Write(SampleRate); w.Write(SampleRate * 2); w.Write((short)2); w.Write((short)16);
        w.Write("data"u8); w.Write(dataBytes);
        w.Write(new byte[dataBytes]);
        w.Flush();
        return ms.ToArray();
    }
}
