using Mutagen.Bethesda.Plugins;
using Mutagen.Bethesda.Skyrim;

namespace Modkit.Mutagen;

/// <summary>Condition helpers. Every condition defaults to "run on Subject", "== 1".</summary>
public static class Cond
{
    public static ConditionFloat Make(ConditionData data, float value = 1, CompareOperator op = CompareOperator.EqualTo, bool or = false)
        => new()
        {
            Data = data,
            CompareOperator = op,
            ComparisonValue = value,
            Flags = or ? Condition.Flag.OR : 0,
        };

    public static ConditionFloat Global(FormKey global, CompareOperator op, float value, bool or = false)
    {
        var d = new GetGlobalValueConditionData();
        d.Global.Link.SetTo(global);
        return Make(d, value, op, or);
    }

    public static ConditionFloat LocationHasKeyword(FormKey keyword, bool or = false)
    {
        var d = new LocationHasKeywordConditionData();
        d.Keyword.Link.SetTo(keyword);
        return Make(d, 1, CompareOperator.EqualTo, or);
    }

    public static ConditionFloat LocationHasRefType(FormKey refType)
    {
        var d = new LocationHasRefTypeConditionData();
        d.LocationReferenceType.Link.SetTo(refType);
        return Make(d);
    }

    public static ConditionFloat InCurrentLocFormList(FormKey formList)
    {
        var d = new GetInCurrentLocFormListConditionData();
        d.FormList.Link.SetTo(formList);
        return Make(d);
    }

    /// <summary>Runs the condition on a specific reference (e.g. the player) instead of the subject.</summary>
    public static T OnRef<T>(this T c, FormKey reference) where T : Condition
    {
        c.Data.RunOnType = Condition.RunOnType.Reference;
        c.Data.Reference = new FormLink<ISkyrimMajorRecordGetter>(reference);
        return c;
    }

    /// <summary>Compares against the current value of a global instead of a constant.</summary>
    public static ConditionGlobal MakeVsGlobal(ConditionData data, FormKey global, CompareOperator op, bool or = false)
        => new()
        {
            Data = data,
            CompareOperator = op,
            ComparisonValue = new FormLink<IGlobalGetter>(global),
            Flags = or ? Condition.Flag.OR : 0,
        };

    /// <summary>GetIsID: the subject (the speaker, in dialogue) is an instance of this base object.</summary>
    public static ConditionFloat IsID(FormKey baseObject, bool or = false)
    {
        var d = new GetIsIDConditionData();
        d.Object.Link.SetTo(baseObject);
        return Make(d, 1, CompareOperator.EqualTo, or);
    }

    /// <summary>GetIsAliasRef: the subject is the reference held by alias <paramref name="aliasId"/> of the owning quest.</summary>
    public static ConditionFloat IsAliasRef(int aliasId, bool or = false)
        => Make(new GetIsAliasRefConditionData { ReferenceAliasIndex = aliasId }, 1, CompareOperator.EqualTo, or);

    public static ConditionFloat Stage(FormKey quest, CompareOperator op, int stage, bool or = false)
    {
        var d = new GetStageConditionData();
        d.Quest.Link.SetTo(quest);
        return Make(d, stage, op, or);
    }

    public static ConditionFloat QuestRunning(FormKey quest, bool running, bool or = false)
    {
        var d = new GetQuestRunningConditionData();
        d.Quest.Link.SetTo(quest);
        return Make(d, running ? 1 : 0, CompareOperator.EqualTo, or);
    }

    public static GetItemCountConditionData ItemCountData(FormKey item)
    {
        var d = new GetItemCountConditionData();
        d.ItemOrList.Link.SetTo(item);
        return d;
    }

    public static ConditionFloat ItemCount(FormKey item, CompareOperator op, float value, bool or = false)
        => Make(ItemCountData(item), value, op, or);
}
