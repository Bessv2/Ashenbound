# Sound and music

The game had no sound until 2026-10-23. It now has about 250 sound files
behind 65 cues, five music tracks and a dungeon bed. All of it is free and
CC0 (public domain), from Kenney and OpenGameArt. The sounds cover combat,
enemies, abilities, loot, gates, the interface, and music that follows the
run.

## What you hear

| When | Sound |
|---|---|
| A melee blow lands | A whoosh in the weapon's weight: a heavy greatsword (Warden; lower for Cleave), light blades (Reaver), a heavy flail (Reliquary). Bolts and spells crack as they leave. |
| Something is struck | What it is made of: bones rattle (skeletons, ghouls, cultists), steel rings (the Fallen Knight, the Ashen Lord), flesh thuds (heroes), stone knocks (training statues). There is always a thud under it, louder for bigger blows. A critical hit adds a crack. |
| An enemy winds up | The Dark Cultist whispers before its bolt. The Fallen Knight draws steel or braces its shield. The Ashen Lord's fire swells before Ash Slam and the Ember Ring. The Hollow King moans before its volley and the earth rumbles before its spikes. Skeletons and ghouls sometimes growl. **These are telegraphs:** the sound starts with the windup, so a fight can be read by ear as well as by eye. |
| Death | Skeletons cry out and collapse into bones; the Knight's armour falls; ghouls shriek; the bosses roar or moan as the floor breaks. Heroes cry out. |
| Abilities | Each has its own: Bulwark Guard rattles chainmail and its counter rings, Ember Brand and the Ashen Lord's attacks roar with fire, Veil Rend and Black Testament hiss with dark magic, Hemorrhage is wet, Grasp of the Grave rumbles, Unmake and Soul Harvest drain. Deadfall cranks and snaps shut. The raven flaps and caws. Benediction chimes, the Hallowed Lantern tolls a soft bell on each pulse, Judgment breaks stone, the Gravecaller's dead claw out of the ground and the wraiths moan. A Vengeful champion's blast fizzes as a fuse, then explodes. |
| Moving | Heroes' footsteps on stone; a cloth rustle on dodge; earth breaking as the dead rise. |
| Loot | A drop clatters; Rare and better chime, brighter by rarity; Legendary and Mythic also ring a bell. Picking up, equipping, salvaging (metal and coins) and upgrading (an anvil) each have a sound. |
| The world | Gates grind on their chains and slam. A low bell tolls when a room is won. A champion's rise is a roar. Levelling up rings a bell. |
| The interface | Every button clicks; panels open and close; learning a skill confirms, and anything refused buzzes. Potions bubble, and a refilled charge uncorks. |
| Music | The title has its own theme. Each dungeon has its own exploring track (the crypt: *Dark Shrine Loop*; the catacombs: *Dark Cavern Ambient*) over a dungeon bed. A room's fight brings in *Determined Pursuit*, the boss brings *Epic Boss Battle* with a roar at each phase, a cleared room tolls and fades back, a win tolls and returns to the dungeon's track, and a fall tolls low and goes silent. The music dips while paused. |

**Volumes:** the pause menu has **Music** and **Effects** sliders, saved with
the settings (`GameSettings.music_volume`, default 70%, and `effects_volume`,
default 100%). Zero turns that part off.

## How it works

- **Cues** are named sounds, such as `hit_bone` or `music_boss`.
  - `SoundFiles` (generated) lists each cue's files.
  - `SoundBank` sets how each cue plays: its loudness, the random pitch
    variation that keeps repeats from sounding identical, its bus, and its
    gap. The gap is how soon the cue may repeat, so a Cleave that hits six
    skeletons plays one rattle, not six stacked.
  - A cue never plays the same file twice running.
- **`Audio`** (autoload, `scripts/audio/audio_service.gd`) plays the cues and
  the music.
  - It makes the buses:
    - Master, with a limiter, holds Sfx and Music;
    - Sfx (the Effects volume) holds World, Ui and Ambience;
    - World carries a light reverb, so the crypt sounds like a crypt.
  - World sounds come from a fixed pool of 16 positional voices; when all are
    busy the oldest is cut, which keeps the cost bounded on a phone.
  - The listener sits on the camera rig at the hero, so sounds pan with the
    screen. They are not heard from the camera, which is 30 m away.
  - World sounds pause with the game. The interface and the music do not;
    the music dips instead.
  - The music crossfades between tracks.
  - Gaps are kept on the frame clock with hit-stop removed, so they are
    deterministic in tests.
- **`CharacterSounds`** is a node in each hero, enemy and summon scene. It
  finds its siblings (Health, attacks, abilities, Dodge, the enemy
  controller) and plays their sounds from their signals:
  - attacks name their sounds in their `AttackData` (`windup_sound`,
    `swing_sound`, `sound_pitch`);
  - abilities name theirs as `Ability.sound`;
  - projectiles name a landing sound as `Projectile.impact_sound`.
- **`SoundDirector`** (in `main.tscn`) handles the music and the world's
  events: encounters, the boss and its phases, gates, loot, potions,
  champions, levels and the end of the run. `Dungeons.INFO` names each
  dungeon's track.
- The traps, the raven, the lantern, risen skeletons and Vengeful blasts
  call `Audio.play` themselves, in one line each.
- **Sound never changes gameplay.** Every call is fire-and-forget; nothing
  waits on a sound or reads one back.

## The files and where they come from

`tools/audio/import_audio.py` downloads each pack from where it is
published and builds the game's files from it. It:
- splits long multi-take recordings into separate takes;
- trims leading silence;
- makes sound effects mono, peaking at -1 dBFS;
- normalises music to -18 LUFS, so the music levels in `SoundBank.TRACKS`
  are deliberate;
- encodes Ogg Vorbis;
- writes `scripts/audio/sound_files.gd`.

`tools/audio/assign_sounds.py` writes the sound choices into the scenes and
resources. Running it again changes nothing, so it doubles as the record of
which object makes which sound. The files are in
`game/assets/third_party/audio/<author>/`, 9.7 MB in all.

| Pack | Author | Source |
|---|---|---|
| Impact Sounds, RPG Audio, Interface Sounds | Kenney | kenney.nl/assets/impact-sounds, /rpg-audio, /interface-sounds |
| 80 CC0 RPG SFX; 75 CC0 breaking / falling / hit sfx | rubberduck | opengameart.org/content/80-cc0-rpg-sfx, /75-cc0-breaking-falling-hit-sfx |
| RPG Sound Pack; Swishes Sound Pack | artisticdude | opengameart.org/content/rpg-sound-pack, /swishes-sound-pack |
| Medieval Sound Effects: Weapon Textures | medicinestorm | opengameart.org/content/medieval-sound-effects-weapon-textures |
| Tinysized SFX Library | vehicle | opengameart.org/content/fantasy-sound-effects-tinysized-sfx |
| Bones Rattle | congusbongus | opengameart.org/content/bones-rattle |
| Zombie, Skeleton, Monster Voice Effects | arcadeparty | opengameart.org/content/zombie-skeleton-monster-voice-effects |
| Ghost Monster Voice; 3 Dark Magic Spells; Energy Drain; Earth Element Magic Spell; Ghost Breath | qubodup | opengameart.org/content/ghost-monster-voice-moaning-growling, /3-dark-magic-spells, /energy-drain, /earth-element-magic-spell, /ghost-breath |
| Cure Magic | someoneman | opengameart.org/content/cure-magic |
| Ice Spells | bart | opengameart.org/content/ice-spells |
| Catching Fire | themightyglider | opengameart.org/content/catching-fire |
| Crow Caw; Crow | zeroisnotnull; fvcalderan | opengameart.org/content/crow-caw, /crow |
| Large Wings Flap | antumdeluge | opengameart.org/content/large-wings-flap |
| Dungeon Ambience; Dark Shrine Loop (posted by qubodup) | yd | opengameart.org/content/dungeon-ambience, /dark-shrine-loop |
| Dark Intro (the title) | nikke | opengameart.org/content/dark-intro |
| Dark Cavern Ambient (the catacombs) | paul-wortmann | opengameart.org/content/dark-cavern-ambient |
| Determined Pursuit (combat) | emmama | opengameart.org/content/determined-pursuit-epic-orchestra-loop |
| Epic Boss Battle (the boss), by Juhani Junkala | subspaceaudio | opengameart.org/content/boss-battle-music |

Each page's licence was checked as CC0 on 2026-10-23 before download.
`game/assets/third_party/audio/packs.json` holds the same list as data.

## Checks

- `tests/test_audio.gd`, 11 tests:
  - every cue's files load, and every mixed cue, track and dungeon has
    files;
  - every sound named by the 14 character scenes, their attacks and
    abilities, and the 4 projectiles exists;
  - the volumes are saved, clamped and reach the buses, and zero mutes;
  - the gap stops a repeat, and unknown cues are silent;
  - a Warden blow sounds its swing, the rattle and the thud, and the kill
    its cry and collapse, with the same 10 damage as before;
  - the cultist's chant starts with its telegraph, before its bolt;
  - footsteps sound as the hero walks;
  - the music follows a crypt run: the crypt track, combat, the toll and
    back, the boss with a roar, the dip while paused, and silence on a fall;
  - the catacombs and the title have their own music;
  - buttons click unless marked silent, and the pause menu's sliders set,
    apply and save the volumes;
  - world voices pause with the game.
- **Probes:** a misspelt cue in the skeleton scene, and the combat music
  removed, each made the matching tests fail.
- **The mix, measured:** the game's own output was recorded during a
  scripted 47-second Warden fight in the crypt (`AudioEffectRecord` on the
  master bus): the walk in, a room's encounter, then the Ashen Lord.
  - It measured **-15.6 LUFS** integrated, with a loudness range of 8.8 LU.
  - Sample peaks stayed at -0.3 dBFS: the limiter holds.
  - Each cue alone peaks between -0.3 and -13 dBFS through the mix.
- **The web build** plays with sound and no errors in the browser console.

## Not tested

- **Nobody has listened yet.** The levels above are measured, not judged by
  ear. Whether each sound suits its moment needs the owner's ears; any cue
  can be swapped in `tools/audio/import_audio.py`.
- **On a phone:** the cost of 16 voices and the reverb, and how the mix
  sounds on a phone speaker.
- **In the web build, browsers play sound only after the first tap or key
  press**, so the title music starts then. Godot's web build also plays
  sounds as samples, without the World bus's reverb.

## Known limits

- The music is CC0 library music, not scored for the game. The boss track
  is the same for both bosses.
- There are no voice lines, and heroes share one set of male grunts.
- A few events still have no sound of their own: an enemy's ordinary
  recovery, and the status marks (Marked, Slowed).
