using Mutagen.Bethesda.Plugins;

namespace BlackshieldCodex.Generator;

/// <summary>
/// Skyrim.esm records this mod links to (FormIDs looked up with Mutagen.Bethesda.FormKeys.SkyrimSE).
/// Records from the five first-wave plugins are looked up by EditorID in the vendored copies
/// under masters/plugins (see Masters.cs), never hard-coded.
/// </summary>
internal static class Vanilla
{
    public static readonly ModKey Skyrim = ModKey.FromFileName("Skyrim.esm");
    public static FormKey K(uint id) => new(Skyrim, id);

    public static readonly FormKey PlayerRef = K(0x000014);
    public static readonly FormKey Gold001 = K(0x00000F);

    // Workbenches
    public static readonly FormKey CraftingSmithingForge = K(0x088105);
    public static readonly FormKey CraftingSmithingSharpeningWheel = K(0x088108);
    public static readonly FormKey CraftingSmithingArmorTable = K(0x0ADB78);

    // Materials (same choices as Ember Smithing's recipes)
    public static readonly FormKey IngotEbony = K(0x05AD9D);
    public static readonly FormKey IngotCorundum = K(0x05AD93);
    public static readonly FormKey IngotSilver = K(0x05ACE3);
    public static readonly FormKey Firewood = K(0x06F993);
    public static readonly FormKey Charcoal = K(0x033760);
    public static readonly FormKey FireSalts = K(0x03AD5E);
    public static readonly FormKey FrostSalts = K(0x03AD5F);

    // Perks
    public static readonly FormKey EbonySmithing = K(0x0CB412);
    public static readonly FormKey AdvancedArmors = K(0x0CB414);
    public static readonly FormKey ArcaneBlacksmith = K(0x05218E);
}
