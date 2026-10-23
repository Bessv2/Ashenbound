# Quests, achievements and daily challenges

Step 5 of [GAME_LOOP.md](GAME_LOOP.md): the concept sheet's Quest / Mission
window, plus the goals Idle Pocket Crafter 2 keeps players coming back for
(achievements, daily and weekly challenges).

The data is in `game/scripts/progression/quests.gd`, tracked and paid by
`Profile` (save version 6). The window is `QuestsPanel`, opened from the
title screen. A badge on its button counts the rewards waiting.

## Story quests

One per dungeon. Its objectives are the dungeon's fights, named after them,
the last being its boss.

| Dungeon | Quest | Reward |
|---|---|---|
| Ashen Crypt | The Ashen Crypt | 300 gold, ore, wood, a Rare item or better |
| Forgotten Catacombs | Below the Crypt | 600 gold, leather, herbs, crystal, Rare+ |
| Ruined Keep | The Iron Oath | 1,000 gold, ore, crystal, Epic+ |
| Cursed Forest | Rot at the Roots | 1,400 gold, herbs, wood, a soul shard, Epic+ |
| Volcanic Depths | The Burning Gate | 1,800 gold, ore, crystal, 2 shards, Epic+ |
| Ancient Temple | The Lost Sanctum (the sheet's own example) | 2,500 gold, crystal, herbs, 2 shards, Legendary |
| Ice Wastes | The Last Bond | 3,500 gold, crystal, leather, 4 shards, Legendary |

- **Progress:** a fight counts as done the first time it is cleared, in any
  run, at any tier. Progress is kept between runs, so a quest can span
  several attempts. A toast says when an objective is done and when the
  quest is complete.
- **Claiming:** the reward is claimed in the window once all objectives are
  done.
  - The item is rolled at the hero's level.
  - A full bag holds the claim back, and nothing is paid until there is
    room.
  - Each quest pays once.
- **Provisional canon:** the quest titles and lines are new proposals, like
  the region bosses' names ([dungeons/regions.md](dungeons/regions.md)).

## Achievements

Fifteen lifetime milestones, for example 50, 500 and 2,500 kills, Champions,
bosses, wins, deep runs, crafting, enchanting, ascending, camp upgrades and
collections, and salvage. Each pays gold, Ash or materials once, when
claimed.

Pocket Crafter's *awards* (permanent power) are **not** built: a permanent
bonus is a balance decision for the owner.

## Daily challenges

- **Today's three:** three a day from a pool of ten (slay 60 enemies, defeat
  2 Champions, defeat a boss, win a run, win at tier 2+, craft, enchant,
  collect from the camps, salvage, drink potions).
  - They are picked by the date, the same three all day.
  - Progress counts from the start of the day.
  - Each pays Ash, gold or materials once.
- **Never punishing** (charter §2.6): no streaks, nothing chains, and a
  missed day costs nothing. Yesterday's unfinished challenges simply go.
- **Provisional:** the day comes from the device clock, like offline rewards
  and the camps, until the Milestone 5 server.

## Counters

`Profile.stats` counts the following; each is added where it happens:
- **In a run (Main):** kills, Champions and bosses killed, runs won, wins at
  tier 2 or higher, potions drunk.
- **In Profile's own actions:** crafts, enchants, ascends, camp collections
  and upgrades, salvage.

## Tests

`game/tests/test_quests.gd` (9 tests) checks:
- every objective names a real fight of its dungeon;
- a quest pays exactly once, with a Rare-or-better item, and waits for room
  in a full bag;
- achievements pay once at their goal;
- dailies change by day, count from the day's start, are the same all day,
  and forgive a missed day;
- crafting and the camps count;
- clearing a run's fight ticks its objective off, with a toast;
- progress is saved;
- the window claims from the title screen and shows its badge.
