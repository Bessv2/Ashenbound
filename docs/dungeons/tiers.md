# Crypt tiers

Owner request (2026-10-22): "Up the gameplay loop." Clearing the Ashen Crypt
opens a harder **tier** of it, with better rewards, so the same dungeon keeps
paying off as the hero levels, learns skills and finds gear. This is the
first step toward repeatable endgame content and the cleared-content farming
of Milestone 6.

**Status:** built. Numbers are first-pass tuning, all in
`game/scripts/dungeon/difficulty.gd`.

## Rules

- Tiers 1 to 10. Tier 1 is the crypt as built. A new profile has tier 1 open.
- Winning a run at tier *t* opens tier *t* + 1. A fall opens nothing.
- The tier of the next run is chosen on the end screen:
  - after a win: **Descend to tier *t* + 1** (main button) or **Replay tier *t***;
  - after a fall: **Rise again** at the same tier, or **Lower to tier *t* − 1**.
- The open tiers and the chosen tier are saved with the profile (save version
  3; older saves load with tier 1 open).
- A run at tier 2 or above opens with a "Tier N" message, and the summary
  names the tier.

## Scaling per tier above 1

| What | Per tier | Tier 3 | Tier 10 |
|---|---|---|---|
| Enemy health | +40% | ×1.8 | ×4.6 |
| Enemy damage (melee, bolts, the Lord's ring) | +15% | ×1.3 | ×2.35 |
| Ash, XP and gold per kill | +50% | ×2 | ×5.5 |
| Champion chance per ordinary enemy ([CHAMPIONS.md](../CHAMPIONS.md)) | +3 points from 10%, capped at 35% | 16% | 35% |
| Item level of drops | +4 | +8 | +36 |
| Drop chance | +10% | ×1.2 | ×1.9 (capped at a certain drop) |
| Rarity boost (tiers above Uncommon) | +25% | ×1.5 | ×3.25 |

Enemies are scaled once as they spawn (bosses' summons included), at full
health. Scaling lives in one place, `Difficulty.apply()`; attack resources
are never changed, only each attack node's `damage_scale`.

## Acceptance checks

1. A tier scales each enemy's health, every attack's damage, and its Ash and
   XP; tier 1 leaves enemies as built.
2. Clearing a tier opens the next one once; choices stay within the open
   tiers and within 1 to 10.
3. The open tiers and the choice survive a save and load; older saves start
   at tier 1.
4. A full run at tier 3 pays double Ash, opens tier 4 and offers it.

## Later

- A tier picker before a run (a crypt entrance or a map screen), once there
  is more than one dungeon.
- Tier-only affixes or legendary drops, once legendary effects exist.
- Offline farming (Milestone 6) of the highest tier cleared.
