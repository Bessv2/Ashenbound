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
| Three abilities | Next: Cleave, Bulwark Guard, Ember Brand |
| Enemy states (idle, approach, telegraph, attack, recovery, death) | Behavior implemented, see below |
| Hit feedback, HUD, pause and lifecycle handling | Validated, verified in runtime |
| Manual checks on a device | Blocked |

The Hollow has the behaviors the charter lists, but folds telegraph, attack
and recovery into one attack state: telegraph during the windup, then the hit,
then recovery. Splitting them into separate states is open work.

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
| next | `docs/project-charter` | This file and `CLAUDE.md` | |

## Deviations from the charter

- **Names:** the hero is still a generic player scene; it becomes the Warden
  in the next task. The arena is not yet framed as the Fallen Marches. The
  Hollow is a placeholder enemy that is not on the charter's list.
- **Docs:** there is no `GAME_DESIGN.md` or `TEST_PLAN.md` yet. The test
  approach is described in [ARCHITECTURE.md](ARCHITECTURE.md#tests).
- **Concept art location:** the art is in `docs/art/`. That is outside the
  game folder, as the charter requires, but is not called `art_reference/`.

## Next task

The Warden's three starter abilities, one at a time:

1. Specify them in `docs/characters/warden.md`, as charter section 13.1
   requires before implementation.
2. Turn the player scene into the Warden, with a greatsword placeholder.
3. Implement Cleave, then Bulwark Guard, then Ember Brand, each with tests
   and a HUD button.
