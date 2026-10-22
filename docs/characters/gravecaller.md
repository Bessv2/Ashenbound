# Gravecaller — The Shepherd of the Unburied

The sixth playable class (charter v2.0 §5.6). It is the roster's summoner:
risen skeletons that fight for it, wraiths that mark, and souls gathered
from the dying. One ability per specialization. It completes the six-class
roster.

**Status:** playable, first pass. Numbers are first-pass tuning.

## Identity

- **Role:** summons and persistent damage; relies on setup and summon
  uptime; fragile.
- **Look:**
  - the KayKit Mage with its open spellbook and wand (staff and closed book
    hidden), dimmed toward grave-green;
  - a teal light;
  - teal soul bolts, minions and rings.
- **Rhythm:** raise the skeletons first and let them hold the pack; mark the
  dangerous ones with wraiths; bolt from behind the line; harvest the souls
  of the fallen for a burst and a heal.

| | Health | Move speed | Basic attack |
|---|---|---|---|
| Gravecaller | 85 | 6.1 m/s | **Soul Bolt:** 7 at range (12 m), aimed at the nearest enemy within 11 m |

## Abilities

| Key | Ability | Branch | What it does | Cooldown |
|---|---|---|---|---|
| Q / 1 | **Raise the Forsaken** (signature) | Bone Legion | Raises 2 skeletons around the hero for 15 s. Each has 40 health and a claw (6, 1.6 m). Casting again dismisses the old ones first. Always casts. | 14 s |
| E / 2 | **Wraith Swarm** | Wraiths | 3 wraiths strike the nearest enemies within 10 m, one each, nearest first (wrapping round when there are fewer enemies). Each hit deals 9 and **marks** the target to take 20% more damage for 4 s. No enemy in reach: no cast. | 7 s |
| R / 3 | **Soul Harvest** | Soul Harvest | Each enemy that dies within 10 m of the hero leaves a **soul** (up to 10; the button's badge shows them). Casting spends them all: 6 per soul to every enemy within 6 m, and 3 per soul healed. No soul: no cast. | 3 s |

## The summons

The charter asks that summon count, lifetime, target selection, collision,
cleanup and performance be defined:

- **Count:** 2, plus Mass Grave's. A new cast replaces the old ones, so
  there are never more.
- **Lifetime:** 15 s (Forsaken Host lengthens it). A skeleton also
  crumbles when its health is spent, and when the hero dies.
- **Targets:** the living enemy nearest to the skeleton within 10 m. With
  none, it follows the hero and stops 2.5 m away.
- **Collision:** skeletons stand on the hero's layer. Enemies body-block on
  them, and enemy swings, bolts, rings, auras and eruptions can hit them.
  Enemies never choose them as a target; they chase the hero. The hero
  walks through them.
- **Cleanup:** skeletons are top-level children of the hero. They go with
  the hero on a scene change or a restart, and never outlive the run.
- **Cost on a phone:** no path planning (they steer straight), one shape
  query each per tick, two or three animated models.

## Skill tree (playable)

- **Bone Legion:**
  - Grave Discipline and Shieldbearers (`summon_health_pct`).
  - Mass Grave (`summon_count`): one more skeleton per rank.
  - Phalanx (`summon_damage_pct`).
  - Forsaken Host (`summon_duration_pct`).
- **Wraiths:**
  - Restless Dead (`summon_damage_pct`, which wraiths use too).
  - Chill Touch (attack speed), Wailing (cooldown reduction) and Dread Aura
    (damage %) work as gear does.
  - Phantom Swarm (`wraith_count`, renamed from a shared `summon_count`):
    one more wraith per rank.
- **Soul Harvest:**
  - Reaping (health on kill), Bone Ward (armour) and Lich Veil (max health)
    work as gear does.
  - Soul Well and Hungry Grave (`soul_harvest_pct`): each soul is worth more.

## Deviations

- The charter's look is a bone staff and a soul reliquary. The Gravecaller
  carries the Mage's open spellbook and wand instead, so it reads apart from
  the staff-carrying Hexbinder on the same model.
- Its skeletons are recoloured KayKit Skeleton Warriors with a teal glow,
  not a dedicated model.

## Acceptance checks

These are automated in `tests/test_gravecaller.gd`.

1. 85 health; the soul bolt finds a target behind the hero and deals 7.
2. Raise the Forsaken:
   - raises two 40-health skeletons on the hero's side, which walk to an
     enemy and strike it;
   - recasting replaces them;
   - they crumble after 15 s, when the hero dies, or one by one when
     destroyed.
3. Wraith Swarm:
   - hits the three nearest within 10 m for 9 and marks them (+20%
     damage);
   - one lone enemy takes every wraith;
   - with no enemy in reach, there is no cast.
4. Soul Harvest:
   - takes souls only from deaths within 10 m;
   - spends them for 6 damage and 3 healing per soul;
   - with no soul, there is no cast.
5. Learned skills change summon count, health and damage, wraith count and
   soul value.
6. Choosing the Gravecaller swaps the hero, and the HARVEST button shows the
   souls.
