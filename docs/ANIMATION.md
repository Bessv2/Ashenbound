# Animation

The characters are KayKit models (CC0), each with its pack's 76 to 95
hand-keyed clips, played by `CharacterAnimator` from gameplay signals. On
2026-10-23 the owner asked for realistic attack animations:
- look A asks for *cartoony characters with realistic attack animations*;
- look B asks for realistic characters.

So **looks A and B now play motion-captured clips** for attacks, abilities,
hits and deaths. **Classic is unchanged.**

## The motion capture

- **Source:** Quaternius's *Universal Animation Library* 1 and 2, Standard
  editions (CC0, free; [README](../game/assets/third_party/quaternius/README.md)).
  Between them they have 86 clips on a realistic humanoid rig, including:
  - three-hit sword combos with recoveries, a heavy combo and a dash attack;
  - a shield bash, a block, an overhand throw and spellcasting;
  - hit reactions, a death, and zombie locomotion.
- **Retargeting:** `tools/anim/retarget_ual.gd` (a Godot script, run
  headless) writes 28 of them onto the KayKit rig (Rig_Medium, shared by
  every hero and enemy) as one AnimationLibrary, `mocap.res` (350 KB).
  - Both rigs rest in a T-pose and face +Z, so each KayKit bone takes its
    source bone's rotation away from rest, in world space; its local
    rotation follows from its parent's.
  - The source's clavicles, second spine bone, neck and fingers fold into
    the bones the KayKit rig has.
  - The hips' movement is scaled by the ratio of hip heights.
- **Download:** `tools/anim/fetch_ual.py` downloads the two libraries from
  itch.io. It follows itch's own "No thanks, just take me to the downloads"
  path for the free editions.

## Who plays what (looks A and B)

Set on each scene's Animator by `tools/anim/assign_mocap.py`. "A | B" means
the clips alternate blow by blow, so a string of attacks plays as a combo.

| Character | Attacks | Abilities | Other |
|---|---|---|---|
| Warden | basic: Sword Regular A \| B; Cleave: Sword Attack | Guard: Sword Block; Brand: spell cast | hits, Death01 |
| Reaver | Twin Slash: Sword A \| Melee Hook \| Sword B; Fan of Blades: Overhand Throw | Veil Rend: Sword Dash; Hemorrhage: Sword B | hits, Death01 |
| Hexbinder, Gravecaller | bolt: spell cast | spell enter or cast | hits, Death01 |
| Dreadhunter | crossbow: KayKit (the library has no crossbow) | Deadfall: Overhand Throw; Raven: spell enter | hits, Death01 |
| Reliquary | flail: Sword A \| B | Benediction, Lantern: spell enter; Judgment: Sword Attack | hits, Death01 |
| Skeleton Warrior, risen skeletons | Sword A \| B | | hits (skeletons) |
| Ghoul | Zombie Scratch | | shambles and idles like a zombie; knocked back when hit |
| Dark Cultist | spell cast | | hits |
| Fallen Knight | Cleave: Sword Attack; Bash: Shield One-Shot | | idles behind its shield |
| Ashen Lord | Cinder Cleave: Sword Attack; Ash Slam: Sword C; Ember Ring: KayKit | | |
| Hollow King | Volley: spell cast; the others KayKit | | |

The clips are sped up to fit each attack's windup and recovery, as before.
They are presentation only: reach, timing and damage are unchanged, and a
test checks that a blow lands on the same frame in Classic and look A.

## Checks

- `tests/test_mocap.gd`:
  - the library drives the KayKit bones, and an arm really swings;
  - every clip a scene names exists;
  - Classic keeps the KayKit clips;
  - in looks A and B blows alternate as a combo, and hits and death play
    their mocap clips;
  - ghouls shamble and scratch;
  - a blow lands on the same frame in Classic and look A, for the same 10
    damage.
- **Probe:** with the combo frozen, the combo test failed.
- **Rendered under Xvfb:**
  - the Warden posed through the sword combos, the heavy combo and the
    shield bash;
  - a look A fight strip, with the Warden and two skeletons swinging their
    mocap combos.

## Limits

- **Proportions:** the KayKit models are chibi, with a big head and short
  limbs, and the clips are for a realistic body. At gameplay distance the
  swings read well, but up close a hand can pass through the big head.
- **No crossbow or two-handed greatsword clips** in the free editions: the
  Warden swings its greatsword with one-handed sword motion, and the
  Dreadhunter's crossbow keeps its KayKit clips. The paid Pro edition of the
  first library has more.
- Dodges keep the KayKit clips: the mocap roll is too long to fit a dodge.
- Not seen on a phone.
