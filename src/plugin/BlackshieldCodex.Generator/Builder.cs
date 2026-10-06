using Modkit.Mutagen;
using Mutagen.Bethesda;
using Mutagen.Bethesda.Plugins;
using Mutagen.Bethesda.Plugins.Records;
using Mutagen.Bethesda.Skyrim;
using Noggog;
using static BlackshieldCodex.Generator.Vanilla;

namespace BlackshieldCodex.Generator;

internal sealed class Builder
{
    private readonly SkyrimMod _mod;
    private readonly FormIdRegistry _ids;
    private readonly Masters _m;
    private static readonly SkyrimRelease R = SkyrimRelease.SkyrimSE;
    private const byte VanillaQuestFormVersion = 65;
    public const int AliasPlayer = 0;

    /// <summary>Every record of another first-wave plugin this mod reads or links to, for the docs and the build log.</summary>
    public List<(string Plugin, string EditorId, string Type, string Use)> ReadRecords { get; } = new();

    public Builder(SkyrimMod mod, FormIdRegistry ids, Masters masters)
    {
        _mod = mod;
        _ids = ids;
        _m = masters;
    }

    private FormKey Id(string editorId) => _ids.Get(editorId);
    private static FormLink<T> L<T>(FormKey k) where T : class, IMajorRecordGetter => new(k);

    /// <summary>Looks a first-wave record up by EditorID and logs what it is used for.</summary>
    private FormKey Ext<T>(string editorId, string use) where T : class, IMajorRecordGetter
    {
        var r = _m.Get<T>(editorId);
        ReadRecords.Add((r.FormKey.ModKey.FileName, editorId, typeof(T).Name.TrimStart('I').Replace("Getter", ""), use));
        return r.FormKey;
    }

    // Ember Smithing's own rules (EmberSmithing.Generator/Builder.cs, 0.1.0), repeated so the new
    // variants behave exactly like the Ember Smithing items they sit next to.
    private sealed record HeatTier(string Prefix, string Key, double Bonus, int MinBonus, double ValueMult, int Smithing);
    private static readonly HeatTier[] Tiers =
    {
        new("Heat-Tempered", "HeatTempered", 0.10, 1, 1.3, 20),
        new("Ember-Forged", "EmberForged", 0.20, 2, 1.7, 45),
        new("Dragonfire", "Dragonfire", 0.30, 3, 2.2, 70),
    };
    private sealed record Engraving(string Prefix, string Key, FormKey Extra, int ExtraCount);
    private static readonly Engraving[] Engravings =
    {
        new("Ember-Engraved", "Ember", FireSalts, 1),
        new("Hearth-Engraved", "Hearth", FrostSalts, 1),
        new("Bellows-Engraved", "Bellows", Charcoal, 2),
    };
    private const int EngraveSmithing = 30;
    private static int TierDamage(int baseDamage, HeatTier t)
        => baseDamage + Math.Max(t.MinBonus, (int)Math.Round(baseDamage * t.Bonus, MidpointRounding.AwayFromZero));

    public void Build()
    {
        BuildLinks();
        BuildGear();
    }

    // ----------------------------------------------------------------------------------------
    // Script synergies: one start-game-enabled quest that polls the other mods' globals
    // ----------------------------------------------------------------------------------------
    private void BuildLinks()
    {
        var gEnabled = Global("BCX_Enabled", 1);
        var gPoll = Global("BCX_PollSeconds", 5);
        var gRenownPerOath = Global("BCX_RenownPerOath", 10);
        var gBlessingFavor = Global("BCX_BlessingFavor", 30);
        var gBoonFavor = Global("BCX_BoonFavor", 80);
        var gBlessingPct = Global("BCX_BlessingPayPct", 10);
        var gBoonPct = Global("BCX_BoonPayPct", 20);
        var gRenownAwarded = Global("BCX_RenownAwarded", 0);
        var gGoldAwarded = Global("BCX_GoldAwarded", 0);

        var msgRenown = Notice("BCX_MsgOathRenown", "Blackshield Codex: %.0f oath(s) kept through the contract, +%.0f company renown.");
        var msgPatronage = Notice("BCX_MsgPatronage", "Blackshield Codex: Daedric patronage adds %.0f gold to the bounty (highest favor %.0f).");

        var bscQuest = Ext<IQuestGetter>("BSC_CompanyQuest", "cast to BSC_CompanyScript; AddRenown(Int) is called");
        var bscActive = Ext<IGlobalGetter>("BSC_ContractActive", "read: a contract was taken (0 -> 1)");
        var bscDone = Ext<IGlobalGetter>("BSC_ContractsDone", "read: a contract was completed (count went up)");
        var oaths = new[] { "Steel", "Shield", "Iron", "Endurance", "Close" }
            .Select(o => Ext<IGlobalGetter>($"SOT_Active{o}", "read: oath active (1) when a contract is taken and completed")).ToArray();
        var chtQuest = Ext<IQuestGetter>("CHT_HunterQuest", "cast to CHT_HunterScript; BasePay(Int) is called");
        var chtClaimed = Ext<IGlobalGetter>("CHT_BountiesClaimed", "read: a bounty was claimed (count went up)");
        var chtPayMult = Ext<IGlobalGetter>("CHT_PayMult", "read: Contract Hunter's pay multiplier, applied to the bonus too");
        var chtOpen = new[] { "Notice", "Wanted", "Dread" }
            .Select(t => Ext<IGlobalGetter>($"CHT_Open{t}", "read: which bounty tier was just claimed (open flag 1 -> 0)")).ToArray();
        var favor = new[] { "Dagon", "Boethiah", "Namira", "MolagBal", "Clavicus", "Hircine", "Sanguine", "Vaermina" }
            .Select(p => Ext<IGlobalGetter>($"BOO_Favor{p}", "read: favor with the prince (highest one counts)")).ToArray();

        var qCodex = Id("BCX_CodexQuest");
        var quest = Add(new Quest(qCodex, R)
        {
            EditorID = "BCX_CodexQuest",
            Name = "Blackshield Codex",
            Flags = Quest.Flag.StartGameEnabled | Quest.Flag.RunOnce,
            Priority = 40,
            Type = Quest.TypeEnum.None,
            QuestFormVersion = VanillaQuestFormVersion,
        });
        quest.Aliases.Add(new QuestAlias
        {
            ID = AliasPlayer, Type = QuestAlias.TypeEnum.Reference, Name = "Player",
            ForcedReference = new FormLinkNullable<IPlacedGetter>(PlayerRef),
        });
        quest.NextAliasID = (uint)quest.Aliases.Count;
        quest.VirtualMachineAdapter = Vmad.QuestAdapter(Vmad.Script("BCX_CodexScript",
                Vmad.Obj("BCX_Enabled", gEnabled), Vmad.Obj("BCX_PollSeconds", gPoll),
                Vmad.Obj("BCX_RenownPerOath", gRenownPerOath),
                Vmad.Obj("BCX_BlessingFavor", gBlessingFavor), Vmad.Obj("BCX_BoonFavor", gBoonFavor),
                Vmad.Obj("BCX_BlessingPayPct", gBlessingPct), Vmad.Obj("BCX_BoonPayPct", gBoonPct),
                Vmad.Obj("BCX_RenownAwarded", gRenownAwarded), Vmad.Obj("BCX_GoldAwarded", gGoldAwarded),
                Vmad.Obj("BCX_MsgOathRenown", msgRenown), Vmad.Obj("BCX_MsgPatronage", msgPatronage),
                Vmad.Obj("Gold001", Gold001),
                Vmad.Obj("BSC_CompanyQuest", bscQuest), Vmad.Obj("BSC_ContractActive", bscActive), Vmad.Obj("BSC_ContractsDone", bscDone),
                Vmad.ObjList("OathActive", oaths),
                Vmad.Obj("CHT_HunterQuest", chtQuest), Vmad.Obj("CHT_BountiesClaimed", chtClaimed), Vmad.Obj("CHT_PayMult", chtPayMult),
                Vmad.ObjList("BountyOpen", chtOpen),
                Vmad.ObjList("PrinceFavor", favor)))
            .WithAliasScripts(qCodex, AliasPlayer, Vmad.Script("BCX_PlayerAliasScript"));
    }

    // ----------------------------------------------------------------------------------------
    // Ember Smithing x Blackshield Company: heat-tempered Blade, engraved Shield and Plate
    // ----------------------------------------------------------------------------------------
    private void BuildGear()
    {
        // Blade: Ember Smithing's three heat tiers, chained, keeping the Blackshield enchantment.
        var blade = _m.Get<IWeaponGetter>("BSC_BlackshieldBlade");
        Ext<IWeaponGetter>("BSC_BlackshieldBlade", "build time: copied as the base of the heat-tempered blades; runtime link: recipe input");
        Ext<IObjectEffectGetter>("BSC_EnchBladeEmber", "runtime link: enchantment kept on the heat-tempered blades");
        FormKey previous = blade.FormKey;
        foreach (var (tier, t) in Tiers.Select((x, i) => (x, i)))
        {
            var edid = $"BCX_{tier.Key}BlackshieldBlade";
            var w = blade.Duplicate(Id(edid));
            w.EditorID = edid;
            w.Name = $"{tier.Prefix} {blade.Name}";
            var damage = TierDamage(blade.BasicStats!.Damage, tier);
            w.BasicStats!.Damage = (ushort)damage;
            w.BasicStats.Value = (uint)Math.Round(blade.BasicStats.Value * tier.ValueMult, MidpointRounding.AwayFromZero);
            w.Critical!.Damage = (ushort)(damage / 2);
            Add(w);

            var items = new List<(FormKey, int)> { (previous, 1) };
            if (t == 0) { items.Add((IngotEbony, 1)); items.Add((Firewood, 2)); }
            else if (t == 1) { items.Add((IngotEbony, 1)); items.Add((Charcoal, 2)); }
            else { items.Add((IngotEbony, 2)); items.Add((FireSalts, 1)); }
            Recipe($"BCX_Recipe{tier.Key}BlackshieldBlade", w.FormKey, CraftingSmithingForge, items,
                new() { Carries(previous), SmithingAtLeast(tier.Smithing), HasPerk(EbonySmithing) });
            Recipe($"BCX_Temper{tier.Key}BlackshieldBlade", w.FormKey, CraftingSmithingSharpeningWheel,
                new() { (IngotEbony, 1) }, TemperConditions());
            previous = w.FormKey;
        }

        // Shield and Plate: the three Ember Smithing engravings, added on top of the Blackshield
        // enchantment (one new enchantment per variant carries both effects).
        Engrave("BSC_BlackshieldShield", "BSC_EnchShieldBlock", "Shieldwall", EbonySmithing, IngotEbony);
        Engrave("BSC_BlackshieldPlate", "BSC_EnchPlateHealth", "CompanyVigor", AdvancedArmors, IngotCorundum);
    }

    private void Engrave(string armorEdid, string enchEdid, string enchKey, FormKey perk, FormKey temperIngot)
    {
        var armor = _m.Get<IArmorGetter>(armorEdid);
        var bscEnch = _m.Get<IObjectEffectGetter>(enchEdid);
        Ext<IArmorGetter>(armorEdid, "build time: copied as the base of the engraved variants; runtime link: recipe input");
        Ext<IObjectEffectGetter>(enchEdid, "build time only: its effects (vanilla magic effects) are copied into the combined enchantments");
        var compact = armor.Name!.String!.Replace(" ", "");
        foreach (var e in Engravings)
        {
            var embEnch = _m.Get<IObjectEffectGetter>($"EMB_{e.Key}Engraving");
            if (!ReadRecords.Any(x => x.EditorId == embEnch.EditorID))
            {
                Ext<IObjectEffectGetter>(embEnch.EditorID!, "build time only: its effect and magnitude are copied into the combined enchantments");
                Ext<IMagicEffectGetter>($"EMB_{e.Key}EngravingEffect", "runtime link: effect of the combined enchantments");
            }

            var enchId = $"BCX_{e.Key}{enchKey}";
            var ench = bscEnch.Duplicate(Id(enchId));
            ench.EditorID = enchId;
            ench.Name = $"{e.Prefix} {bscEnch.Name}";
            foreach (var fx in embEnch.Effects) ench.Effects.Add(fx.DeepCopy());
            Add(ench);

            var edid = $"BCX_{e.Key}Engraved{compact}";
            var a = armor.Duplicate(Id(edid));
            a.EditorID = edid;
            a.Name = $"{e.Prefix} {armor.Name}";
            a.ObjectEffect = new FormLinkNullable<IObjectEffectGetter>(ench.FormKey);
            a.Value = (uint)Math.Round(armor.Value * 1.5, MidpointRounding.AwayFromZero) + 100;
            Add(a);

            Recipe($"BCX_Recipe{e.Key}Engraved{compact}", a.FormKey, CraftingSmithingForge,
                new() { (armor.FormKey, 1), (IngotSilver, 1), (e.Extra, e.ExtraCount) },
                new() { Carries(armor.FormKey), SmithingAtLeast(EngraveSmithing), HasPerk(perk) });
            Recipe($"BCX_Temper{e.Key}Engraved{compact}", a.FormKey, CraftingSmithingArmorTable,
                new() { (temperIngot, 1) }, TemperConditions());
        }
    }

    // ----------------------------------------------------------------------------------------
    // Record helpers
    // ----------------------------------------------------------------------------------------
    private void Recipe(string edid, FormKey created, FormKey workbench, List<(FormKey item, int count)> items, List<Condition> conditions)
    {
        var cobj = new ConstructibleObject(Id(edid), R)
        {
            EditorID = edid,
            CreatedObject = new FormLinkNullable<IConstructibleGetter>(created),
            WorkbenchKeyword = new FormLinkNullable<IKeywordGetter>(workbench),
            CreatedObjectCount = 1,
            Items = items.Select(i => new ContainerEntry { Item = new ContainerItem { Item = L<IItemGetter>(i.item), Count = i.count } }).ToExtendedList(),
        };
        cobj.Conditions.AddRange(conditions);
        _mod.ConstructibleObjects.Add(cobj);
    }

    /// <summary>Only list the recipe while the player carries the item it starts from.</summary>
    private static Condition Carries(FormKey item)
    {
        var d = new GetItemCountConditionData();
        d.ItemOrList.Link.SetTo(item);
        return Cond.Make(d, 1, CompareOperator.GreaterThanOrEqualTo);
    }

    private static Condition SmithingAtLeast(int value)
        => Cond.Make(new GetBaseActorValueConditionData { ActorValue = ActorValue.Smithing }, value, CompareOperator.GreaterThanOrEqualTo);

    private static Condition HasPerk(FormKey perk, bool or = false)
    {
        var d = new HasPerkConditionData();
        d.Perk.Link.SetTo(perk);
        return Cond.Make(d, 1, CompareOperator.EqualTo, or);
    }

    /// <summary>The vanilla tempering rule: unenchanted, or the Arcane Blacksmith perk (all of these are enchanted).</summary>
    private static List<Condition> TemperConditions()
        => new() { Cond.Make(new EPTemperingItemIsEnchantedConditionData(), 0, CompareOperator.EqualTo, or: true), HasPerk(ArcaneBlacksmith) };

    private T Add<T>(T record) where T : SkyrimMajorRecord
    {
        _mod.GetTopLevelGroup<T>().Add(record);
        return record;
    }

    private FormKey Global(string edid, float value)
    {
        var g = new GlobalFloat(Id(edid), R) { EditorID = edid, Data = value };
        _mod.Globals.Add(g);
        return g.FormKey;
    }

    /// <summary>A notification (top-left corner), not a message box.</summary>
    private FormKey Notice(string edid, string text)
    {
        var m = new Message(Id(edid), R) { EditorID = edid, Description = text, Flags = 0, DisplayTime = 2, INAM = new byte[4] };
        _mod.Messages.Add(m);
        return m.FormKey;
    }
}
