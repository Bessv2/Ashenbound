# Reliquary — The Saint of Hollow Light

The fifth playable class (charter v2.0 §5.5). It is the roster's sustain
class: corrupted blessings that heal and judge, and a Martyrdom branch that
trades health for power. One ability per specialization.

**Status:** playable, first pass. Numbers are first-pass tuning.

## Identity

- **Role:** sustain and area damage; balanced, less burst than the Warden or
  Reaver.
- **Look:**
  - the KayKit Knight with a one-handed sword and the badge shield (the
    greatsword and other shields hidden);
  - pale silver armour with a faint spectral-blue glow, and a blue light;
  - blue-white rings and bursts.
- **Rhythm:** hold the line with the flail; set the lantern where you fight;
  pay blood for Judgment when a pack bunches up; Bless to recover.

| | Health | Move speed | Basic attack |
|---|---|---|---|
| Reliquary | 110 | 6.0 m/s | **Flail:** melee 9, 2 m reach, 120° |

## Abilities

| Key | Ability | Branch | What it does | Cooldown |
|---|---|---|---|---|
| Q / 1 | **Last Benediction** (signature) | Atonement | Spectral light from the hero: 12 to every enemy within 5 m, and the hero heals 15% of max health. One cast never heals more than **30%** of max health, however it is raised. Always casts. | 10 s |
| E / 2 | **Hallowed Lantern** | Radiance | A lantern at the hero's feet for 6 s. Once a second it burns every enemy within 4 m for 5, and heals the hero 2 while the hero stands in its light. One lantern at a time. | 12 s |
| R / 3 | **Martyr's Judgment** | Martyrdom | Pays 10% of max health to smite the nearest enemy within 9 m and everything within 3 m of it for 28. | 6 s |

**Judgment's safeguards** (charter: no accidental self-defeat):
- it is refused at 20% health or less, with no cost and no cooldown;
- its cost never takes the last point;
- with no enemy in reach it costs nothing and spends no cooldown.

The cost is paid directly, not as a hit, so armour, guards and dodges do
not change it. The health bar shows it like damage.

**Zeal** (Martyrdom passive, Blood Oath and Stigmata): below half health,
the hero's flail and all three abilities deal `martyr_damage_pct` more.
Judgment's own cost can tip the hero below half, and its smite then counts
the zeal.

## Skill tree (playable)

- **Atonement:**
  - Penitence (max health) and Hallowed Plate (armour) work as gear does.
  - Mercy (`healing_pct`) raises every heal.
  - Benediction Mastery (`benediction_heal_pct`) raises Benediction's heal,
    still capped.
  - Absolution (health on kill).
- **Radiance:**
  - Pale Flame (damage %), Sanctify (cooldown reduction) and Hollow Halo
    (crit chance) work as gear does.
  - Lantern Light and Judgment (`radiance_damage_pct`) raise all three
    abilities' damage.
- **Martyrdom:**
  - Blood Oath and Stigmata (`martyr_damage_pct`) power zeal.
  - Unyielding Faith and Final Vigil add health and armour.
  - Scourge (crit damage) works as gear does.

## Deviations

- The charter's look is a relic flail and a sacred lantern. The free models
  have neither, so the Reliquary swings a one-handed sword with its shield,
  and the lantern is a glowing primitive placed on the ground.

## Acceptance checks

These are automated in `tests/test_reliquary.gd`.

1. 110 health; the flail hits for 9.
2. Benediction:
   - deals 12 within 5 m and nothing beyond;
   - heals 15%;
   - never heals more than 30% at once.
3. The lantern:
   - pulses 5 a second within 4 m;
   - heals 2 a pulse only while the hero stands in its light;
   - goes after six pulses.
4. Judgment:
   - pays 10% and deals 28 to a group;
   - is refused at 20% health or less, without cost or cooldown;
   - never takes the last point;
   - with no target, it costs nothing.
5. Zeal adds `martyr_damage_pct` below half health, to the flail and to the
   abilities.
6. Learned skills change health, healing, light damage and cooldowns.
7. Choosing the Reliquary swaps the hero for the run.
