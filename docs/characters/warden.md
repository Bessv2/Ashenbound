# Warden: The Ashen Vanguard

The first playable class and the reference for the combat framework
(charter section 13.1). This page specifies the **starter kit**: the moves the
Warden has before any skill tree exists. Each class gets its own skill tree
later; the three starter abilities below will become entry points into the
Carnage, Bulwark and Doomfire specializations.

**Status:** Cleave, Bulwark Guard and Ember Brand are **validated** (20
automated tests against the acceptance checks below) and **verified in
runtime** (a rendered run under Xvfb with software Vulkan). **Not yet verified on a
device.** Implementation notes are in
[ARCHITECTURE.md](../ARCHITECTURE.md#warden-abilities).

## Identity

- **Role:** durable frontline melee fighter.
- **Silhouette:** a broad, grounded figure in blackened iron with ember-orange
  accents, carrying a greatsword. The current model is a placeholder capsule
  with an oversized blade.
- **Rhythm:** deliberate heavy strikes, a defensive counter, and fire that
  finishes what the sword starts.

## Kit at a glance

| Move | Input (keys / touch) | Cooldown | Purpose |
|---|---|---|---|
| Basic attack | J or Space, held / **ATTACK** | none | Steady damage in front |
| Dodge | Left Shift or K / **DODGE** | 0.9 s | Escape and evade, with an invulnerable window |
| Cleave | Q or 1 / **CLEAVE** | 4 s | Hit every enemy around the front, hard |
| Bulwark Guard | E or 2 / **GUARD** | 6 s | Brace against damage, punish the first hit |
| Ember Brand | R or 3 / **BRAND** | 7 s | Set the nearest enemy burning |

**Priority:** dodge, then abilities, then the basic attack.

- Starting a dodge cancels any ability or basic attack in progress. A hit
  still in its windup never lands.
- Starting an ability cancels a basic attack in progress.
- No ability starts while another one is still playing out.
- Ability presses are not buffered: a press made while another action is
  busy is ignored. (Only the dodge buffers its press, for 0.2 s.)
- Cooldowns run on the physics clock from the moment of activation. They
  pause with the game.
- An ability that cannot take effect (Ember Brand with no target in range)
  does not start and does not spend its cooldown.

## Basic attack (existing)

10 damage to each enemy within 1.8 m in a 120° arc in front of the Warden.
0.12 s windup, then 0.33 s recovery: one attack every 0.45 s. Movement is
slowed to 35% while attacking. Aim assist turns the attack toward the nearest
enemy within 4 m.

## Dodge (existing)

A 4 m dash over 0.3 s toward the movement input, or forward when there is
none. Damage is ignored for the first 0.25 s. Usable again 0.9 s after the
dash starts.

## Cleave (Carnage)

A heavy two-handed sweep.

| Property | Value |
|---|---|
| Windup | 0.3 s |
| Damage | 25 to each enemy in the arc, once |
| Reach and arc | 2.6 m, 220° centered on the facing |
| Recovery | 0.35 s after the hit |
| Movement while active | 20% speed |
| Aim assist | Turns toward the nearest enemy within 4 m |
| Cooldown | 4 s |

**Counterplay and readability:** the windup is long enough to see, and the
greatsword sweeps the full arc. A dodge during the windup cancels it.

**Acceptance checks:**

- Enemies inside the arc and reach take 25 once. Enemies behind the Warden or
  beyond 2.6 m take nothing.
- Pressing again during the cooldown does nothing.
- The Warden is slowed while it plays out.
- A dodge during the windup cancels the hit.

## Bulwark Guard (Bulwark)

Brace behind the greatsword for a moment, then punish whoever struck.

| Property | Value |
|---|---|
| Duration | 1.0 s |
| Damage taken while guarding | 20% of each hit, rounded to the nearest whole point (a Hollow's 12 becomes 2) |
| Counter | On the first hit taken during the guard: 15 damage to each enemy within 2.2 m, all around, resolved on the next physics tick. Once per guard. |
| Movement while active | None (rooted) |
| Cooldown | 6 s |

The guard lasts its full duration even after the counter; later hits in the
same guard are still reduced. A dodge cancels the guard.

Mitigation lives in `Health` (one source of truth for damage). The guard's
visual (a ring of embers around the Warden) applies no gameplay effect.

**Acceptance checks:**

- A hit during the guard deals 20% of its damage.
- The first hit triggers exactly one counter, which damages adjacent enemies.
- After the guard ends, hits deal full damage again.
- The Warden cannot move while guarding.
- A dodge ends the guard, and full damage applies afterward.

## Ember Brand (Doomfire)

Mark the nearest enemy with a burning brand.

| Property | Value |
|---|---|
| Target | The nearest living enemy within 7 m of the Warden. With none in range, nothing happens and no cooldown is spent. |
| Cast | Instant |
| Burning | 4 damage every 0.5 s for 4 s: 8 ticks, 32 damage in total. The first tick lands 0.5 s after the brand. |
| Reapplying | Restarts the 8 ticks. It does not stack: one brand per enemy. |
| Cooldown | 7 s |

Burning is a gameplay status on the target. The ember mark above the target's
head is visual only. Burning stops when the target dies, and is removed with
it. Burn damage respects invulnerability like any other damage.

**Acceptance checks:**

- With no enemy within 7 m, the ability does not start and no cooldown runs.
- Otherwise, the nearest enemy takes 4 damage per tick for 8 ticks, at 30, 60
  and 120 Hz alike.
- Reapplying restarts the count; there is never more than one brand per
  enemy.
- A dead target takes no more ticks.

## Not in the starter kit

The following are deferred to the Warden's skill tree:

- an ultimate ability;
- a class resource;
- bleeds and execution bonuses (Carnage);
- counters beyond the guard's (Bulwark);
- explosive finishers (Doomfire).
