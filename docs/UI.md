# Presentation: visuals and UI

Owner request (2026-10-22): "make the visuals 100x better and let's start to
put some life into the UI". What the game does on screen, beyond the models
(those are in [ART_ASSET_PIPELINE.md](ART_ASSET_PIPELINE.md)). Everything
here is visual only: no effect deals damage or changes a number.

## The world

- **Fire** (`FlameFx`): every wall torch, brazier and pillar ember has an
  animated flame (`resources/shaders/flame.gdshader`, a camera-facing quad),
  embers drifting up, and, where it has a light, a flicker on that light.
- **Dust**: motes of ash hang in every crypt room and catch the light.
- **Grade**: darker ambient and moonlight, so the warm pools of torch light
  carry the scene; stronger bloom (flames, spells and loot beams glow),
  more contrast and saturation (`resources/environment/`).
- **Frame** (`ScreenFx`): a vignette and faint grain over the world; when
  the hero's health falls under 40% the edges pulse red, faster as it drops.
- **Heroes** carry a dark outline (an inverted hull, `outline.gdshader`) so
  they read against the floor.
- **Hits**: the struck body squashes and springs back; damage numbers pop
  in, drift aside, and are bigger for bigger hits. Slash arcs, sparks, death
  bursts, spell rings and camera shake from the earlier visual pass remain.

## The HUD

Laid out like the concept sheet's in-game panel (2026-10-23):
- **Top left:** a round portrait (the class's weapon, ringed in its colour,
  with the level in a badge), then the class name, the red health bar and
  the blue XP bar ("Lv N").
  - The sheet's blue bar is mana; Ashenbound has no mana, so the blue bar
    is the XP toward the next level.
- **Top right:** the skills, bag and pause buttons as icons, and under them
  the round **minimap**.
  - The minimap shows the level's rooms around the hero, turned with the
    camera so up on the map is up on screen.
  - A room appears once the hero has been in it or near it.
  - Enemies are red marks (a boss bigger); the hero is an ember arrow
    pointing where they face.
  - It is hidden in levels without rooms (the test arena).
- **Bottom:** the stick on the left. On the right, round icon buttons:
  attack (the class's weapon), dodge, the three abilities and the potion.
- **Icons** come from game-icons.net (CC BY 3.0,
  [ART_ASSET_PIPELINE.md](ART_ASSET_PIPELINE.md#icons-2026-10-23)). They are
  white and tinted in the game; `Icons` finds them by key.
- **Damage numbers** on enemies are red, as on the sheet; the hero's own
  are pale.
- **Swings** (look B) are crescents near the end of the reach: thin and
  faint where the blade started, thick and bright where it finished.
- **Health** drops at once and a pale trail follows a moment later, so a
  hit's size reads at a glance; the bar flashes when hit; heals fill
  smoothly. **XP** fills smoothly.
- **Banners**: a room's name (and a line under it) when its fight starts;
  the Ashen Throne's in red; "Level N" when a level is gained.
- **Ability buttons** take their ability's colour, sink under a finger, and
  flash a ring when the ability is ready again.
- Messages slide in; the bag, skills, pause and away screens pop in.
- The **POTION** button, left of DODGE, shows the potions left in a badge, is
  dimmed while the belt is empty and flashes when a charge comes back
  ([CHAMPIONS.md](CHAMPIONS.md#health-potions)).
- A **champion** has its name (its affixes, then what it is) and a bar over
  its head and a ring at its feet, in its first affix's colour. A toast
  announces it when it rises.

## The title screen

The game opens on it (`scenes/title.tscn`): the name and tagline over
drifting embers, a card per class (the playable ones can be chosen; the
others show what is coming), level, Ash and gold, the crypt tier (`<` and
`>` within the open tiers), and **Enter the crypt** (focused: Enter starts
it). The pause menu's **Leave the crypt** returns to it; a run left early
pays nothing (its rewards are paid when it ends). The pause menu also has
**Music** and **Effects** volume sliders and the screen shake switch, all
saved ([AUDIO.md](AUDIO.md)).
- A **dungeon row** under the cards: the Ashen Crypt, and the Forgotten
  Catacombs once the crypt is cleared. The way in names the chosen dungeon.
- At the end of that row, **Classic**, **Look A** and **Look B**: the art
  style test ([ART_STYLE_TEST.md](ART_STYLE_TEST.md)), saved, applied from the
  next run.

## Performance notes

Each fire is one quad, a few CPU particles and, for those that have one, a
light whose energy changes. Dust is one CPU particle system per room. The
frame is one translucent full-screen pass without reading the screen. The
outline is one extra pass on the hero's parts only. None of this is measured
on a phone yet.
