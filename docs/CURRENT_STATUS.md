# Current status

The live state of the project against the charter in [CLAUDE.md](../CLAUDE.md).
Update this file whenever a milestone's state, a decision or the next task
changes. The full history of what was built, and how it was checked, is in
[IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md).

**Last updated:** 2026-10-21

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
| 2026-10-21 | **A browser build is a playtest preview** ([WEB_PREVIEW.md](WEB_PREVIEW.md)), not a platform change: Android stays the target. |

## Milestones

| Milestone | State | Notes |
|---|---|---|
| 0: Repository and toolchain baseline | Verified in runtime | Imports cleanly, runs, tests pass, a debug APK exports and its signature verifies. |
| 1: Movement and camera | Verified in runtime | **Device gate blocked:** there is no Android device, and no `/dev/kvm` for an emulator. The manual checklist is in [BUILD_ANDROID.md](BUILD_ANDROID.md#manual-device-checklist). |
| 2: Combat foundation | In progress | See below. |
| 3: First dungeon | Not started | |
| 4: First loot loop | Parked | PR #6 |
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

## Open pull requests

Each PR is stacked on the one before it. Merge them in order.

| PR | Branch | Content | CI |
|---|---|---|---|
| #1 | `ccr-f0dcdd15-eok91q` | Foundation, movement, camera, HUD, pause, CI, basic attack | Green |
| #2 | `feature/enemy-ai` | Player health and death, Hollow, spawner | Green |
| #3 | `feature/enemy-navigation` | Navigation mesh and path following | Green |
| #4 | `feature/art-reference` | Concept sheet and art direction (docs) | Green |
| #5 | `feature/dodge-skills` | Dodge | Green |
| #6 | `feature/loot` | Loot (**parked, do not merge**) | |
| #7 | `docs/project-charter` | This file and `CLAUDE.md` | |
| #8 | `feature/warden-abilities` | The Warden and its three starter abilities | |
| #9 | `feature/enemy-states` | The Hollow's states split to match the charter | Green |
| #10 | `feature/device-testing` | PerfLog, `tools/device-test.sh`, device-test procedure | Green |
| #11 | `feature/ci-emulator` | Device test on a CI emulator (start-up and stability only) | Green |
| next | `feature/web-preview` | Browser build for playtesting on a phone | | |

## Deviations from the charter

- **Names:** the hero is the Warden. The main scene's slot for it is still
  called `Player`, because that slot will hold any class. The arena is not yet
  framed as the Fallen Marches. The enemy now looks like a Skeleton Warrior but
  is still called the Hollow in code; the rename comes with Milestone 3.
- **Art ahead of schedule:** the owner asked for a first art pass before
  Milestone 3. It uses third-party CC0 models
  ([ART_ASSET_PIPELINE.md](ART_ASSET_PIPELINE.md)), not final art.
- **Docs:** there is no `GAME_DESIGN.md` or `TEST_PLAN.md` yet. The test
  approach is described in [ARCHITECTURE.md](ARCHITECTURE.md#tests).
- **Concept art location:** the art is in `docs/art/`. That is outside the
  game folder, as the charter requires, but is not called `art_reference/`.

## Next task

Start Milestone 3, the first dungeon, with a specification before any code,
as for the Warden. The spec covers:

- the encounter controller and its waves;
- one elite;
- the first boss, with distinct phases;
- victory and defeat;
- a reward summary;
- reset and replay.

The content is decided (see Owner decisions): Skeleton Warriors and Dark
Cultists in the waves, a Fallen Knight elite, and the Ashen Lord as the boss.

Before that, the owner tests a demo build on an Android device. Its results
close the device checks for Milestones 1 and 2. The [web preview](WEB_PREVIEW.md)
can show the feel of the controls in a phone's browser, but it does not count
as a device check: it uses a different renderer and a browser, not the app. The owner chose to run the
test with Claude Code on their own computer and a USB-connected phone. The
procedure is [DEVICE_TESTING.md](DEVICE_TESTING.md): `tools/device-test.sh`
plus hand checks.
