# Current status

The live state of the project against the charter in [CLAUDE.md](../CLAUDE.md).
Update this file whenever a milestone's state, a decision or the next task
changes. The full history of what was built, and how it was checked, is in
[IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md).

**Last updated:** 2026-10-23

Status labels follow the charter:

| Label | Meaning |
|---|---|
| Implemented | The code exists. |
| Validated | Automated checks ran and passed. |
| Verified in runtime | Launched and observed; here, rendered under Xvfb with software Vulkan. |
| Verified on device | Tested on a physical Android phone. |
| Blocked | Something outside the code prevents the check. |

## Owner decisions

| Date | Decision |
|---|---|
| 2026-10-21 | Continue development past Milestone 0 before device verification ("Feel free to autonomously continue developing"). |
| 2026-10-21 | **Loot is parked** until Milestone 4. Draft PR #6 holds the early loot work, which predates the charter: five tiers and three slots, against the charter's six tiers and nine slots. |
| 2026-10-21 | The charter is committed as `CLAUDE.md`. |
| 2026-10-21 | **The Warden's starter abilities are Cleave, Bulwark Guard and Ember Brand**, one per specialization direction. Skill trees for each class come later and are designed per class. |
| 2026-10-21 | **Milestone 3 content:** the first boss is **the Ashen Lord**, with distinct phases. **Skeleton Warriors** are the basic enemy and replace the placeholder Hollow; a **Dark Cultist** is the ranged second type; a **Fallen Knight** is the elite. |
| 2026-10-21 | Test a demo build on an Android device before Milestone 3 work starts. The owner's phone is their daily driver, so cloud options were explored: the CI emulator proves the game starts without crashing but cannot draw it. |
| 2026-10-21 | **Art pass now**, ahead of Milestone 3, with free CC0 assets (KayKit), keeping Godot. |
| 2026-10-21 | Owner playtest of the art pass in the web preview on their phone: "The play tests were great!" Continue with the milestones. |
| 2026-10-21 | **Long-term vision:** "a Diablo 4 style game with Torchlight levels of classes and a full loot system", where being offline still earns XP, gold and loot resources. Work through the milestones in order to a working gameplay loop first, then add skills, attacks and systems. Offline XP extends the charter's offline rewards (Milestone 6). |
| 2026-10-22 | "Keep going, and dev as many milestones as you can. Up the gameplay loop, better visuals and start a skill tree for the first 3 classes or all 6 classes." |
| 2026-10-22 | "Merge them all, keep going with the Hexbinder … make the visuals 100x better and let's start to put some life into the UI." Done in PRs #32 and #33, merged. |
| 2026-10-22 | "Go ahead and keep building more of the gameplay." Next: champions and potions, then the Dreadhunter. |
| 2026-10-22 | "Merge them and keep going with a second dungeon. You don't have to check in with me to merge them. I want a fully playable test version of the game with mechanics we talked about by today." |
| 2026-10-22 | The charter was updated to v2.0 (`CLAUDE.md`) and reconciled with the repository. |
| 2026-10-23 | "The graphics are still too basic. Too cartoony." Two directions named: (A) cartoony characters with realistic attack animations and effects, or (B) hyper-realistic characters and atmosphere with Castle Crashers-style effects. The owner chose to **see both first**: [ART_STYLE_TEST.md](ART_STYLE_TEST.md). **Pending: the owner's pick.** |
| 2026-10-23 | The owner opened the environment's network to asset sites: "I opened up network access. Go wild." Acquiring free (CC0) resource packs began with sound: [AUDIO.md](AUDIO.md). |
| 2026-10-23 | **Look B chosen**: "Look B is really nice but it's extremely poor performance. I like the effects better. Look A is just a cooler toned classic." Look B is now the default; its cost was cut (see [ART_STYLE_TEST.md](ART_STYLE_TEST.md#performance)). Classic and look A stay selectable until look B is confirmed on the owner's phone. |
| 2026-10-23 | **The web preview always reflects `main`**: every merge publishes it ([WEB_PREVIEW.md](WEB_PREVIEW.md#publishing)). |
| 2026-10-23 | **Build the concept sheet's game**: its HUD, menus, crafting, more regions and Demons ("2 3 4 5 should be achieved easily"), as "something of a full game like idle miner. Or Diablo 4 style mechanics", with Idle Pocket Crafter 2 as the baseline for active play against idle time. Plan and mapping: [GAME_LOOP.md](GAME_LOOP.md). Realistic characters (gap 1) are not in this order. |
| 2026-10-21 | **A browser build is a playtest preview** ([WEB_PREVIEW.md](WEB_PREVIEW.md)), not a platform change: Android stays the target. |

## Milestones

| Milestone | State | Notes |
|---|---|---|
| 0: Repository and toolchain baseline | Verified in runtime | Imports cleanly, runs, tests pass, a debug APK exports and its signature verifies. |
| 1: Movement and camera | Verified in runtime | **Device gate blocked:** there is no Android device, and no `/dev/kvm` for an emulator. The manual checklist is in [BUILD_ANDROID.md](BUILD_ANDROID.md#manual-device-checklist). |
| 2: Combat foundation | In progress | See below. |
| 3: First dungeon | Validated, verified in runtime | Spec: [dungeons/ashen_crypt.md](dungeons/ashen_crypt.md). All six steps done; the gate (three runs in a row, clean, paid once each) passes in automated tests. **Device check open.** PRs #15 to #20, stacked. |
| 4: First loot loop | Validated, verified in runtime | Design: [LOOT.md](LOOT.md). All five steps done; the gate (restart restores bag, gear and Ash; stats verified in combat) passes in automated tests. **Device check open.** |
| Progression (XP, levels, skill trees) | Validated, verified in runtime | Design: [SKILL_TREES.md](SKILL_TREES.md). Warden tree playable; the other five classes' trees as previews (PR #24 and the six-trees PR). |
| Visual pass | Validated, verified in runtime | Hit sparks, slash arcs, death bursts, camera shake with an off switch. PR stacked on #24. |
| Crypt tiers | Validated, verified in runtime | [dungeons/tiers.md](dungeons/tiers.md): ten tiers, unlocked by clears, scaling enemies and rewards. PR stacked on the visual pass. |
| Gold, salvage and upgrades | Validated, verified in runtime | [LOOT.md](LOOT.md#gold-salvage-and-upgrades). PR stacked on the crypt tiers. |
| Offline rewards | Validated, verified in runtime; **provisional** (device clock) | [OFFLINE_REWARDS.md](OFFLINE_REWARDS.md): highest tier cleared, half a run per hour, 8-hour cap. Milestone 6 groundwork, ahead of Milestone 5. |
| Second class: Reaver | Validated, verified in runtime | [characters/reaver.md](characters/reaver.md): Twin Slash, Veil Rend, Fan of Blades, Hemorrhage; playable tree; class switch. |
| Third class: Hexbinder | Validated, verified in runtime | [characters/hexbinder.md](characters/hexbinder.md): Hex Bolt, Black Testament, Grasp of the Grave, Unmake; playable tree. |
| Concept HUD | Validated, verified in runtime | [UI.md](UI.md#the-hud): portrait, blue XP bar, minimap, icon buttons (game-icons.net, CC BY 3.0), red damage numbers, crescent slashes. |
| Visuals and living UI | Validated, verified in runtime | [UI.md](UI.md): fire, dust, grade, vignette, outlines, hit punch; health trail, banners, coloured buttons; title screen with class select. |
| Second dungeon: the Forgotten Catacombs | Validated, verified in runtime | [dungeons/forgotten_catacombs.md](dungeons/forgotten_catacombs.md): opens after a crypt clear. Ghouls, three combat rooms, and the Hollow King (volley, spikes, nova, Ghoul adds); dungeon choice on the title screen. |
| Art style test: Look A against Look B | Validated, verified in runtime | [ART_STYLE_TEST.md](ART_STYLE_TEST.md): a title-screen switch (Classic, A, B) restyles characters, the world, the grade, hits, kills and swings; both looks add hit-stop and lunges. Classic stays the default until the owner chooses. |
| Fifth and sixth classes: Reliquary and Gravecaller | Validated, verified in runtime | [characters/reliquary.md](characters/reliquary.md), [characters/gravecaller.md](characters/gravecaller.md). All six classes are playable, with playable trees. Reliquary: capped heals, a lantern, a health-cost smite with safeguards, zeal. Gravecaller: skeleton summons with defined lifetime and cleanup, marking wraiths, soul harvest. |
| Sound and music | Validated, verified in runtime (mix measured; not listened to) | [AUDIO.md](AUDIO.md): 65 cues and 6 tracks, all CC0 (Kenney, OpenGameArt), rebuilt from source by `tools/audio/`. Combat, enemy telegraphs, abilities, loot, gates, interface, and music that follows the run; volume sliders in the pause menu. |
| Effect sprites and photographed stone | Validated, verified in runtime | [ART_ASSET_PIPELINE.md](ART_ASSET_PIPELINE.md#effect-sprites-and-photographed-stone-2026-10-23): Kenney's particle sprites (CC0) for sparks, smoke, debris, fire, shockwaves and scorch marks in every look, and on the torches; Poly Haven stone (CC0) on look B's floors and walls, which also fixes look B leaving the tiled floors and walls undressed. |
| Motion-captured animation (looks A and B) | Validated, verified in runtime | [ANIMATION.md](ANIMATION.md): 28 CC0 mocap clips (Quaternius) retargeted onto the KayKit rig: sword combos, shield bash, spellcasting, hits, deaths, zombie ghouls. Classic keeps its clips. |
| Fourth class: Dreadhunter | Validated, verified in runtime | [characters/dreadhunter.md](characters/dreadhunter.md): crossbow, Deadfall, Charged Shot, Carrion Raven; playable tree. |
| Champions and health potions | Validated, verified in runtime | [CHAMPIONS.md](CHAMPIONS.md): ordinary enemies may rise as champions with affixes (Hasted, Stoneskin, Vampiric, Ember-wreathed, Vengeful) and a guaranteed Rare drop; three potions per run, refilled by kills. |
| 5 to 7 | Not started | Offline rewards above are early Milestone 6 work. |

### Milestone 2 progress

| Item | State |
|---|---|
| Health and damage, death exactly once | Validated, verified in runtime |
| Targeting and range (basic attack, aim assist) | Validated, verified in runtime |
| Basic attack | Validated, verified in runtime |
| Dodge with cooldown and an invulnerable window | Validated, verified in runtime (PR #5) |
| Three abilities | Validated, verified in runtime: Cleave, Bulwark Guard, Ember Brand |
| Enemy states (idle, approach, telegraph, attack, recovery, death) | Validated: separate states with tested order and timing |
| Hit feedback, HUD, pause and lifecycle handling | Validated, verified in runtime |
| Manual checks on a device | Blocked |

Milestone 2 is complete apart from its device check, which stays blocked
until a phone is available.

## Pull requests

Everything up to #33 (the Hexbinder, then visuals and the living UI) is
merged into `main`, apart from #6.

| PR | Branch | State |
|---|---|---|
| #34 | `feature/champions` | Merged: champions and health potions. |
| #35 | `feature/dreadhunter` | The Dreadhunter; merged once its checks pass. |
| #36 to #38 | `feature/second-dungeon`, `feature/full-roster` | Merged: the catacombs and the full roster. |
| #39 | `feature/style-lab` | Merged: the art style test. |
| #40 | `feature/audio` | Merged: sound and music. |
| #41 | `feature/vfx-pack` | Merged: effect sprites and photographed stone. |
| #42 | `feature/mocap` | Merged: motion-captured animation for looks A and B. |
| (new) | `feature/look-b-perf` | Look B as the default, made faster; the preview publishes on every merge. |
| #6 | `feature/loot` | Open draft, **obsolete**: the early loot work, superseded by Milestone 4's loot. Kept for reference; it can be closed. |

## Deviations from the charter

- **Offline rewards before the backend:** the charter puts them in Milestone
  6, with trusted server time. The owner asked for them early; they use the
  device clock and are marked provisional until Milestone 5
  ([OFFLINE_REWARDS.md](OFFLINE_REWARDS.md)).

- **Names:** the hero is the Warden. The main scene's slot for it is still
  called `Player`, because that slot will hold any class. The arena is not yet
  framed as the Fallen Marches.
- **Dreadhunter's weapon:** a heavy crossbow instead of the charter's
  longbow, because the free model set has no bow. Its companion is a raven
  built from primitives ([characters/dreadhunter.md](characters/dreadhunter.md#deviations)).
- **Art ahead of schedule:** the owner asked for a first art pass before
  Milestone 3. It uses third-party CC0 models
  ([ART_ASSET_PIPELINE.md](ART_ASSET_PIPELINE.md)), not final art.
- **Docs:** there is no `GAME_DESIGN.md` or `TEST_PLAN.md` yet. The test
  approach is described in [ARCHITECTURE.md](ARCHITECTURE.md#tests).
- **Concept art location:** the art is in `docs/art/`. That is outside the
  game folder, as the charter requires, but is not called `art_reference/`.

## Next task

Build the rest of [GAME_LOOP.md](GAME_LOOP.md#order-of-work), in order:
1. The menus from the concept sheet: character stats, an inventory grid
   with item icons, gold and Ash in the header, quests, and dungeon cards.
2. Materials, the crafting chain, and gathering camps that work while away.
3. New regions and Demons.
4. Quests, achievements and daily challenges.

Still open from the owner: whether look B runs well enough on their phone
since fog and phone shadows were cut
([ART_STYLE_TEST.md](ART_STYLE_TEST.md#performance)). If not, the next cuts
are a lower 3D resolution on phones, then fewer torch lights and less glow.

Device checks for Milestones 1 to 4 are still open: they need the Android app
on a phone ([DEVICE_TESTING.md](DEVICE_TESTING.md)). The owner's playtests so
far were in the [web preview](WEB_PREVIEW.md), which does not count as a device
check (another renderer, and a browser rather than the app).
