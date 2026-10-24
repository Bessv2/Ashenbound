# Generated dungeons

Owner request (2026-10-24): "The dungeons need to be randomly generated in
design, right now every single play through looks the exact same. It's the
same 3-4 rooms straight ahead with the same spawn rates."

**Status:** built and validated (`tests/test_dungeon_generator.gd`). Captured
under Xvfb for the crypt, the catacombs, the Volcanic Depths and the Cursed
Forest. Not yet played on a phone.

Every run now lays its dungeon out anew (`DungeonGenerator`,
`game/scripts/dungeon/dungeon_generator.gd`). Main does this before the level
enters the tree; the same seed always builds the same dungeon.

## What stays from the authored dungeon

Each dungeon's scene (`scenes/dungeon/<id>.tscn`) is still its frame:
- lighting, environment, colour cast, victory title and item level;
- **the start room**, where it is, with its dressing (the crypt's training
  dummies);
- **the boss hall**: its size, dressing (throne, banners, braziers) and boss
  fight, moved to wherever the way ends;
- **the story fights' names**: the quests ([QUESTS.md](../QUESTS.md)) name
  them, so they stay, in order.

Tests still play the authored layout (`Main.random_layout = false`), so
they know where every room is.

## What is new each run

- **The way winds.**
  - Each fighting room is joined to the last by a corridor (8 or 12 m), to
    the north, east or west. A step north is followed by a turn when there
    is room, and the way never doubles back.
  - The boss hall is always entered from the south, so its throne faces the
    hero.
  - A placement that would overlap anything already laid out is tried in
    another direction or corridor length. Failing all of those, it goes
    straight north, which is always free.
- **Room sizes:** 20 or 28 m on each side, so each fight room is one of four
  shapes. A side with a doorway must be 12, 20 or 28 m long so the wall
  pieces come out whole.
- **Extra fights:** none or one untitled fight at tiers 1 to 3, one or two
  from tier 4, mixed in among the story fights.
- **Sealed vaults:** one or two optional side rooms (12 or 20 m) off the
  fighting rooms, in any free direction (south too).
  - The vault's gate opens with its room.
  - The guardians are more likely to be Champions (+40 points).
  - Clearing it lays out a hoard of three Rare-or-better items.
  - Vaults are never needed to win; their kills count toward the run.
- **Props:** at random along the walls.
  - Tall ones by the far (north and west) walls, short ones by the near
    walls, never in a doorway.
  - Some rooms also get four pillars or a centrepiece.
  - Two brazier fires burn in the far corners of each fight room.
- **Spawns and waves:**
  - Enemies rise at random points on a 3 m grid, away from walls, props
    and the doorway the hero came in by.
  - Each room has 2 waves, or 2 to 3 from the third room on.
  - A wave has 3 to 5 enemies by room size, plus one from the fourth room
    on, plus the tier's extra enemies ([tiers.md](tiers.md)), at most 9.
  - The mix is the dungeon's basic enemies, a quarter ranged. From the third
    room on, the last wave opens with an elite, two from tier 5.

## Camera rules

The camera looks from the south-east.
- North and west walls are the far ones: tall, and see-through around the
  hero. West walls became see-through too, since a corridor can now run
  behind one.
- South and east walls are low colonnades.
- A room can now have a doorway on any side (`CryptRoom.west`, `east`).
  Gates in an east or west doorway are turned a quarter.

## Checks (`tests/test_dungeon_generator.gd`)

- The same seed builds the same layout; six seeds give at least five
  different layouts, for every dungeon.
- For every dungeon, at three seeds:
  - the story fights come in order and the boss fight last;
  - no wave is empty, and every spawn marker exists;
  - no two rooms overlap.
- Most layouts turn and most have a vault.
- Tier 10 waves are at least three enemies larger than tier 1's.
- A generated crypt's navigation mesh joins the start to the boss once the
  gates open, and not before.
- A run through a generated Volcanic Depths wins at the boss with its vault
  left alone.
- A cleared vault lays out three Rare-or-better items and does not end the
  run.

## Not yet

- Room shapes other than rectangles, and rooms of more than one floor.
- Traps, shrines or events in rooms.
- A seed shown to the player, for sharing a layout.
