# Reaver — The Knife in the Dark

The second playable class (charter 13.2, implementation order 13.9 step 3: a
class with a different range and mobility profile than the Warden, to prove
the combat framework is shared).

**Status:** playable, first pass. Numbers are first-pass tuning.

## Identity

- **Role:** high-mobility melee damage; fragile if caught.
- **Look:** KayKit Rogue (hooded), dual knives, dark cloak tinted toward
  crimson, a crimson light; crimson slash arcs.
- **Rhythm:** quick slashes, a dash through the pack that marks it, then
  burst on the marked.

| | Warden | Reaver |
|---|---|---|
| Health | 100 | 85 |
| Move speed | 6.0 m/s | 6.8 m/s |
| Dodge cooldown | 0.9 s | 0.7 s (4.5 m) |
| Basic attack | 10 damage, 120°, 1.8 m, 0.12 s + 0.33 s | **Twin Slash:** 7 damage, 110°, 1.7 m, 0.08 s + 0.2 s |

## Abilities

| Key | Ability | What it does | Cooldown |
|---|---|---|---|
| Q / 1 | **Veil Rend** (signature) | Dashes 6 m along the facing in 0.18 s, unhurt and passing through enemies (not walls). When it ends, every enemy within 1.2 m of the path travelled takes 14 and is **Marked** for 4 s: +25% damage taken. Always activates, so it is also an escape. | 6 s |
| E / 2 | **Fan of Blades** | A 360° strike, 2.4 m, 12 damage. | 4 s |
| R / 3 | **Hemorrhage** | Bleeds the nearest enemy within 2.8 m: 5 every 0.5 s, 6 times. A bleed and a burn can run at once. No target: no cooldown spent. | 6 s |

- A mark never stacks: marking again refreshes it and keeps the larger
  bonus. When it ends the target's damage taken returns exactly to normal.
- Dodging during Veil Rend cancels it (no cut) and keeps the dodge's own
  invulnerable window.

## Skill tree (playable)

The tree from [SKILL_TREES.md](../SKILL_TREES.md#reaver). Its class stats:
`bleed_damage_pct` (Hemorrhage, Deep Cuts) raises the bleed;
`veil_rend_damage_pct` (Veil Rend Mastery) the cut; `mark_damage_pct` (Mark
for Death) adds to the mark; `dash_cooldown_pct` (Phantom Step) shortens
Veil Rend. The rest are the shared stats (damage, crits, speed, armour…).

## Playing it

The skill screen opens on the class being played. On the Reaver's tab,
**Play Reaver** switches class and starts a new run; the Warden's tab offers
**Play Warden** back. The level, gear, Ash and gold are shared; each class has
its own learned skills (and the same level's points to spend).

## Acceptance checks

1. Twin Slash, Fan of Blades and Hemorrhage deal their damage to what is in
   reach, and nothing else.
2. Veil Rend moves about 6 m through enemies, takes no damage while dashing,
   cuts and marks exactly the enemies on the path, and is solid and
   vulnerable again after.
3. A marked enemy takes +25%; the mark ends on time and leaves nothing behind.
4. A dodge during Veil Rend keeps the dodge's invulnerability.
5. Learned Reaver skills change the bleed, the cut, the mark and the cooldown.
6. Choosing the Reaver swaps the hero for the run: one hero, the camera, the
   HUD and the run's defeat follow it.
