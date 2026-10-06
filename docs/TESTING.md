# Testing checklist (v0.1.0, early beta)

Automated (every `./build.sh`):

- [x] Vendored master files match `masters/SHA256SUMS`.
- [x] Papyrus compiles; the calls into `BSC_CompanyScript` and `CHT_HunterScript` are type-checked against their sources.
- [x] Plugin validation: ESL range, masters exactly Skyrim.esm + the five in order, every link into the five masters resolves to a record of the right type, script properties match their declarations, alias script base types, SEQ file contents, byte-exact round trip.
- [x] FOMOD schema.
- [x] Cross-mod check (`tools/modkit/Modkit.Compat`) with every released mod of the series: no FormID, EditorID, script, global or file collisions, no overrides.

In game (not done yet; please help):

Setup: install the five first-wave mods and the Codex, start or load a game, wait a few seconds, then `sqv BCX_CodexQuest` should show the quest running. With Papyrus logging on, `BCX_ init` or `BCX_ loaded` lines name what was found.

1. **Oaths and contracts**
   - [ ] Join the Blackshield Company, swear one or two Steel Oaths, take a contract and finish it without breaking them. A few seconds after the payout: notification "N oath(s) kept ... +X company renown", and the ledger's renown is higher by 10 per oath.
   - [ ] Take a contract without any oath: no notification.
   - [ ] Swear an oath *after* taking the contract: it doesn't count.
   - [ ] Break an oath during the contract: it doesn't count.
   - [ ] Renown pushing you past a rank threshold promotes you (company's own message).
2. **Daedric favor and bounties**
   - [ ] With every prince's favor below 30 (`show BOO_FavorDagon` etc.), claim a bounty: no bonus.
   - [ ] `set BOO_FavorDagon to 35`, claim a Notice: +10% of the base pay (150 + 10 x level, times `CHT_PayMult`) arrives as a notification and in your gold.
   - [ ] `set BOO_FavorDagon to 85`, claim a Wanted or Dread bounty: +20% of that tier's base pay.
3. **Forge**
   - [ ] With Smithing 20+, Ebony Smithing and a Blackshield Blade in your pack, the forge lists the Heat-Tempered Blackshield Blade; making it consumes the Blade, an Ebony Ingot and 2 Firewood. Next tiers appear at 45 and 70.
   - [ ] Engravings appear at Smithing 30 with Ebony Smithing (Shield) / Advanced Armors (Plate) while you carry the piece; the result shows both effects (e.g. Fortify Block 15% and fire resistance 20%).
   - [ ] Tempering works with Arcane Blacksmith at the grindstone / armor table.
4. **Switch and degradation**
   - [ ] `set BCX_Enabled to 0`, finish a contract with an oath: no bonus. Switch back on: no retroactive bonus.
   - [ ] Install the Codex mid-game with a contract running: finishing it with an active oath pays the bonus.
