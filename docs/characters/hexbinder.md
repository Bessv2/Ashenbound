# Hexbinder — The Keeper of Forbidden Names

The third playable class (charter 13.3; implementation order 13.9 step 4:
status effects, durations and area spells).

**Status:** playable, first pass. Numbers are first-pass tuning.

## Identity

- **Role:** ranged occult caster; curses and damage over time; needs setup
  time to reach full output, and is the most fragile hero so far.
- **Look:** KayKit Mage with its two-handed staff (spellbook and wand
  hidden), the texture dimmed toward violet, a violet light; violet bolts,
  curse rings and bursts.
- **Rhythm:** bolt from range, curse a pack, keep it off with Grasp, then
  Unmake for the payoff.

| | Warden | Reaver | Hexbinder |
|---|---|---|---|
| Health | 100 | 85 | 80 |
| Move speed | 6.0 | 6.8 | 6.2 m/s |
| Basic attack | melee 10 | melee 7, fast | **Hex Bolt:** 9 at range (13 m), aimed at the nearest enemy within 12 m |

## Abilities

| Key | Ability | What it does | Cooldown |
|---|---|---|---|
| Q / 1 | **Black Testament** (signature) | Curses the nearest enemy within 11 m and everything within 3.5 m of it: 6 at once, then **Cursed**: 3 every 0.5 s, 12 times. No enemy in reach: no cast, no cooldown. | 5 s |
| E / 2 | **Grasp of the Grave** | Everything within 4 m takes 6 and is slowed to 40% for 2.5 s. Always casts. | 8 s |
| R / 3 | **Unmake** | Every cursed enemy within 12 m bursts for 1.5× the curse damage it still had to take; the curse ends. No curse in reach: no cast, no cooldown. | 6 s |

- A curse is its own effect: it runs alongside a burn or a bleed, and casting
  again refreshes it rather than stacking.
- Slows never stack; the stronger one wins, and ending one restores the speed
  exactly (the Ashen Lord's own speed-up is kept).

## Skill tree (playable)

From [SKILL_TREES.md](../SKILL_TREES.md#hexbinder): `curse_duration_pct`
(Withering Word) adds ticks; `curse_damage_pct` (Spreading Blight, Frailty)
raises the tick damage; `black_testament_pct` (Mastery) widens the curse
and hardens its first hit; `detonation_damage_pct` (Volatile Hex, Cataclysm
Mastery) raises Unmake's multiplier; `soul_siphon_pct` (Hungering Souls,
Reaper's Tithe) heals for that share of Unmake's damage.

## Acceptance checks

1. Hex Bolt reaches a target behind the caster through aim assist and deals 9.
2. Black Testament curses exactly the group around the nearest enemy; the
   curse ticks on time and does not replace a burn; no target, no cooldown.
3. Unmake deals 1.5× the remaining curse damage once, ends the curse, ignores
   uncursed enemies; no curse, no cooldown.
4. Grasp damages and slows only what is within 4 m; the slow ends cleanly.
5. Learned Hexbinder skills change ticks, tick damage, area, burst and heal.
6. Choosing the Hexbinder swaps the hero for the run.
