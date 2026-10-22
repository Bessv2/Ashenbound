# Current status

The live state of the project against the charter in [CLAUDE.md](../CLAUDE.md).
Update this file whenever a milestone's state, a decision or the next task
changes. The full history of what was built, and how it was checked, is in
[IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md).

**Last updated:** 2026-10-22

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
| 2026-10-21 | **A browser build is a playtest preview** ([WEB_PREVIEW.md](WEB_PREVIEW.md)), not a platform change: Android stays the target. |

## Milestones

| Milestone | State | Notes |
|---|---|---|
| 0: Repository and toolchain baseline | Verified in runtime | Imports cleanly, runs, tests pass, a debug APK exports and its signature verifies. |
| 1: Movement and camera | Verified in runtime | **Device gate blocked:** there is no Android device, and no `/dev/kvm` for an emulator. The manual checklist is in [BUILD_ANDROID.md](BUILD_ANDROID.md#manual-device-checklist). |
| 2: Combat foundation | In progress | See below. |
| 3: First dungeon | Validated, verified in runtime | Spec: [dungeons/ashen_crypt.md](dungeons/ashen_crypt.md). All six steps done; the gate (three runs in a row, clean, paid once each) passes in automated tests. **Device check open.** PRs #15 to #20, stacked. |
| 4: First loot loop | Validated, verified in runtime | Design: [LOOT.md](LOOT.md). All five steps done; the gate (restart restores bag, gear and Ash; stats verified in combat) passes in automated tests. **Device check open.** |
| Progression (XP, levels, skill trees) | Validated, verified in runtime | Design: [SKILL_TREES.md](SKILL_TREES.md). Warden tree playable; Reaver and Hexbinder trees as previews. PR #24. |
| Visual pass | Validated, verified in runtime | Hit sparks, slash arcs, death bursts, camera shake with an off switch. PR stacked on #24. |
| Crypt tiers | Validated, verified in runtime | [dungeons/tiers.md](dungeons/tiers.md): ten tiers, unlocked by clears, scaling enemies and rewards. PR stacked on the visual pass. |
| 5 to 7 | Not started | |

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

PRs #1 to #5 and #7 to #12 were merged into `main` on 2026-10-21, at the
owner's request, so the web preview could be published from `main`.

| PR | Branch | State |
|---|---|---|
| #15 to #24 | `feature/m3-…`, `feature/m4-…`, `feature/skill-trees` | Open drafts, **stacked**: each is based on the one before, so they merge in order starting with #15. |
| #6 | `feature/loot` | Open draft, **parked** until Milestone 4. It is based on `feature/dodge-skills` and predates the charter's six rarities and nine slots. |

## Deviations from the charter

- **Names:** the hero is the Warden. The main scene's slot for it is still
  called `Player`, because that slot will hold any class. The arena is not yet
  framed as the Fallen Marches.
- **Art ahead of schedule:** the owner asked for a first art pass before
  Milestone 3. It uses third-party CC0 models
  ([ART_ASSET_PIPELINE.md](ART_ASSET_PIPELINE.md)), not final art.
- **Docs:** there is no `GAME_DESIGN.md` or `TEST_PLAN.md` yet. The test
  approach is described in [ARCHITECTURE.md](ARCHITECTURE.md#tests).
- **Concept art location:** the art is in `docs/art/`. That is outside the
  game folder, as the charter requires, but is not called `art_reference/`.

## Next task

**Gold, salvage and upgrades**: enemies and salvaged items give gold; gold
and Ash raise an item's level. This gives every drop a use and the tiers
something to spend on.

Then offline rewards (Milestone 6, capped at 8 hours, on the local clock and
marked provisional until the Milestone 5 server exists), farming the highest
tier cleared; then a second playable class (Reaver).

Device checks for Milestones 1 to 4 are still open: they need the Android app
on a phone ([DEVICE_TESTING.md](DEVICE_TESTING.md)). The owner's playtests so
far were in the [web preview](WEB_PREVIEW.md), which does not count as a device
check (another renderer, and a browser rather than the app).
