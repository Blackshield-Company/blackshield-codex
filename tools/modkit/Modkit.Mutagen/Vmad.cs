using Mutagen.Bethesda.Plugins;
using Mutagen.Bethesda.Skyrim;

namespace Modkit.Mutagen;

/// <summary>Small helpers for building Papyrus script attachments (VMAD).</summary>
public static class Vmad
{
    public static ScriptEntry Script(string name, params ScriptProperty[] props)
    {
        var e = new ScriptEntry { Name = name, Flags = ScriptEntry.Flag.Local };
        e.Properties.AddRange(props);
        return e;
    }

    public static VirtualMachineAdapter Adapter(params ScriptEntry[] scripts)
    {
        var a = new VirtualMachineAdapter();
        a.Scripts.AddRange(scripts);
        return a;
    }

    public static QuestAdapter QuestAdapter(params ScriptEntry[] scripts)
    {
        var a = new QuestAdapter();
        a.Scripts.AddRange(scripts);
        return a;
    }

    /// <summary>Attaches scripts to a quest alias (e.g. a ReferenceAlias forced to the player).</summary>
    public static QuestAdapter WithAliasScripts(this QuestAdapter adapter, FormKey quest, int aliasId, params ScriptEntry[] scripts)
    {
        var a = new QuestFragmentAlias
        {
            Property = new ScriptObjectProperty { Object = new FormLink<ISkyrimMajorRecordGetter>(quest), Alias = (short)aliasId },
            Version = 5,
            ObjectFormat = 2,
        };
        a.Scripts.AddRange(scripts);
        adapter.Aliases.Add(a);
        return adapter;
    }

    public static ScriptObjectProperty Obj(string name, FormKey target) => new()
    {
        Name = name,
        Flags = ScriptProperty.Flag.Edited,
        Object = new FormLink<ISkyrimMajorRecordGetter>(target),
        Alias = -1,
    };

    /// <summary>A property pointing at a quest alias (ReferenceAlias / LocationAlias).</summary>
    public static ScriptObjectProperty Alias(string name, FormKey quest, int aliasId) => new()
    {
        Name = name,
        Flags = ScriptProperty.Flag.Edited,
        Object = new FormLink<ISkyrimMajorRecordGetter>(quest),
        Alias = (short)aliasId,
    };

    public static ScriptObjectListProperty ObjList(string name, params FormKey[] targets)
    {
        var p = new ScriptObjectListProperty { Name = name, Flags = ScriptProperty.Flag.Edited };
        foreach (var t in targets)
            p.Objects.Add(new ScriptObjectProperty { Object = new FormLink<ISkyrimMajorRecordGetter>(t), Alias = -1 });
        return p;
    }

    public static ScriptIntProperty Int(string name, int value) => new() { Name = name, Flags = ScriptProperty.Flag.Edited, Data = value };
    public static ScriptFloatProperty Float(string name, float value) => new() { Name = name, Flags = ScriptProperty.Flag.Edited, Data = value };
    public static ScriptBoolProperty Bool(string name, bool value) => new() { Name = name, Flags = ScriptProperty.Flag.Edited, Data = value };

    /// <summary>
    /// Script attachment for a dialogue INFO (DialogResponses): the TopicInfo script plus its fragment
    /// binding. By convention the fragment function is <c>Fragment_0(ObjectReference akSpeakerRef)</c>.
    /// </summary>
    public static DialogResponsesAdapter InfoFragment(string script, bool onBegin = false, params ScriptProperty[] props)
    {
        var a = new DialogResponsesAdapter();
        a.Scripts.Add(Script(script, props));
        var frag = new ScriptFragment { ScriptName = script, FragmentName = "Fragment_0" };
        a.ScriptFragments = new ScriptFragments
        {
            FileName = script,
            OnBegin = onBegin ? frag : null,
            OnEnd = onBegin ? null : frag,
        };
        return a;
    }
}
