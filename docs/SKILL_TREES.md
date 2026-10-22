# XP, levels and skill trees

Owner request (2026-10-22): "start a skill tree for the first 3 classes or
all 6 classes". The charter (section 13) gives every class three
specialization branches. This document defines the progression system and
the first three trees.

**Status:** the Warden's tree is playable. The Reaver's and Hexbinder's trees
are complete data, shown in the skill screen as previews: their nodes act on
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

### Reaver (preview)

Branches from charter 13.2: **Bloodletting** (bleeds, sustained damage),
**Shadowstep** (mobility, flank attacks), **Executioner** (marks, finishers).
Nodes: Open Veins, Hemorrhage, Crimson Thirst, Deep Cuts, Exsanguinate;
Light Feet, Phantom Step, Flanker, Smoke Veil, Veil Rend Mastery; Mark for
Death, Coup de Grâce, Cold Focus, Relentless, Final Verdict. Stat nodes (damage,
crits, move speed, attack speed) are real; ability nodes name the Reaver's
abilities.

### Hexbinder (preview)

Branches from charter 13.3: **Curses**, **Soul Siphon**, **Cataclysm**. Nodes:
Withering Word, Spreading Blight, Hex Mastery, Frailty, Black Testament
Mastery; Soul Leech, Dark Pact, Hungering Souls, Spirit Ward, Reaper's Tithe;
Gathering Storm, Volatile Hex, Doom Chain, Ruin, Cataclysm Mastery.

### Dreadhunter, Reliquary, Gravecaller

Branch names are set by the charter (13.4 to 13.6); their trees are written
when each class is scheduled.

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
