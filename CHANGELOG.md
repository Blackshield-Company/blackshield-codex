# Changelog

All notable changes to this project are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-10-06

Early beta. First public release. It passes every automated check in the build (Papyrus compile against the first-wave scripts, plugin validation with every link into the five masters resolved, round trip, SEQ check, FOMOD schema, cross-mod compatibility check) but has not been playtested in-game yet. Please report problems on the Nexus page or on GitHub.

### Added
- **Steel Oath x Blackshield Company:** every oath you keep through a Blackshield contract (sworn when you take it, still active when it pays out) adds 10 company renown (`BCX_RenownPerOath`), through Blackshield Company's own renown function, so promotions happen as usual.
- **Bounties of Oblivion x Contract Hunter:** when you claim a Contract Hunter bounty, your highest favor with any Daedric prince adds a bonus: +10% of the bounty's base pay at Blessing favor (30+), +20% at Boon favor (80+). Contract Hunter's pay multiplier applies to the bonus too.
- **Ember Smithing x Blackshield Company:** forge recipes for the Blackshield gear, following Ember Smithing's own rules:
  - Blackshield Blade: Heat-Tempered, Ember-Forged and Dragonfire tiers (damage 11 / 12 / 13 instead of 10), keeping its Ember Edge enchantment.
  - Blackshield Shield and Blackshield Plate: Ember-, Hearth- and Bellows-Engraved variants that keep the Blackshield enchantment and add the engraving (fire resistance 20%, frost resistance 20%, or 25% faster stamina regeneration).
  - Tempering recipes for all nine new items (they're enchanted, so tempering needs Arcane Blacksmith, as in vanilla).
- Settings as console globals, and an on/off switch (`BCX_Enabled`).
- FOMOD installer with optional Papyrus sources.
