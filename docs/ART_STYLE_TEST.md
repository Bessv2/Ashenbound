# Art style test: Look A against Look B

On 2026-10-23 the owner found the graphics "too basic" and "too cartoony", and
named two directions:

- **A:** cartoony characters, realistic attack animations and
  photorealistic effects;
- **B:** hyper-realistic characters and atmosphere, with Castle
  Crashers-style cartoony effects.

The owner chose to **see both before choosing**. This test puts both in the
game behind one switch, so they can be played side by side in any class and
either dungeon.

**Status:** on 2026-10-23 the owner chose **look B** ("really nice", and its
effects are preferred; look A was "just a cooler toned classic") but found it
far too slow on their phone. Look B is now the default and has been made much
cheaper (below). Classic and look A stay selectable until look B is
confirmed on the phone; then the charter's art direction (v2.0 §9) is
updated.

## How to compare

On the title screen, the row under the class cards has **Classic**,
**Look A** and **Look B**. The choice is saved, and it applies from the next
run: press **Enter the crypt** after choosing.

![The same blow in the three looks](images/style_test_hit.jpg)
![The same kill in the three looks](images/style_test_kill.jpg)
![Look A's hit effects (top) and Look B's (bottom)](images/style_test_effects.jpg)

## What each look changes

| | Look A ("bold heroes, real effects") | Look B ("grim world, cartoon effects") |
|---|---|---|
| **Characters** (heroes, enemies, summons) | Cel-shaded in three hard light bands, more saturated colour, a bright rim on the silhouette, a thick ink outline. | Worn, real materials: muted colour, fine relief and grime, grey steel turned metallic and glossy. |
| **World** | As built. | Real photographed stone (Poly Haven, CC0): flagstones on the floors and rock blocks on the walls, with their relief and roughness, and damp grimy hollows that catch the torchlight, in muted colour. Walls keep the see-through hole around the hero. (Until 2026-10-23 the tiled floors and walls were left out by mistake; only props and gates were dressed.) |
| **Grade** | Warmer and more saturated, a little more glow. | Desaturated, more contrast, less bloom. |
| **Hits** | White-hot spark streaks that fall and cool, a glare at the point of contact, a flash of light, smoke, bone chips (undead) or blood droplets (heroes). | A comic star that pops at the impact, and fat ink-outlined blobs (bone or blood) that bounce and squash. |
| **Kills** | A dust cloud and debris, and a blood pool spreading on the floor for the living. | A ring of round, outlined puffs and a big star. |
| **Swings** | A thin, white-hot motion-blur streak. | A thick, solid, ink-outlined smear. |
| **Being hit** | A jolt backward that recovers (a flinch). | A big rubbery squash. |

**Attack weight**, in both A and B:
- **Hit-stop:** the moment a blow lands, the game runs at 5% speed for about
  0.06 s (0.09 s for a critical hit, 0.14 s for killing a champion, elite or
  boss), so the blow is felt.
- **Lunge:** the body draws back through the windup, drives forward as the
  blow lands (0.32 m in A, 0.5 m in B), and settles. Only the model moves:
  reach, collision and the hero's position are unchanged.

Every one of these is presentation. Damage, timing, reach and rewards are
the same in all three looks. `test_art_style.gd` checks this: the same blow
deals the same 10 in each look.

## What this test cannot show yet

- **Complete animation sets.** Since 2026-10-23 looks A and B play
  motion-captured attacks, hits and deaths (Quaternius, CC0;
  [ANIMATION.md](ANIMATION.md)), on top of the hit-stop and lunges. The free
  library has no crossbow or two-handed greatsword clips, so those still
  use KayKit motion.
- **Truly realistic characters for Look B.** Look B gives the existing
  cartoon-proportioned models realistic materials. It cannot change their
  shapes or proportions. A real Look B needs realistic rigged character
  models, which are not available for free from this environment: the free
  asset sites it can reach are blocked, apart from GitHub. They would have
  to be bought, licensed or provided.
- **Photorealistic effects** are built from particles and shaders. Real
  flipbook textures (fire, smoke, blood) would raise them further, and need
  sourced assets.

The cost of the two directions differs:
- **Look A** can be finished here with what exists: stronger cel shading,
  more effects, better attack timing.
- **Look B's** look will only land fully once realistic character models
  arrive.

## Code

- `ArtStyle` (`scripts/presentation/art_style.gd`): the look, restyled
  materials, world dressing and the grade.
- Shaders:
  - `resources/shaders/toon_character.gdshader` (A);
  - `resources/shaders/grim_surface.gdshader` (B, with the optional
    cutout).
- Effects: `RealFx` (A) and `ToonFx` (B), called from `HitFeedback` and
  `AttackSwoosh`.
- Attack weight:
  - `HitStop`;
  - `CharacterAnimator._lunge()`;
  - `HitFeedback._punch(look)`.
- The setting: `GameSettings.art_style`. The title screen's look buttons call
  `TitleScreen.choose_look()`.

## Performance

Look B was slow for two reasons, both fixed on 2026-10-23:
- **Its surface shader** computed noise per pixel (about 120 hashes, for the
  grime and the relief) and read the photographed stone three times over
  (triplanar, nine texture reads).
  - Now the noise is one baked texture, `resources/textures/grime_noise.png`
    from `tools/art/make_grime_noise.py`: relief normal, fine and coarse
    noise in one RGBA image.
  - The stone is read once, along the axis the surface faces most.
  - A pixel now costs four or five texture reads.
  - The photographs also now have mipmaps and GPU texture compression;
    before, every distant pixel read the full 1k image.
- **Phones draw far more pixels than the game needs.** The web build renders
  at the screen's full density (about 2400 × 1080 on a typical phone).
  - On phones (the Android app, or a browser on Android or iOS), the 3D scene
    is now drawn at most 810 pixels tall and scaled up; the interface stays
    sharp (`SettingsService.scale_3d`).
  - The web export now also carries the phone texture formats (ETC2).

Measured:
- **Desktop, software Vulkan:** the crypt's opening view (a proxy for pixel
  cost, not phone numbers). Classic took 138 ms a frame. Look B took 222 ms
  (+61%) before the fixes and 155 ms (+16%) after.
- **Chromium emulating a phone** (800 × 360 at 3× density, software WebGL):
  frame rate rose about 40% in both looks with the 3D cap.
- **Not measured on a real phone.**

The owner still found it laggy on their phone, so a second cut followed the
same day:
- **No fog** in any look or level (`fog_enabled = false` in every
  `resources/environment/*.tres`; look B no longer thickens it).
- **No dynamic shadows on phones.** The only shadow-casting light was the
  moonlight (the torches never cast shadows); its shadow pass drew every
  character and wall a second time. `RendererLighting` turns it off when
  `SettingsService.is_phone()`. Desktop keeps it.
- The torches keep their light and flames.
- Measured in the same phone emulation: 1.2 to 1.3–1.4 frames a second. These
  are software-rendering numbers, useful only for comparison; the real test is
  the owner's phone.

## Look B's tone (2026-10-23)

The owner: "I like style B but it's too sharp and grainy. We can tone down
the visuals and keep the edgy darkness with funny animations. So it's kinda
ominous and serious but also goofy and meant to be over the top or pace
changing."

**Softer surfaces, same darkness:**
- **Relief:** world 1.8 to 0.45; characters 0.5 to 0.25.
- **Noise:** larger features in the world (scale 1.7 to 1.0).
- **Colour speckle** (`grain`): 45% in the world, 40% on characters.
- **Photographed stone:** 85% to 55%, with its normals at 45% depth
  (`detail_relief`).
- **Damp hollows:** their shine dropped from 0.9 to 0.6. That sparkle was
  the grain on a phone's dense screen.
- **Grade:** contrast ×1.12 to ×1.03, saturation ×0.72 to ×0.78, glow
  bloom ×0.5 to ×0.9. Still dark and muted; lights bloom instead of cutting.

**Over-the-top beats** (look B; visual only, no rule changes):
- **Knock-outs:** a killed enemy (not a boss, not a hero) is flung up and
  away from the hero, tumbling 1.5 turns, lands with a squash and pops away
  in a ring of puffs (`ToonFx.launch`). Its body stays where it fell. A
  comic star marks the blow; living flesh (ghouls, demons, imps) bleeds red
  blobs (`HitFeedback.bleeds`).
- **Cartoon wind-ups:** an attack stretches its model tall and thin as the
  blow gathers, squashes it flat as it lands, and wobbles back
  (`CharacterAnimator._stretch`).
- **Pace changes** (`HitStop.slow_motion`, looks A and B):
  - a boss's death drops the game to 20% speed and eases back over 1.4 s;
  - clearing a room is a 0.7 s beat at 35%.
  - A win keeps its beat; a fall cancels it.

## Checks

- `tests/test_art_style.gd`:
  - the setting is saved and clamped;
  - each look's materials, cached;
  - look B's walls keep the cutout;
  - a full crypt run in each look, with the same damage;
  - hit-stop only in A and B, always ending, including when the run is left;
  - the lunge moves the model, not the body;
  - the title's look buttons.
- Rendered under Xvfb (Mobile renderer): the same blow and kill in all three
  looks, and both effect sets close up (the images above).
- Web build (Compatibility renderer, Chromium): both looks played into the
  crypt with no shader errors in the browser console.

## Not tested

- On a phone: the frame rate of Look B's surface shader and Look A's
  heavier effects, and how either reads on a small screen.
