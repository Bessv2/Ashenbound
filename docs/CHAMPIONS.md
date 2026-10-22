# Champions and health potions

Two Diablo-style systems that make each crypt run less predictable and give
the hero a way to recover mid-fight. Both are in the playable build. Their
numbers are first guesses for playtesting, not final balance.

## Champions

Any ordinary enemy (Skeleton Warrior, Dark Cultist) that an encounter spawns
may rise as a **champion**. Elites and bosses never do; they set
`EnemyController.champion_eligible = false`. Enemies the Ashen Lord summons
mid-fight are never champions either.

### How often

| Crypt tier | Chance per ordinary enemy | Affixes |
|---|---|---|
| 1 | 10% | 1 |
| 2 to 3 | 13%, 16% | 1 |
| 4 to 7 | 19% to 28% | 2 |
| 8 to 10 | 31%, then 35% (the cap) | 3 |

There are 13 ordinary enemies in a crypt run, so tier 1 averages about one
champion per run and tier 10 about four or five. The numbers are in
`Difficulty` (`champion_chance()`, `champion_affix_count()`).

### What a champion is

A champion keeps its kind's attacks and behaviour, but it:

- has **2.5×** health, on top of the tier's scaling;
- deals **1.2×** damage;
- is worth **4×** XP and gold and **3×** Ash;
- always drops a **Rare or better** item, on top of its normal drops;
- fills one **potion** charge when killed;
- is 15% bigger, with its name and a health bar over its head, a ring at its
  feet and a glow, all in its first affix's colour.

When one rises, a toast names it ("A champion rises: Hasted Vengeful Skeleton
Warrior"). Killing one shakes the camera, as killing an elite does.

### Affixes

| Affix | Colour | Effect | How to play against it |
|---|---|---|---|
| **Hasted** | ice blue | Moves 35% faster; its windups and recoveries take 75% of the time. | Its telegraphs are shorter: dodge earlier. |
| **Stoneskin** | stone grey | Takes 60% of each hit. | A long fight; damage over time still adds up. |
| **Vampiric** | blood red | Heals 10% of its health for each target its hit lands on. Melee enemies only. | Don't trade blows; dodge its swings. |
| **Ember-wreathed** | ember orange | Burns everything on the hero's layer within 2.6 m once a second (4 × its damage scale). An orange ring shows the reach. | Fight it from the ring's edge, or kill it fast. |
| **Vengeful** | violet | When it dies, the ground where it fell erupts 1.2 s later: 16 × its damage scale to everything within 3 m. A violet ring fills in as a warning. | Step out of the ring after the kill. |

With several affixes they stack. A Hasted Vampiric champion attacks faster
and heals each time.

### Rules the code keeps

- The aura's damage comes from `Champion`'s once-a-second ticks, and the
  eruption's from `VengefulBlast`, through `Health`. The rings and glow are
  presentation only (charter: VFX never apply damage).
- An eruption belongs to the level, not to the corpse, so it still goes off
  after the corpse is gone, and it is freed when the scene changes.
- A champion's scaling multiplies the tier's. `Difficulty.apply()` runs
  first, then `Champion.promote()`.
- An encounter without a `Difficulty` (a bare one in a test) raises no
  champions. `Main.champions_appear = false` turns them off, and the test
  helper `instantiate_main()` does, so tests that check exact run rewards
  stay deterministic.

Code: `scripts/enemies/champion.gd`, `scripts/enemies/vengeful_blast.gd`, and
`EncounterController._maybe_promote()`. Tests: `tests/test_champions.gd`.

## Health potions

- A run starts with **3 potions** (`PotionBelt.max_charges`).
- Drinking one (**F** or **4**, or the **POTION** button) heals **35%** of
  the hero's maximum health at once. The next can be drunk **1 s** later.
- A hero at full health does not waste one, and neither does a dead hero.
- **Refills:**
  - every **6** ordinary kills give one charge;
  - a champion, elite or boss kill gives one at once.

  Kills made while the belt is full count for nothing.
- The POTION button shows the charges in a badge. The button is dimmed while
  the belt is empty and flashes when a charge comes back.
- When the run ends (death or victory), the potion key stops working.

Potions are shared by every class. They are a run resource: they are not
saved, and gear or skills do not change them yet. A "more potions" affix or
skill would be a natural later addition.

Code: `scripts/player/potion_belt.gd` (the `Potions` node in `main.tscn`),
`Hud.track_potions()`, `TouchActionButton.badge`. Tests:
`tests/test_potions.gd`.

## Not tested

- On a phone: whether champion names and rings read well at phone size, and
  whether the POTION button is easy to reach with the thumb.
- Balance across classes and tiers in full runs.
