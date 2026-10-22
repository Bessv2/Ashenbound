# XP, levels and skill trees

Owner request (2026-10-22): "start a skill tree for the first 3 classes or
all 6 classes". The charter (section 13) gives every class three
specialization branches. This document defines the progression system and
the first three trees.

**Status:** the Warden's, the Reaver's and the Hexbinder's trees are playable
([characters/reaver.md](characters/reaver.md),
[characters/hexbinder.md](characters/hexbinder.md)). The other three classes' trees
(all six of the charter's roster) are complete data, shown in the skill
screen as previews: their nodes act on
their own abilities, which arrive with those classes (charter 13.9: a second
class only after the first one's dungeon works, which it now does).
Numbers are first-pass tuning.

## XP and levels

- Every kill gives XP right away: Skeleton Warrior 10, Dark Cultist 20,
  Fallen Knight 100, Ashen Lord 500. A full crypt run is about 790 XP.
- XP to reach the next level: `100 × level^1.5` (100, 283, 520, 800, …).
  Level cap 30 for now.
- Each level-up gives **one skill point**. The level, XP and points are saved
  with the profile and kept on death.
- Later, offline rewards (Milestone 6) grant XP through the same function.

## Trees

- Three branches per class, the charter's specializations. Each branch has
  five nodes in three tiers; a node may require another node in its branch.
- Each rank adds stats through `CharacterStats.bonus`, the same pipeline as
  items. Item stats work as they do on gear; skill-only stats change one
  ability (Cleave damage, Guard duration, Brand ticks).
- **Reset** refunds every point, for free, at any time out of combat (the
  build is meant to be experimented with).

### Warden (playable)

| Branch | Node | Ranks | Per rank | Requires |
|---|---|---|---|---|
| **Carnage** | Bloodied Edge | 5 | +3% damage | |
| | Heavy Swings | 3 | +15% Cleave damage | Bloodied Edge |
| | Butcher's Eye | 3 | +4% critical chance | Bloodied Edge |
| | Rending Blows | 3 | +15% critical damage | Butcher's Eye |
| | Executioner | 2 | +3 health on kill | Heavy Swings |
| **Bulwark** | Iron Skin | 5 | +6 armour | |
| | Stalwart | 5 | +10 max health | |
| | Shield Wall | 3 | +0.3 s Guard duration | Iron Skin |
| | Retribution | 3 | +30% Guard counter damage | Shield Wall |
| | Unbroken | 1 | +25 max health, +10 armour | Stalwart |
| **Doomfire** | Kindling | 5 | +2% damage | |
| | Searing Brand | 3 | +1 Brand damage per tick | Kindling |
| | Wildfire | 2 | +2 Brand ticks | Searing Brand |
| | Ember Haste | 3 | +4% cooldown reduction | Kindling |
| | Ashen Stride | 3 | +3% move speed | Ember Haste |

### Reaver (playable)

Branches from charter 13.2: **Bloodletting** (bleeds, sustained damage),
**Shadowstep** (mobility, flank attacks), **Executioner** (marks, finishers).
Nodes: Open Veins, Hemorrhage, Crimson Thirst, Deep Cuts, Exsanguinate;
Light Feet, Phantom Step, Flanker, Smoke Veil, Veil Rend Mastery; Mark for
Death, Coup de Grâce, Cold Focus, Relentless, Final Verdict. Stat nodes (damage,
crits, move speed, attack speed) and ability nodes (bleed, Veil Rend, the
mark, the dash cooldown) all act.

### Hexbinder (playable)

Branches from charter 13.3: **Curses**, **Soul Siphon**, **Cataclysm**. Nodes:
Withering Word, Spreading Blight, Hex Mastery, Frailty, Black Testament
Mastery; Soul Leech, Dark Pact, Hungering Souls, Spirit Ward, Reaper's Tithe;
Gathering Storm, Volatile Hex, Doom Chain, Ruin, Cataclysm Mastery.

### Dreadhunter (preview)

Branches from charter 13.4: **Precision** (charged shots, weak points),
**Trapper** (snares, Deadfall), **Beastcraft** (a companion, if scope and
performance permit). Nodes: Steady Aim, Drawn Shaft, Weak Point, Piercing
Volley, Deadeye; Snare Craft, Fleet Hunter, Bramble Spikes, Deadfall Mastery,
Killing Ground; Hunter's Bond, Thick Hide, Pack Instinct, Wild Heart, Savage
Bite.

### Reliquary (preview)

Branches from charter 13.5: **Atonement** (sustain), **Radiance** (spectral
area damage), **Martyrdom** (power below half health). Nodes: Penitence,
Mercy, Hallowed Plate, Benediction Mastery, Absolution; Pale Flame, Lantern
Light, Sanctify, Judgment, Hollow Halo; Blood Oath, Unyielding Faith, Scourge,
Stigmata, Final Vigil. Final Vigil carries the charter's safeguard: health
costs can never take the last point. Last Benediction's healing stays capped
(no infinite sustain).

### Gravecaller (preview)

Branches from charter 13.6: **Bone Legion**, **Wraiths**, **Soul Harvest**.
Nodes: Grave Discipline, Shieldbearers, Mass Grave, Phalanx, Forsaken Host;
Restless Dead, Chill Touch, Wailing, Phantom Swarm, Dread Aura; Reaping, Bone
Ward, Soul Well, Hungry Grave, Lich Veil. Summon count nodes add at most +2
skeletons and +2 wraiths in total, inside the summon budget the class spec
will set.

## Screens

- **SKILLS** on the HUD opens the tree (pauses the game, like the bag): class
  tabs, three branch columns, each node with its ranks; tapping one shows its
  description and **Learn**. Points left and **Reset** at the top.
- The HUD shows the level and an XP bar under the health bar; a level-up
  shows a message.

## Acceptance checks

1. XP adds up across kills and levels follow the curve; each level gives a
   point.
2. A node can only be learned with a free point, below its max rank, with its
   requirement met, for the playable class.
3. Each learned rank changes the matching combat number; reset restores it
   and refunds every point.
4. Level, XP and learned nodes survive a save and load; older saves load with
   level 1.
