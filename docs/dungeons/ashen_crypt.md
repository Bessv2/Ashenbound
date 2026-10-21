# The Ashen Crypt: first dungeon specification

Milestone 3 (charter section 6): an encounter controller, waves, an elite, a
boss with distinct phases, victory and defeat, a reward summary, and reliable
reset and replay. The content was decided by the owner on 2026-10-21: Skeleton
Warriors and Dark Cultists in the waves, a Fallen Knight elite, and the Ashen
Lord as the boss.

**Status:** specification, being built. Steps 1 and 2 of the build order are
done; the rest is not implemented yet. Numbers are first-pass tuning to be adjusted in playtests.

**Gate (charter):** multiple consecutive runs complete correctly with no stale
state or duplicate rewards.

## The run in one paragraph

The Warden descends into a crypt in the Fallen Marches. Four rooms in a line,
joined by short corridors: a quiet **Gatehouse**, the **Ossuary Hall** (two
waves of skeletons), the **Cultist Chapel** (casters, then the Fallen Knight),
and the **Ashen Throne**, where the Ashen Lord waits. Stepping into a combat
room seals its doors until the room is cleared. Killing the Ashen Lord wins
the run; dying loses it. Either way a summary shows time, kills and the reward,
and the run can be played again from the start. One run should take 5 to 8
minutes.

## Layout

Built from the KayKit dungeon pieces already in the game (see
[ART_ASSET_PIPELINE.md](../ART_ASSET_PIPELINE.md)), on the same 4 m grid.
Sizes are interior floor space.

| Room | Size | Contents |
|---|---|---|
| Gatehouse | 12 × 12 m | Start point, two torches, no enemies. The door north opens at once. |
| Ossuary Hall | 20 × 20 m | Encounter 1. Four pillars for cover. Doors south (in) and north (out). |
| Cultist Chapel | 20 × 24 m | Encounter 2. A raised altar at the north end (no height gameplay yet). |
| Ashen Throne | 28 × 28 m | Boss arena, open floor, four braziers. Entry door only. |

- **Corridors:** 4 m wide, 8 m long, between each pair of rooms.
- **Doors:** a gate in the north wall of every room but the Throne: the KayKit
  doorway with a 2 m door (the pack has no portcullis). While closed it blocks
  movement and the navigation mesh. Entering a combat room (2 m past the
  doorway) shuts the door behind the player (the previous room's gate) and
  the room's own exit; both open when the room's encounter is cleared. The
  Gatehouse door starts open.
- **Navigation:** one navigation mesh for the whole crypt. A closed gate splits
  it, so enemies cannot path through, and it is rebaked when the gate opens.
- **Camera:** unchanged (fixed orthographic, size 16 m). The near walls of every
  room stay low, as in the current arena. The far north walls are tall, and
  the hero walks behind them in each corridor, so they (and the gates and tall
  pillars) turn see-through in a small dithered circle around the hero.

## Enemies

All enemies share the existing systems (Health, MeleeAttack or a ranged attack,
the IDLE / APPROACH / TELEGRAPH / ATTACK / RECOVERY / DEAD states, navigation
and CharacterAnimator). Each type is one scene plus data resources. Models are
KayKit placeholders.

| Enemy | HP | Attack | Movement | Model |
|---|---|---|---|---|
| **Skeleton Warrior** (today's Hollow, renamed) | 30 | Chop, 12 damage, 0.5 s windup, 1.4 m reach | 3.4 m/s | Skeleton Warrior with blade |
| **Dark Cultist** | 24 | Shadow bolt: 0.7 s windup with a line telegraph, a projectile at 10 m/s, 10 damage, 12 m range, blocked by walls, dodgeable | Keeps 6 to 9 m away, backs off if the player is closer than 4 m | KayKit Mage, recoloured to black and violet |
| **Fallen Knight** (elite) | 140 | Overhead cleave, 26 damage, 0.9 s windup, 2 m reach, 100° arc. Every third attack is a shield bash: 1.2 m reach, 8 damage, pushes the player back 3 m | 2.6 m/s. Takes half damage from the front while not attacking | Skeleton Warrior at 1.25× with a large shield and axe, darker material |

The elite gets a health bar above it and a name label, so the player knows
this fight is different.

## Encounters

An encounter belongs to a room and is defined in data: a list of waves, each a
list of (enemy, count, spawn markers). The next wave starts 1.5 s after every
enemy of the current wave is dead. Enemies spawn with the skeleton
rise-from-the-ground clip, and are inert (not targetable, no AI) for its
0.8 s, so nothing hits the player before it can be seen.

| Encounter | Wave 1 | Wave 2 |
|---|---|---|
| Ossuary Hall | 3 Skeleton Warriors | 3 Skeleton Warriors, 1 Dark Cultist |
| Cultist Chapel | 2 Dark Cultists, 2 Skeleton Warriors | **Fallen Knight** with 2 Skeleton Warriors |

Clearing an encounter opens the room's exit gate and restores 30 health
(a brazier flares; the Warden is not invulnerable meanwhile).

## Boss: the Ashen Lord

A towering knight bound in ash and ember. **600 HP.** Placeholder model: the
KayKit Knight at 1.7× with an ash-black, ember-emissive material. A boss health
bar with its name runs along the top of the screen. The fight starts when the
player crosses into the Throne room: the door seals, the Lord rises from his
seat (1.5 s, invulnerable), then attacks.

| Phase | Health | Moves |
|---|---|---|
| **1. The Lord** | 100% to 60% | **Cinder Cleave:** 1.0 s windup, 3 m reach, 160° arc, 30 damage. **Ash Slam:** 1.2 s windup, a 4 m circle telegraphed on the floor under him, 35 damage. Alternates; slam when the player stays close. |
| **2. The Bound Dead** (at 60%) | 60% to 30% | Roars (2 s, invulnerable, no damage), then **summons 3 Skeleton Warriors** at the braziers, once. Adds **Ember Ring:** a ring of fire expanding from him to 10 m over 2 s, 20 damage, dodgeable through its i-frames or by being outside it. |
| **3. Unbound** (at 30%) | 30% to 0 | Roars again. All windups 25% shorter, movement 30% faster. Ember Ring every other attack. |

- Phase changes happen once each, in order, even if one hit skips past a
  threshold (a hit that takes him from 65% to 25% plays phase 2 and then
  phase 3).
- Adds summoned in phase 2 die when the Lord dies.
- The Lord's damage, like everything else, goes through Health. Visual
  effects never deal damage (charter).

## Victory, defeat and the summary

- **Victory:** the Ashen Lord dies. Remaining enemies die with him, input locks,
  and after 2 s the summary opens.
- **Defeat:** the player dies. The existing death screen becomes the defeat
  summary.
- Victory and defeat are **mutually exclusive**: whichever happens first ends
  the run. A player killed by an attack that was already in flight after the
  Lord died does not turn a victory into a defeat.
- **Summary:** result, time, enemies killed, damage taken, and the reward.
  Buttons: **Play again** (restarts the run from the Gatehouse) and, later,
  **Leave**.

## Rewards

Loot is parked until Milestone 4, so the first reward is a currency: **Ash**.

- 1 Ash per Skeleton Warrior, 2 per Dark Cultist, 10 for the Fallen Knight,
  50 for the Ashen Lord; a defeat keeps the Ash already earned in that run.
- The total is shown in the summary and granted **once**, when the summary
  opens. Replaying starts a new run with a new count.
- Ash is not saved yet (save/load is Milestone 4). The grant goes through one
  function so persistence and server validation can hook in later without
  changing the run.

## Reset and replay

- Play again reloads the dungeon scene from scratch. No enemy, encounter,
  gate, status effect or timer survives a restart.
- The run controller is created with the scene, not as an autoload, so it
  cannot leak between runs.
- Tests play several runs in a row and check that each starts clean and
  grants its reward once.

## Acceptance checks

1. Waves advance in order, and only when the current wave is fully dead.
2. A room's gates close on entry and open only when its encounter is cleared.
3. Spawning enemies cannot deal or take damage while rising.
4. The Dark Cultist's bolt is telegraphed, travels, can be dodged through its
   i-frames, and is stopped by walls.
5. The Fallen Knight's front damage reduction applies only from the front and
   only while it is not attacking.
6. The Ashen Lord enters each phase exactly once, in order, including when one
   hit crosses two thresholds.
7. Phase 2 summons exactly three adds, once; they die with the Lord.
8. Victory and defeat are mutually exclusive.
9. The reward is granted exactly once per run, and replay starts with zero.
10. Three consecutive runs in one session complete with no stale enemies,
    gates or timers.
11. Pause, focus loss and the death screen work in every room, as now.

## Build order

Each step is its own branch and PR, tested, and published to the web preview.

1. *(Done.)* **Encounters:** rename the Hollow to Skeleton Warrior; data-driven
   encounters and waves; rising spawns; the encounter in the current arena
   replaces the endless spawner; a placeholder victory screen and replay.
2. **The crypt:** the four rooms, corridors, gates and room triggers. *Done.*
   Until steps 3 to 5 land, the rooms hold Skeleton Warriors only: the Chapel
   fights two waves of four, and the Throne two waves (four, then six) in place
   of the Ashen Lord.
3. **Dark Cultist:** ranged attack, projectile, keep-away movement.
4. **Fallen Knight:** heavy attacks, shield bash, frontal guard, elite bar.
5. **Ashen Lord:** the boss, three phases, summons, Ember Ring, boss bar.
6. **Run summary and Ash:** result screen, stats, reward granted once,
   multi-run tests; Milestone 3 gate.

## Assumptions to confirm

- **Ash** is the name of the currency.
- The run is **linear**: no branching rooms or secrets in the first dungeon.
- The heal between rooms (30 health) stands in for potions, which are not
  designed yet.
