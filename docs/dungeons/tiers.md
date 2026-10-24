# Crypt tiers

Owner request (2026-10-22): "Up the gameplay loop." Clearing the Ashen Crypt
opens a harder **tier** of it, with better rewards, so the same dungeon keeps
paying off as the hero levels, learns skills and finds gear. This is the
first step toward repeatable endgame content and the cleared-content farming
of Milestone 6.

**Status:** built. Numbers are first-pass tuning, all in
`game/scripts/dungeon/difficulty.gd`. Made much steeper on 2026-10-24 (owner:
"scale the enemies to be much harder the deeper into the dungeons you go. The
tier should enhance enemy difficulty and also drop higher rarity items").

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

| What | Per tier | Tier 3 | Tier 5 | Tier 10 |
|---|---|---|---|---|
| Enemy health | ×1.35, compounding | ×1.8 | ×3.3 | ×14.9 |
| Enemy damage (melee, bolts, the Lord's ring) | ×1.13, compounding | ×1.28 | ×1.63 | ×3.0 |
| Enemy movement speed | +3% | +6% | +12% | +27% |
| Extra enemies in every wave (generated dungeons) | +1 per 2 tiers | +1 | +2 | +4 |
| Ash, XP and gold per kill | +50% | ×2 | ×3 | ×5.5 |
| Champion chance per ordinary enemy ([CHAMPIONS.md](../CHAMPIONS.md)) | +4 points from 10%, capped at 45% | 18% | 26% | 45% |
| Champion affixes | | 1 | 2 (from tier 4) | 3 (from tier 7) |
| Item level of drops | +4 | +8 | +16 | +36 |
| Drop chance | +10% | ×1.2 | ×1.4 | ×1.9 (capped at a certain drop) |
| Rarity boost (tiers above Uncommon) | ×1.35, compounding | ×1.8 | ×3.3 | ×14.9 |
| Lowest rarity that drops | | Uncommon | Uncommon | Epic |

The lowest rarity rises at tier 3 (Uncommon), tier 6 (Rare) and tier 9
(Epic). With the boost, a tier 10 drop is Epic about 88% of the time,
Legendary about 11% and Mythic about 1%.

**Deeper rooms are tougher too.** Each fighting room of a run after the first
adds 8% health and 4% damage (`EncounterController.depth`): after five
fights, the boss has +40% health on top of the tier.

Enemies are scaled once as they spawn (bosses' summons included), at full
health. Scaling lives in one place, `Difficulty.apply()`; attack resources
are never changed, only each attack node's `damage_scale` and the enemy's
`speed_multiplier` (which a boss's last phase and the Hasted affix multiply
further).

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
