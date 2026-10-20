![blackshield-codex](.github/preview.png)

# Blackshield Codex

An optional **integration plugin** for Skyrim Special Edition that ties together the five first-wave mods of the series: [Blackshield Company](https://github.com/synthalorian/blackshield-company), [Bounties of Oblivion](https://github.com/synthalorian/bounties-of-oblivion), [Contract Hunter](https://github.com/synthalorian/contract-hunter), [Steel Oath](https://github.com/synthalorian/steel-oath) and [Ember Smithing](https://github.com/synthalorian/ember-smithing). Each of those works on its own; the Codex makes them notice each other.

**Status: v0.1.0, early beta.** It passes every automated check in the build (Papyrus compile against the first-wave scripts, plugin validation with every link into the five masters resolved by FormID and type, byte-exact round trip, SEQ check, FOMOD schema, cross-mod compatibility check) but has not been playtested in-game yet. Expect rough edges and please report what you find. See [docs/TESTING.md](docs/TESTING.md).

- Game: Skyrim Special Edition / Anniversary Edition 1.6.x (also fine on 1.5.97). Works on Windows and on Linux through Proton.
- **Requires all five first-wave mods** (0.1.0 or later). No SKSE, no SkyUI, no DLC, no Creation Club content.
- Plugin: `BlackshieldCodex.esp`, ESL-flagged. Masters: Skyrim.esm, BlackshieldCompany.esp, BountiesOfOblivion.esp, ContractHunter.esp, SteelOath.esp, EmberSmithing.esp (all ESL-flagged ESPs, which is fine as masters). Load it after them.
- **No edits** to vanilla records or to any of the five mods' records. The Codex only reads their globals, calls two public functions in their scripts, and adds its own recipes and items. The exact list is in [docs/DESIGN.md](docs/DESIGN.md#what-the-codex-reads-from-the-other-mods).

## What it does

| Link | Effect |
|---|---|
| Steel Oath x Blackshield Company | Every oath you keep through a Blackshield contract (active when you take it and still active when it pays) adds **+10 company renown** (`BCX_RenownPerOath`). Up to three oaths, so up to +30 on top of the contract's 40-60. Promotions trigger as usual. |
| Bounties of Oblivion x Contract Hunter | When you claim a bounty, your **highest favor with any Daedric prince** adds **+10%** of the bounty's base pay at Blessing favor (30+) or **+20%** at Boon favor (80+). |
| Ember Smithing x Blackshield Company | At the forge: **Heat-Tempered, Ember-Forged and Dragonfire** Blackshield Blades (damage 11 / 12 / 13 instead of 10, enchantment kept), and **Ember-, Hearth- and Bellows-Engraved** Blackshield Shields and Plates (Blackshield enchantment kept, engraving added). All nine can be tempered (Arcane Blacksmith, as for any enchanted item). |

A short notification in the top-left corner tells you when a bonus is paid.

### Recipes

| Item | Needs | Smithing | Perk |
|---|---|---|---|
| Heat-Tempered Blackshield Blade (11 dmg) | Blackshield Blade, Ebony Ingot, 2 Firewood | 20 | Ebony Smithing |
| Ember-Forged Blackshield Blade (12 dmg) | Heat-Tempered Blackshield Blade, Ebony Ingot, 2 Charcoal | 45 | Ebony Smithing |
| Dragonfire Blackshield Blade (13 dmg) | Ember-Forged Blackshield Blade, 2 Ebony Ingots, Fire Salts | 70 | Ebony Smithing |
| Ember-Engraved Blackshield Shield / Plate (+20% fire resistance) | the Shield or Plate, Silver Ingot, Fire Salts | 30 | Ebony Smithing (Shield) / Advanced Armors (Plate) |
| Hearth-Engraved Blackshield Shield / Plate (+20% frost resistance) | the Shield or Plate, Silver Ingot, Frost Salts | 30 | as above |
| Bellows-Engraved Blackshield Shield / Plate (stamina regenerates 25% faster) | the Shield or Plate, Silver Ingot, 2 Charcoal | 30 | as above |

Recipes only show at the forge while you carry the item they start from (Ember Smithing's rule). Tempering: Ebony Ingot for the Blade and Shield, Corundum Ingot for the Plate.

### Settings (console)

```
set BCX_Enabled to 0            ; switch all script bonuses off (1 = on); nothing is paid retroactively
set BCX_RenownPerOath to 10     ; renown per oath kept through a contract
set BCX_BlessingFavor to 30     ; favor needed for the smaller bounty bonus
set BCX_BlessingPayPct to 10    ; ... and its size in percent of base pay
set BCX_BoonFavor to 80         ; favor needed for the larger bonus
set BCX_BoonPayPct to 20
set BCX_PollSeconds to 5        ; how often (real seconds, not in menus) the Codex looks for finished contracts
```

Stats: `BCX_RenownAwarded` and `BCX_GoldAwarded` (read with `show BCX_GoldAwarded`).

## Graceful degradation

- The bonuses only happen when the systems are in use: no Blackshield contracts, no oath, no bounty or no Daedric favor simply means nothing extra.
- Every property that points into another mod is checked before use; if a future version of one of those mods drops a record, that one link stops (and says so in the Papyrus log with a `BCX_` line) while the rest keep working.
- Installed mid-game: the current state is taken as the starting point and nothing is paid for the past. A contract already running at install counts the oaths active at payout.
- Turning it off (`BCX_Enabled 0`) keeps watching the counters, so switching back on never pays for the time it was off.
- Without the five masters the game cannot load the plugin at all; that's why the links live in this separate, optional file instead of in the five mods.

## Building

`./build.sh` on Linux builds the release zip from this repo. The five first-wave plugins are vendored in `masters/plugins` (the released 0.1.0 files, checked against `masters/SHA256SUMS`) and their script sources in `masters/scripts`: the generator copies the Blackshield gear and the enchantment effects from them and the validator resolves every link into them by FormID and type; Papyrus type-checks the Codex's calls into their scripts. None of those files are packaged. Needs .NET SDK 9+, python3, curl and optionally xmllint. See [tools/modkit/README.md](tools/modkit/README.md).

## Layout

```
src/plugin/BlackshieldCodex.Generator/   C# generator (quest, globals, items, enchantments, recipes)
src/plugin/formids.json                  pinned FormIDs
src/papyrus/                             the Codex quest and player alias scripts
masters/                                 build-time copies of the five first-wave plugins and their script sources
fomod/                                   FOMOD installer config
tools/modkit/                            shared build tooling (Mutagen helpers, validator, Papyrus, FOMOD, compat check)
docs/                                    design notes, testing checklist, Nexus page
```

## Credits

- Built with [Mutagen](https://github.com/Mutagen-Modding/Mutagen) and [russo-2025/papyrus-compiler](https://github.com/russo-2025/papyrus-compiler).
- Skyrim belongs to Bethesda Softworks. This mod references Skyrim.esm and ships no Bethesda assets.

## Support

Donations are optional. Nothing in the mod is gated on them.

- GitHub Sponsors: https://github.com/sponsors/synthalorian
- Ko-fi: https://ko-fi.com/synthalorian

## License

MIT (code and text in this repository). See [LICENSE](LICENSE).

## Support

Donations are optional. Nothing in the mod is gated on them.

- GitHub Sponsors: https://github.com/sponsors/synthalorian
- Ko-fi: https://ko-fi.com/synthalorian

<p><img src="docs/knight-a.gif" width="64" height="56" alt="Knight A, the Blackshield Company mascot"><br><sub>A <a href="https://github.com/synthalorian">Blackshield Company</a> mod.</sub></p>
