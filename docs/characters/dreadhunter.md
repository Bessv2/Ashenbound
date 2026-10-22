# Dreadhunter — The Last Stalker

The fourth playable class (charter 13.4). It adds a ranged physical class with
traps, a piercing shot and a small companion, one ability per specialization.

**Status:** playable, first pass. Numbers are first-pass tuning.

## Identity

- **Role:** ranged physical damage and battlefield control; weak when enemies
  close in.
- **Look:** the KayKit hooded Rogue with its two-handed crossbow (both knives,
  the one-handed crossbow and the throwable are hidden). Its texture is tinted
  toward forest green, with an amber light. Bolts, snares and the raven's
  eyes are amber.
- **Rhythm:** shoot from range; Deadfall the pack that rushes in; loose a
  Charged Shot down the line it forms; keep the raven up for steady damage.

| | Warden | Reaver | Hexbinder | Dreadhunter |
|---|---|---|---|---|
| Health | 100 | 85 | 80 | 90 |
| Move speed | 6.0 | 6.8 | 6.2 | 6.4 m/s |
| Basic attack | melee 10 | melee 7, fast | Hex Bolt 9, 13 m | **Crossbow:** 8 at range (15 m), a fast bolt aimed at the nearest enemy within 14 m |

## Abilities

| Key | Ability | Branch | What it does | Cooldown |
|---|---|---|---|---|
| Q / 1 | **Deadfall** (signature) | Trapper | Sets a rune-snare (3 m) under the nearest enemy within 12 m, or 4 m ahead with none. For 2 s it holds everything in it almost still (5% speed), including enemies that walk in. Then it erupts: each body in it takes 6 bolts × 4 = 24, once. Always casts. | 9 s |
| E / 2 | **Charged Shot** | Precision | Draws for 0.5 s, nearly rooted, then looses a bolt down a line 18 m long and about 1 m wide, aimed at the nearest enemy within reach. Every enemy in the line takes 24 (scaled by the weapon and damage %). A wall stops it, and a dodge during the draw cancels it. | 4 s |
| R / 3 | **Carrion Raven** | Beastcraft | A raven circles the hero for 8 s and every 0.8 s dives at the nearest enemy within 9 m for 6. Casting again renews it; there is only ever one. It leaves when the hero dies. | 12 s |

- Deadfall's hold uses `Slowed`, so it never stacks with Grasp of the Grave,
  and the enemy's speed is restored exactly when it ends.
- The snare, the tracer and the raven's flight are presentation. Damage is
  dealt once per eruption, per shot and per dive, through `Health`.
- Mobile budget: there is at most one snare at a time (a 2 s life on a 9 s
  cooldown) and one raven, with no navigation or collision for either.

## Skill tree (playable)

From [SKILL_TREES.md](../SKILL_TREES.md#dreadhunter-playable):

- **Precision:** Steady Aim (crit chance), Weak Point (crit damage) and
  Deadeye (damage %) work as gear does. Drawn Shaft and Piercing Volley
  (`charged_shot_damage_pct`) raise Charged Shot's damage.
- **Trapper:**
  - Snare Craft (`trap_duration_pct`) holds longer.
  - Bramble Spikes (`trap_damage_pct`) raises each bolt's damage.
  - Deadfall Mastery (`deadfall_bolts`) adds 2 bolts per rank.
  - Fleet Hunter (move speed) and Killing Ground (damage %) work as gear does.
- **Beastcraft:**
  - Hunter's Bond and Savage Bite (`companion_damage_pct`) raise the raven's
    dives.
  - Thick Hide (max health), Pack Instinct (attack speed) and Wild Heart
    (health on kill) work as gear does.

## Deviations

- The charter describes a longbow. KayKit has no bow, so the Dreadhunter
  carries the Rogue's heavy crossbow for now; its shots are "bolts".
- The charter allows "a limited companion or creature-assisted abilities".
  The companion is a raven built from primitives (no rig, no navigation),
  which keeps it cheap on phones. A proper creature model is open art work.
- Piercing Volley originally read "… and pierce". Charged Shot always
  pierces, so the node now only adds damage.

## Acceptance checks

1. The crossbow reaches a target behind the hero through aim assist and deals 8.
2. Deadfall sets under the nearest enemy; it holds what is in its 3 m and not
   what is outside; it erupts once for 24 each; then it is gone and the
   hold has worn off. With no enemy, it is set 4 m ahead.
3. Charged Shot deals nothing during the draw. It hits every enemy in its
   line for 24 and misses one 3 m aside. A wall stops it, and a dodge
   cancels it.
4. The raven dives every 0.8 s for 6 at the nearest enemy. There is only ever
   one. It leaves after 8 s, or when the hero dies.
5. Learned Dreadhunter skills change the snare's hold, bolts and bolt damage,
   the shot's damage and the raven's damage.
6. Choosing the Dreadhunter swaps the hero for the run.

Tests: `game/tests/test_dreadhunter.gd`.
