# The regions after the catacombs

Step 4 of [GAME_LOOP.md](../GAME_LOOP.md): the concept sheet's environments
(Ruined Keep, Cursed Forest, Volcanic Depths, Ancient Temple, Ice Wastes) and
its Demons.

All five are written by `tools/levels/make_regions.py` from recipes. In play,
each run lays out its own winding way between their start room and boss hall
([generation.md](generation.md)). The authored layout below is the frame and
the layout the tests use:
- a stairwell, then three fighting rooms and a boss hall;
- corridors between the rooms, with gates that seal during a fight and open
  after it.

Each region has its own:
- **colour cast** over the same KayKit stone (`Level.world_tint`, applied by
  `ArtStyle.tint_world` in every look);
- torch colour, light, ambient and background;
- props (KayKit Halloween Bits and Medieval Hexagon, CC0): tall ones against
  the far walls, short ones by the near walls, so none hides the hero;
- enemy mix and boss;
- materials ([CRAFTING.md](../CRAFTING.md)).

## Order and levels

Each dungeon opens once the one before it has been cleared at any tier
(`Profile.cleared_dungeons`, save version 5). Older saves with a cleared tier
count the crypt as cleared. Tiers stay shared across dungeons.

| Dungeon | Hero levels | Item level | Enemies | Boss | Materials |
|---|---|---|---|---|---|
| The Ashen Crypt | 1-10 | 1 | Skeletons, cultists, a Fallen Knight | The Ashen Lord | Ore, wood |
| The Forgotten Catacombs | 5-15 | 6 | Ghouls, cultists, knights | The Hollow King | Leather, herbs |
| The Ruined Keep | 10-15 | 10 | Skeletons, Fallen Knights, cultists | **The Iron Castellan** (Ashen Lord kin; raises knights) | Ore, wood, leather |
| The Cursed Forest | 12-18 | 14 | Ghouls, skeletons, cultists, knights | **The Rotwood Witch** (Hollow King kin; raises ghouls) | Herbs, wood, leather |
| The Volcanic Depths | 15-22 | 18 | **Demons**, **Imps** | **The Cinder Tyrant** (a horned Ashen Lord; raises imps) | Ore, crystal |
| The Ancient Temple | 20-26 | 22 | Skeletons, imps, cultists, knights | **The Sunless Oracle** (Hollow King kin; raises skeletons) | Crystal, herbs, ore |
| The Ice Wastes | 25-30 | 26 | Ghouls, skeletons, demons, cultists, knights | **The Rime King** (Hollow King kin; raises ghouls) | Crystal, leather |

**Provisional canon.** The five boss names, the room titles and their lines
are new. They follow the charter's tone but are proposals for the owner to
keep or rename (charter §2.8); nothing else depends on the names.

## The Demons

- **Demon:** a horned brute.
  - Built from the KayKit Knight at 1.2×, in a dark crimson material with a
    faint ember glow, with horn cones and ember eyes on its head bone.
  - 70 health. A claw swipe (14 damage, 0.55 s windup).
  - Every third attack is a **ground slam**: a full circle around it,
    22 damage, a 1.1 s telegraphed windup, knockback. It punishes standing
    next to it.
  - It can rise as a Champion.
- **Imp:** a small horned caster.
  - The hooded Rogue at 0.75×, red.
  - 30 health. It keeps its distance and throws **fire bolts** (12 damage,
    0.6 s windup), like a faster, frailer Dark Cultist.
- **Cinder Tyrant:** the Ashen Lord's fight with horns, a molten material,
  and imps for adds.

The other four bosses are inherited scenes of the Ashen Lord or the Hollow
King: their fights, with their own name, colour, health (900 to 1,450),
rewards and adds. New boss mechanics per region are future work.

## Not yet

- **Outdoor ground:** the Cursed Forest and the Ice Wastes are rooms of
  KayKit stone, cast green or frost-blue, with trees and rocks for props.
  Real outdoor ground (grass, snow) needs other art.
- **Own boss mechanics:** each boss fights like the boss it is built on.
- **Own music:** the regions reuse the crypt's and the catacombs' tracks.
