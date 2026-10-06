# Nexus Mods page: Blackshield Codex

Early beta: v0.1.0 passed every automated build check but hasn't been playtested in-game. The page says so up front. Exact upload-form values are in [NEXUS_FIELDS.md](NEXUS_FIELDS.md).

## Page settings

- **Game:** Skyrim Special Edition
- **Mod name:** Blackshield Codex
- **Version:** 0.1.0 (early beta)
- **Category:** Gameplay
- **Suggested tags:** Gameplay, Crafting, Smithing, Factions, Daedric, ESL, No SKSE, Scripted, Patch
- **Requirements:** Blackshield Company (194203), Bounties of Oblivion (194204), Contract Hunter (194206), Steel Oath (194208), Ember Smithing (194210).
- **Permissions (suggested):** source on GitHub under MIT, so allow modification and conversions with credit. Don't allow re-uploads of the archive itself.
- **File to upload:** `BlackshieldCodex-0.1.0.zip` (FOMOD), main file, named "Blackshield Codex".

## Description (paste into the BBCode editor)

```bbcode
[center][size=6][b]BLACKSHIELD CODEX[/b][/size]
[size=3][i]Five trades, one ledger. The company hears of your oaths, the princes pay your bounties, and the forge knows your shield.[/i][/size]

[size=3][color=#e0a030][b]EARLY BETA (v0.1.0)[/b]: this version passes every automated build check but hasn't been playtested in-game yet. Please report bugs in the Bugs tab or on GitHub, ideally with your Papyrus log.[/color][/size][/center]

[line]

[size=4][b]Summary[/b][/size]
An optional plugin that makes my five first-wave mods notice each other. Each of them still works alone; with the Codex installed, what you do in one pays off in another.

[size=4][b]What it does[/b][/size]
[list]
[*][b]Steel Oath x Blackshield Company[/b]: every oath you keep through a Blackshield contract (sworn when you take it, still unbroken when it pays) adds [b]+10 company renown[/b]. Up to three oaths, so up to +30 on top of the contract's own renown. Promotions happen as usual.
[*][b]Bounties of Oblivion x Contract Hunter[/b]: when you claim a bounty, your highest favor with any Daedric prince adds [b]+10%[/b] of the bounty's base pay at Blessing favor (30+), or [b]+20%[/b] at Boon favor (80+).
[*][b]Ember Smithing x Blackshield Company[/b]: at the forge, take the [b]Blackshield Blade[/b] through Ember Smithing's three heat tiers (Heat-Tempered, Ember-Forged, Dragonfire: damage 11/12/13, enchantment kept), and give the [b]Blackshield Shield[/b] and [b]Plate[/b] an Ember, Hearth or Bellows engraving on top of their Blackshield enchantment (+20% fire resistance, +20% frost resistance, or 25% faster stamina regeneration). All nine can be tempered with Arcane Blacksmith.
[/list]
A short notification in the corner tells you when a bonus is paid.

[size=4][b]Forge recipes[/b][/size]
[list]
[*]Blade tiers: Smithing 20 / 45 / 70 and Ebony Smithing. Ebony Ingot plus Firewood, Charcoal or Fire Salts, as in Ember Smithing.
[*]Engravings: Smithing 30, Ebony Smithing (Shield) or Advanced Armors (Plate). Silver Ingot plus Fire Salts, Frost Salts or 2 Charcoal.
[*]Recipes only appear while you carry the item they start from.
[/list]

[size=4][b]Requirements[/b][/size]
[list]
[*]Skyrim Special Edition or Anniversary Edition (1.5.97 or 1.6.x). Works on Steam under Proton on Linux.
[*][b]All five[/b]: Blackshield Company, Bounties of Oblivion, Contract Hunter, Steel Oath and Ember Smithing (0.1.0 or later). They are masters of this plugin; the game won't start with any of them missing.
[*]Nothing else. No SKSE, no SkyUI, no DLC, no Creation Club content.
[/list]

[size=4][b]Installation[/b][/size]
Install with [b]Mod Organizer 2[/b] or [b]Vortex[/b] (FOMOD installer) and enable [b]BlackshieldCodex.esp[/b] [b]after[/b] the five (LOOT sorts it automatically). It's ESL-flagged, so it doesn't take a full load-order slot. Safe to add mid-playthrough: nothing is paid for the past.

[size=4][b]Compatibility[/b][/size]
[list]
[*][b]No edits to anyone's records[/b]: not vanilla, not the five mods. The Codex reads their settings and counters, calls two of their own script functions (the company's renown function and Contract Hunter's base pay), and adds its own items and recipes.
[*]If a future version of one of the five changes something the Codex relies on, only that link stops, with a note in the Papyrus log.
[*]Checked by loading it together with every mod in the series: no FormID, EditorID, script, global or file collisions.
[/list]

[size=4][b]Settings (console)[/b][/size]
[code]set BCX_Enabled to 0          (switch the bonuses off; 1 = on)
set BCX_RenownPerOath to 10
set BCX_BlessingFavor to 30 / set BCX_BlessingPayPct to 10
set BCX_BoonFavor to 80 / set BCX_BoonPayPct to 20[/code]

[size=4][b]Uninstalling[/b][/size]
Items you made stay in your save as long as the plugin is installed. As with any scripted mod, prefer not to remove it mid-playthrough; if you do, the five mods keep working on their own.

[size=4][b]Known issues / early beta limits[/b][/size]
[list]
[*]Not playtested in-game yet. Found something? Please post it in the Bugs tab.
[*]Bonuses arrive a few seconds after the payout (the Codex checks every 5 seconds instead of editing the other mods' scripts).
[*]The bounty bonus is based on base pay only, not on notoriety or hold standing.
[*]The Blade gets heat tiers, not an engraving: Ember Smithing engraves armor only.
[/list]

[size=4][b]Source[/b][/size]
Open source (MIT): [url=https://github.com/synthalorian/blackshield-codex]github.com/synthalorian/blackshield-codex[/url]

[size=4][b]Credits[/b][/size]
[list]
[*][url=https://github.com/Mutagen-Modding/Mutagen]Mutagen[/url] by Noggog and contributors, which generates the plugin from code.
[*][url=https://github.com/russo-2025/papyrus-compiler]papyrus-compiler[/url] by russo-2025, the open-source Papyrus compiler.
[*][url=https://github.com/GandaG/fomod-schema]FOMOD schema[/url] by GandaG.
[*]Bethesda Game Studios for Skyrim.
[/list]
```
