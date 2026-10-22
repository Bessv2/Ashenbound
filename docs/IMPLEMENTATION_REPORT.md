# Implementation report: Task 1, Android project foundation

**Date:** 2026-10-21 · **Branch:** `ccr-f0dcdd15-eok91q`

## Outcome

> **Update:** after the user's go-ahead to keep developing, CI, a
> safe-area-aware HUD and a first combat slice were added. See
> [section 4](#4-follow-up-work-after-the-go-ahead-to-keep-developing).

- The Godot 4.7.2 project under `game/` imports cleanly and runs without errors.
- The movement prototype passes all 38 automated tests.
- A signed debug APK was exported and verified.
- **Not done:** installing and playing the APK on a phone. No device or emulator
  was available (details below), so the manual device checklist in
  [BUILD_ANDROID.md](BUILD_ANDROID.md#manual-device-checklist) is still open.

## 1. Environment inspection

The repository initially held only a two-line `README.md` ("Android Idle Game")
and was on the development branch with a clean tree. The README was expanded;
nothing else existed to preserve.

| Tool | Found at start | Resolution in this environment |
|---|---|---|
| Godot | No | 4.7.2-stable editor from the Nix binary cache (nixpkgs 26.05 `godot_4_7`). godotengine.org, tuxfamily and GitHub release downloads are blocked by the network policy. |
| Export templates | No | Official 4.7.2 `.tpz` via Nix (`godot_4_7-export-templates-bin`, hash-pinned), linked into `~/.local/share/godot/export_templates/4.7.2.stable` |
| JDK | OpenJDK 21 only | Installed `openjdk-17-jdk-headless` (17.0.20) with apt; JDK 21 was left in place |
| Android SDK | No (`dl.google.com` blocked) | Ubuntu `adb` (34.0.4), `apksigner` (31.0.2) and `zipalign`, which form `/usr/lib/android-sdk` |
| .NET SDK | No | Not needed (GDScript only). Needed later for the ASP.NET Core backend. |
| Docker | CLI 29.9.1, **no daemon** | Not needed yet |
| PostgreSQL | psql 16.15, cluster down | Not needed yet |
| Android device / emulator | None; no `/dev/kvm` | Not resolvable here |

**Selected configuration:** Godot 4.7.2-stable + export templates 4.7.2.stable +
OpenJDK 17 + Android SDK (platform-tools, build-tools 36.1.0; target SDK 36,
min SDK 24) + non-Gradle APK export. These are the versions Godot 4.7.2 builds
against. The container used Ubuntu's apksigner 31.0.2 in place of build-tools
36.1.0, which works for signing debug APKs. Setup steps for a development
machine are in [BUILD_ANDROID.md](BUILD_ANDROID.md).

## 2. Changed files

New: `.gitignore`, `tools/test.sh`, `tools/export-android-debug.sh`,
`docs/{BUILD_ANDROID,ARCHITECTURE,IMPLEMENTATION_REPORT}.md`, `docs/images/*.png`,
and the whole `game/` project:

- **Config:** `project.godot`, `export_presets.cfg`, `icon.svg`
- **Scenes:** `scenes/main.tscn`, `scenes/arena/test_arena.tscn`,
  `scenes/player/warden.tscn`, `scenes/camera/isometric_camera_rig.tscn`
- **Scripts:** `scripts/main.gd`, `scripts/input/movement_input.gd`,
  `scripts/player/{player_controller,movement_stats}.gd`,
  `scripts/camera/isometric_camera_rig.gd`,
  `scripts/core/{pause_controller,game_settings,settings_service}.gd`
- **UI:** `ui/hud/{hud.tscn,hud.gd,touch_joystick.gd}`,
  `ui/pause_menu/{pause_menu.tscn,pause_menu.gd}`, `ui/theme/ashen_theme.tres`
- **Resources:** `resources/materials/*` (including the flagstone shader),
  `resources/environment/arena_environment.tres`,
  `resources/player/player_movement.tres`
- **Tests:** `tests/run_tests.gd`, `tests/framework/{test_case,error_counter}.gd`,
  `tests/test_{movement_input,touch_joystick,player_movement,pause,settings}.gd`

Modified: `README.md`.

The `*.uid` and `*.import` files are Godot-generated and committed, as Godot
recommends.

## 3. Executed checks

All commands were run from the repository root with
`JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 ANDROID_HOME=/usr/lib/android-sdk`.

| # | Command | Exit | Result |
|---|---|---|---|
| 1 | `godot --version` | 0 | `4.7.2.stable.nixpkgs.ed1daf0bf` |
| 2 | `rm -rf game/.godot && godot --headless --path game --import` | 0 | Clean import, no errors or warnings. Editor settings picked up the JDK and SDK, and a debug keystore was generated. |
| 3 | `godot --headless --path game --fixed-fps 60 --quit-after 600` | 0 | Main scene ran 600 frames; 0 errors, 0 warnings |
| 4 | `godot --headless --path game --fixed-fps 60 --script res://tests/run_tests.gd` (via `tools/test.sh`) | 0 | **38 passed, 0 failed** on each of 4 runs, the last from a clean `.godot/`. *Correction found later:* some of these runs also logged one engine warning from Jolt Physics, which the runner did not report at the time (see section 4). |
| 5 | Same runner with a temporary self-check suite (`push_error`, null call, failed check) | 1 | All 3 deliberate failures detected; suite then removed |
| 6 | `godot --headless --path game --check-only --script res://<file>` for each `.gd` | — | 14 of 19 clean. The other 5 use the `Settings` autoload, directly or through `hud.gd`, and report only "Identifier not found: Settings", because check-only mode does not register autoloads. Checks 2–4 compile and run the same scripts without errors. |
| 7 | `tools/export-android-debug.sh` (`godot --headless --path game --export-debug "Android" ../build/android/ashenbound-debug.apk`) | 0 | Godot: "Signed". 28,382,846-byte APK |
| 8 | `apksigner verify --verbose --print-certs build/android/ashenbound-debug.apk` | 0 | Verifies; APK Signature Scheme v2 and v3 |
| 9 | `zipalign -c -p -v 4 build/android/ashenbound-debug.apk` | 0 | Verification successful |
| 10 | `aapt dump badging` / `aapt dump xmltree … AndroidManifest.xml` | 0 | `com.ashenbound.game` 0.1.0 (code 1), minSdk 24, targetSdk 36, `screenOrientation=userLandscape`, `lib/arm64-v8a` only, scripts compiled to `.gdc`, 0 test files packaged |
| 11 | Export with an unknown preset; export with an invalid SDK path | 1, 1 | Godot reports the misconfiguration and exits non-zero (the export script relies on this) |
| 12 | `adb start-server`; `adb devices -l` | 0, 0 | Empty device list. No `/dev/kvm`, so no emulator is possible. |
| 13 | Rendered smoke test: `xvfb-run godot --path game --resolution 1600x720 --script <capture script>` with Mesa lavapipe | 0 | `renderer=mobile driver=vulkan`. Keyboard and touch-joystick movement, camera follow and the pause overlay were confirmed visually; see `docs/images/` |

### What the tests cover

- **Input:** diagonal keys normalized; analog strength preserved; opposite keys
  cancel; camera-relative mapping (forward = away from the camera, independent
  of pitch).
- **Joystick (through GUI touch routing):** drag maps to actions; output is
  clamped at the rim; release stops cleanly; a second finger is ignored; touches
  outside the zone are ignored; it does not cancel a held key; pause and focus
  loss reset it, and a new touch works after resume.
- **Player (real `main.tscn`, Jolt physics):** settles on the floor; can't
  leave the arena in any direction; distance per second agrees across 30, 60
  and 120 Hz physics within 2%; no drift after release.
- **Camera:** orthographic, yaw 45°, pitch −35.264°; never rotates during
  movement; follows the player.
- **Pause:** Esc and P toggle; HUD and Resume buttons work; focus loss,
  backgrounding and Android Back pause; held movement is released across pause.
- **Settings:** round-trip through disk; values are clamped and type-checked;
  apply reaches the engine and the joystick.

## 4. Follow-up work (after the go-ahead to keep developing)

After Task 1, the user asked for development to continue autonomously. The
following was added on the same branch, in separate commits:

| Commit | Change |
|---|---|
| CI | `.github/workflows/ci.yml`: official Godot 4.7.2 Linux editor plus Android templates (cached), Temurin JDK 17, build-tools 36.1.0; runs `tools/test.sh`, exports the debug APK and uploads it as an artifact |
| Safe area | On mobile, the HUD is inset by `DisplayServer.get_display_safe_area()` so controls clear camera cutouts |
| Combat slice | `Health`, `AttackData`, `MeleeAttack` (windup → hit → recovery, arc and reach, aim assist), the `attack` action (J, Space and an on-screen **ATTACK** button), `TrainingDummy` (hit flash, damage numbers, death and respawn), and pause releasing all gameplay actions |

Combat started before on-device validation of the movement prototype, which the
original brief gated it on. That was a judgment call on the go-ahead; device
validation remains the first next step.

### Checks for the follow-up work

| Check | Result |
|---|---|
| `actionlint` 1.7.12 and `shellcheck` 0.9.0 on the workflow and `tools/*.sh` | Clean |
| Local `tools/test.sh` | **71 passed, 0 failed** on 3 consecutive runs. The new tests found a real bug: a 360° arc missed targets directly behind because of floating-point error. Fixed. |
| CI runs 1–3 on GitHub Actions (`ubuntu-24.04`, `4.7.2.stable.official.ed1daf0bf`) | All green: 38, 43 and 71 tests passed. Each run exported a debug APK signed with Google's `apksigner` (build-tools 36.0.0, which Godot picked over 36.1.0) and verified v2 and v3 signatures. |
| `--check-only` on all 32 scripts | 25 clean. The 7 others report only the `Settings` autoload identifier (a check-only limitation, as before). |
| Jolt Physics warning: "job system exceeded the maximum number of jobs … Please report this" | Logged at most once per run during the arena test, locally and on CI. To isolate it, the same wall-pushing scenario ran 3 times in real time and 3 times fast-forwarded with `--fixed-fps 60`. It appeared in **0 of 3** real-time runs and **2 of 3** fast-forwarded runs, with identical simulation results every time. It is caused by running physics steps back to back without frame pacing, which only happens in tests; when it fires, Jolt waits for jobs to free up. The runner now prints warnings under the test that logged them and counts them in the summary, without failing the test. |
| Rendered combat smoke test (Xvfb, Mobile renderer, lavapipe) | Holding the on-screen **ATTACK** button destroyed a 50 HP dummy in 5 hits over about 2 s. Damage numbers, health label and touch buttons render; no warnings logged. Screenshot: `docs/images/prototype-combat.png`. |

New tests cover:

- **Health:** damage, clamping, death once, revive.
- **MeleeAttack** with real physics bodies:
  - the hit lands exactly when the windup ends;
  - no new attack starts during recovery;
  - targets behind or out of reach are missed;
  - several targets in the arc are all hit;
  - the attacker is never hit;
  - aim assist picks the nearest living target.
- **TouchActionButton:** round hit area, ignores a second finger, works
  together with the joystick, resets on pause and focus loss.
- **Player in the main scene:**
  - damages a dummy in reach and faces it;
  - attack count in 2 s is identical at 30, 60 and 120 Hz;
  - attacking slows movement;
  - pause freezes an attack mid-windup and it finishes after resume;
  - dummy death and respawn;
  - the player cannot walk through a dummy.
- **HUD:** safe-area inset conversion, including a safe area on another screen.

## 5. Known issues and limitations

1. **Not validated on Android hardware.** Touch was tested with synthetic
   events through the engine's input pipeline. Rendering was tested with
   software Vulkan on Linux, not on a phone GPU. Performance on devices is
   unmeasured.
2. **The sandbox toolchain differs from the recommended one.** Locally, the
   editor is nixpkgs' build of the 4.7.2-stable source and signing used
   apksigner 31.0.2. CI uses the official editor and Google's build-tools, and
   gets the same results.
3. **The debug key is per machine and per CI run.** Installing an APK signed by
   a different debug key requires `adb uninstall com.ashenbound.game` first.
4. **Keyboard and touch on the same action.** If a key and a touch control both
   hold the same action and the touch control is released, the action is
   released for both. This is an engine-level limitation of
   `Input.action_release()`, and it only matters on desktops with a
   touchscreen.
5. **Combat simplifications.**
   - The hit arc is checked against target *centers*.
   - Each attack cycle can run up to one physics tick long.
   - There is no player health, enemy AI or hit-stop.
   - The blade is a small placeholder and is often hidden behind the target
     from this camera angle.
6. **Intermittent Jolt warning in fast-forwarded tests.** See section 4. It has
   not been seen in real-time runs. If it ever shows up in `adb logcat` on a
   device, report it upstream with the scenario.
7. **One-time editor diff.** Hand-written scenes have no `unique_id` node
   attributes. The editor adds them the first time each scene is saved; commit
   that diff on its own.
8. `com.ashenbound.game` is a placeholder package name.

## 6. Next steps

1. **Validate on a phone.** Install the CI-built APK on a physical phone, work
   through the [manual checklist](BUILD_ANDROID.md#manual-device-checklist)
   (movement, pause, cutouts and combat), and record the device model, GPU and
   FPS.
2. **Combat feel**, guided by device testing: a clearer swing effect (trail or
   arc), hit-stop and camera shake, and a combo or second attack type.
3. **First real enemy:** a chaser with simple AI, a `Health` component and
   contact damage. That needs player health and a death/restart loop.
4. **Release setup:** settle the application ID, create an upload keystore
   outside the repository, and switch to a Gradle build for AAB when Play
   distribution is needed.

## 7. Enemy AI (branch `feature/enemy-ai`)

Requested after PR #1: "keep going, open a new branch for the enemy AI". The
branch starts from PR #1's head and its PR targets PR #1's branch, so the diff
shows only this work.

| Commit | Change |
|---|---|
| Shared helpers | `MovementStats.step_velocity()`, `turn_toward()` and `yaw_of()` shared by the player and enemies. `HitFeedback` component (flash plus colored damage number) replaces the dummy's own copy. |
| Player health | `Health` (100 HP) and red `HitFeedback` on the player; HUD health bar; topple on death; `DeathScreen` with **Rise again** (scene reload); held input released on death. |
| Hollow | `EnemyController` (IDLE / CHASE / ATTACK / DEAD), `EnemyBehavior` data, `AttackTelegraph` ground sector, `MeleeAttack.cancel()`, `EnemySpawner`, and the Hollow scene with three spawn slots in the arena. |

### Bugs found while building it

1. **Hollows stacked on one spawn point and were flung out of the arena.** The
   rendered smoke test showed a Hollow 274 m away. A trace showed all three
   spawning at (−15, 0, −8) and being pushed apart through the walls. The cause
   was in the spawner: with a player present, every spawn chose the same
   "farthest from the player" point. Spawning now skips points that have a
   living enemy within 1.5 m.
   - The existing spawner tests had missed this because they ran without a
     player.
   - Two regression tests were added. Both fail with the old logic, reproducing
     the out-of-arena positions, and pass with the fix.
2. **DamageNumber lingered for 0.84 s instead of 0.6 s.** This came from PR #1:
   the fade ran for the full duration after its delay. The new `HitFeedback`
   test caught it.
3. **A test assumed a newly added enemy acts on the same physics tick.** It
   doesn't, so the test now waits for the state with a bounded `wait_until()`
   instead of a fixed frame count.

### Checks

| Check | Result |
|---|---|
| `tools/test.sh` | **98 passed, 0 failed** on 3 consecutive runs (+27 tests: AI 13, spawner 6, player health 5, hit feedback 3). The only warning is the known fast-forward Jolt message (section 4). |
| Rendered smoke test (Xvfb, Mobile renderer, lavapipe) | A Hollow chased for 83 frames, stopped at 1.34 m and telegraphed; its hit took the player to 88. The player killed it while taking one more hit (76). On death the death screen opened with Rise again enabled, and pressing it reloaded the scene: new player at 100 HP, death screen hidden. Screenshots: `docs/images/prototype-hollow-telegraph.png`, `prototype-death-screen.png`. |
| `tools/export-android-debug.sh` | Exit 0, APK verified; enemy scenes and scripts packaged |
| `--check-only` on all 42 scripts | No errors besides the known `Settings` autoload limitation |

### Known issues

- **No navigation:** enemies steer straight at the player and can get stuck
  behind a pillar. (Addressed in [section 8](#8-enemy-navigation-branch-featureenemy-navigation).)
- **No stagger:** player hits do not interrupt a Hollow's windup.
- **Readability:** the Hollow's dark body is hard to see when it is behind
  the player from this camera angle. The glowing eyes and the telegraph help;
  a silhouette outline or a camera-facing occlusion effect would help more.
- **Untested on a phone**, like everything else.

### Next steps

1. Validate on a phone: the extended checklist in
   [BUILD_ANDROID.md](BUILD_ANDROID.md#manual-device-checklist) now covers
   enemies, death and restart.
2. Navigation (`NavigationRegion3D` baked from the arena) once layouts get
   walls that block line of sight.
3. Combat feel: hit-stop, a short stagger on the enemy, a clearer swing effect.
4. A second enemy type (ranged or charging) to exercise `EnemyBehavior` reuse.

## 8. Enemy navigation (branch `feature/enemy-navigation`)

Requested after PR #2: "keep going, new branch for enemy navigation". The
branch starts from PR #2's head and its PR targets PR #2's branch.

Before this change, a Hollow chasing the player straight across a pillar
pressed into it indefinitely. A probe with the player at (0, 0, −7.5) and a
Hollow at (0, 0, −12.5), with PillarNorth at (0, 0, −10) between them, stopped the
Hollow at z = −11.10 within half a second (the pillar's surface plus the
Hollow's radius), and it stayed there for the rest of the 4 s run.

| Change | Details |
|---|---|
| Navigation mesh | The arena's floor, walls and pillars moved under `Navigation`, a `BakedNavigationRegion` that bakes at load from static colliders on the world layer. The settings are in `resources/navigation/ground_navigation_mesh.tres`: agent radius 0.5 m, height 2 m, islands under 1 m² dropped. The arena bakes to 39 polygons in about 10 ms on this container's CPU. |
| Path following | `EnemyController` gets an optional `navigation` agent. While chasing, it replans when the player has moved 0.5 m from the end of the path, and walks toward the next path point with the unchanged movement code. With no path, it steers straight at the player as before. |
| Hollow scene | A `NavigationAgent3D` with a 0.5 m waypoint distance and a 0.5 m path height offset (the baked mesh sits 0.5 m above the floor). |
| Project settings | Navigation map and region updates are synchronous (`navigation/world/*_use_async_iterations = false`), so paths become available on a predictable frame. |
| Tests | `add_level()` and `wait_for_navigation()` helpers. The AI suite now runs on a baked floor. A new `test_enemy_navigation` suite has 8 tests. |

The design notes are in
[ARCHITECTURE.md](ARCHITECTURE.md#navigation).

### Problems found while building it

1. **Path points float 0.5 m above the floor.** Recast places the baked mesh
   two cells (2 × 0.25 m) above the surface it was baked from. The agent checks
   waypoints by 3D distance, so with its 0.5 m waypoint distance it could never
   reach one. The agent's `path_height_offset` is now 0.5 m, and a test checks
   that every vertex of the arena's mesh sits exactly that high.
2. **Walkable islands on the pillar tops.** The first bake had four
   0.5 × 0.5 m polygons at y = 4.5. Raising `region_min_size` to 4 (16 cells,
   1 m²) removes them, and the same test would catch them coming back.
3. **A test waited for navigation by frame count, and the map updated on a
   background thread.** With `--fixed-fps`, 30 physics frames can pass before
   the thread finishes, so the wait timed out once in the first run. Making
   map and region updates synchronous fixed it: the suite then passed on three
   consecutive runs.

### Checks

| Check | Result |
|---|---|
| `tools/test.sh` | **106 passed, 0 failed** on 3 consecutive runs (+8 navigation tests). The only warning is the known fast-forward Jolt message. |
| Tests fail without the feature | With `_chase_direction()` forced to straight-line steering, 4 navigation tests fail: wall, replan, frame rate and pillar. With replanning disabled (the target set only once per chase), the replan test fails. Both changes were reverted. |
| Frame-rate independence | Time from spawn to the first attack, walking around the 8 m wall: 3.13 s at 30 Hz, 3.05 s at 60 Hz, 3.06 s at 120 Hz (the test allows ±5 %). |
| Rendered smoke test (Xvfb, Mobile renderer, lavapipe) | In the real arena, the Hollow walked around the west side of PillarNorth and started its attack 77 frames after spawning, 1.32 m from the player. Screenshot: `docs/images/prototype-hollow-navigation.png`. |
| `tools/export-android-debug.sh` | Exit 0, APK signature verified; the navigation script and settings are packaged. |
| `--check-only` on all 44 scripts | The new script passes. Every error traces back to the known `Settings` autoload limitation (same cascade as on the base branch). |

### Known issues

- **Training dummies are not in the navigation mesh.** Hollows slide around a
  dummy instead of planning around it.
- **No avoidance between enemies.** Hollows can bunch up and push each other.
- **Aggro and leash use straight-line distance,** so a Hollow on the far side
  of a wall still notices the player.
- **The bake runs on the main thread at load.** That is fine for the test arena
  but not for large levels, which should be baked in the editor.
- **Untested on a phone.**

### Next steps

1. Validate on a phone, including the new pillar item in the device checklist.
2. Combat feel: hit-stop, a short stagger on the enemy, a clearer swing effect.
3. Navigation avoidance (RVO) once more than a few enemies chase at once.
4. A second enemy type (ranged or charging) to exercise `EnemyBehavior` reuse.

## 9. Art reference and dodge (branches `feature/art-reference`, `feature/dodge-skills`)

Requested after PR #3: "Go ahead and add the reference and then move to the
next features."

- **Art reference (PR #4, docs only).** `docs/art/concept-sheet.jpg` and
  [ART_DIRECTION.md](ART_DIRECTION.md) hold the supplied concept sheet, its
  palette and rarity colors, how the build compares, and the planned order:
  dodge and skill buttons, then loot with rarity tiers, then a second enemy.
- **Dodge.** The first skill from the concept sheet's action cluster:

| Change | Details |
|---|---|
| `Dodge` and `DodgeData` | A 4 m dash over 0.3 s, invulnerable for the first 0.25 s, with a 0.9 s cooldown and a 0.2 s input buffer. The body drives it with `step(delta)`; the last tick is partial, so the distance is exact at any tick rate. |
| `Health.invulnerable` | `apply_damage()` deals nothing while it is set. `MeleeAttack.struck` now lists only targets that took damage. |
| `PlayerController` | Buffers the press. Dashes toward the input or the facing. Cancels the attack in progress and holds attacks off during the dash. Caps speed to running speed when the dash ends. Death cancels the dash. |
| HUD | A **DODGE** button beside **ATTACK**. `TouchActionButton` gained an optional cooldown sweep. Keyboard: Left Shift or K. |
| `DodgeLean` | Placeholder animation: a 30° lean and a squash during the dash. |

### Checks

| Check | Result |
|---|---|
| `tools/test.sh` | **120 passed, 0 failed** on 3 consecutive runs (+14 dodge tests). The only warning is the known fast-forward Jolt message. |
| Tests fail without the feature | Each of these was removed in turn, and exactly one test failed each time: the partial-tick correction (exact distance), the invulnerability check (a hit inside the window does nothing), the input buffer (an early press dodges), the attack cancel, and the exit speed cap (frame-rate test). All were reverted, and the restored files were compared byte for byte with backups. |
| Invulnerable window against a real Hollow | With the player dodging into a wall (so they stay in reach), a hit landing 0.2 s into the dodge deals nothing and `struck` reports no targets. A hit landing after the window deals 12. |
| Rendered smoke test (Xvfb, Mobile renderer) | A touch on the HUD **DODGE** button dashed the player out of a Hollow's windup with no damage. The button showed its cooldown sweep (0.54 left 20 ticks after the dash). Screenshot: `docs/images/prototype-dodge.png`. |

### Known issues

- **The slide after the dash depends slightly on tick rate**, by up to 5 cm
  between 30 Hz and 60 Hz. This is not the dodge: ordinary deceleration
  updates speed before moving each tick, so it stops about half a tick of
  speed short, the same as releasing the stick after running. The dash
  distance itself is exact. Fixing it means changing how all movement
  integrates speed, which is out of this PR's scope.
- **No feedback for an evaded hit** beyond the missing damage number.
- **The dash does not pass through enemies.**
- **Untested on a phone.**

## 10. Project charter and the Warden's starter abilities (branches `docs/project-charter`, `feature/warden-abilities`)

The owner supplied the project charter, now committed as
[CLAUDE.md](../CLAUDE.md), and decided:

- loot is parked until Milestone 4 (draft PR #6);
- the charter goes into the repository;
- Cleave, Bulwark Guard and Ember Brand are the Warden's starter abilities;
- per-class skill trees come later.

[CURRENT_STATUS.md](CURRENT_STATUS.md) now carries the live state in the
charter's terms. The report below follows the charter's format.

```text
ASHENBOUND MILESTONE REPORT

Milestone: 2: Combat foundation (three abilities)
Status: Validated, verified in runtime. Device: blocked.

Changes:
- Specification first: docs/characters/warden.md (numbers, priority rules,
  acceptance checks per ability)
- The player scene is now the Warden (scenes/player/warden.tscn):
  greatsword placeholder, blackened-iron armor with an ember glow
- Ability base class; CleaveAbility, GuardAbility and BrandAbility; Burning status
- Health: damage_multiplier (guard mitigation) and a `hit` signal
- Targeting helper extracted from MeleeAttack (shared with Ember Brand)
- WeaponSwing takes a list of attacks (basic attack and Cleave)
- Inputs ability_1 to ability_3 (Q E R / 1 2 3); CLEAVE, GUARD and BRAND
  buttons in an arc around ATTACK, each with a cooldown sweep

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 140 passed, 0 failed, on 3 runs (+20 tests)
- Command: tools/export-android-debug.sh
  Exit code: 0
  Result: APK signature verified, ability scripts packaged, tests excluded
- Command: godot --check-only on the 10 new and changed scripts
  Exit code: 0
  Result: no errors
- Command: rendered run (Xvfb, Mobile renderer, software Vulkan)
  Exit code: 0
  Result: Cleave hit two Hollows for 25 each; Guard's counter finished them;
          Brand ticked 4 on the nearest target

Manual checks:
- None on a device

Not tested:
- On a device: the ability buttons' thumb reach and the feel of each ability

Blockers:
- No Android device, and no /dev/kvm for an emulator

Known risks:
- Five buttons now sit around ATTACK; their spacing needs checking on a phone
- Ability presses are not buffered

Recommended next task:
- Split the Hollow's attack state into telegraph, attack and recovery

Acceptance criteria (docs/characters/warden.md):
- [x] Cleave: 25 to each enemy in the arc once; none behind or out of reach;
      cooldown; slows the Warden; a dodge cancels it
- [x] Guard: hits cut to 20%; one counter per guard; full damage after;
      rooted; a dodge ends it
- [x] Brand: no target, no cooldown; 8 ticks of 4 on the nearest enemy at
      30, 60 and 120 Hz; restarts instead of stacking; stops on death
- [ ] Verified on device
```

**Tests fail without the feature.** Each behavior was removed in turn, and
each time the test meant to catch it failed:

- guard mitigation;
- the guard's once-only counter;
- the burn timer's carried-over time;
- burns not stacking;
- Brand not spending its cooldown without a target;
- one ability at a time.

Two of these first passed, which showed two tests were too weak:

- the counter test never had two hits during one guard;
- the burn rate test used 0.5 s, which divides evenly into every tick rate
  tested.

Both tests were strengthened, and both probes now fail. Every probe was
reverted, and the restored files were compared byte for byte with backups.

## 11. Enemy states (branch `feature/enemy-states`)

The Hollow's attack state is split into the charter's states: IDLE, APPROACH,
TELEGRAPH, ATTACK, RECOVERY and DEAD. ATTACK is the one physics tick on
which the hit resolves. `state_changed` reports every change.

Checks:

- **Tests:** `tools/test.sh` gives 144 passed, 0 failed on 3 runs. Four tests
  are new:
  - the order of the states;
  - each state's length against the attack data, with the hit landing on
    the ATTACK tick;
  - the telegraph being visible exactly during TELEGRAPH;
  - death during TELEGRAPH going straight to DEAD.
- **Probes:**
  - with the ATTACK state removed, the order and timing tests fail;
  - with the telegraph left visible after the hit, both telegraph tests fail;
  - both changes were reverted and the restored files compared byte for byte
    with backups.

Milestone 2 is now complete apart from its device check, which is blocked.

## 12. First art pass (branch `feature/art-pass`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: Art pass (owner request, ahead of Milestone 3)
Status: Validated, verified in runtime (desktop software Vulkan and headless Chromium); not verified on device

Changes:
- The Warden is the KayKit Knight with its greatsword, recoloured to
  blackened iron, ember and crimson (tools/art/make_warden_texture.py), with
  an ember light that follows it.
- The Hollow is a KayKit Skeleton Warrior with a blade on its hand bone and
  glowing eyes. Training targets are dormant skeletons.
- CharacterAnimator plays idle, run, attack, Cleave, Guard, Brand, dodge,
  hit and death clips from gameplay signals; ModelDressing applies materials,
  hides spare parts and holds poses.
- The arena: KayKit floor tiles, walls, colonnades, pillars, torches, banners
  and barrels; TileGrid lays repeated pieces out as MultiMesh chunks. Fog,
  stronger moonlight and ambient light.
- RendererLighting gives the web preview's Compatibility renderer darker
  lighting.
- Removed the placeholder WeaponSwing, DodgeLean and death topple, and the
  materials only they used.
- docs/ART_ASSET_PIPELINE.md records sources, commits, licences and changes.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 156 passed, 0 failed (11 new tests: 7 animation, 4 dressing)
- Command: probe, Cleave mapped to the wrong clip and the west wall moved 2 m
  Exit code: 1
  Result: the animation and wall tests failed; files restored and compared byte for byte
- Command: rendered main scene under Xvfb, software Vulkan, PerfLog
  Exit code: 0
  Result: draw_calls about 192 (was about 106); screenshots inspected
- Command: tools/export-web.sh, then node tools/web/smoke.js build/web
  Exit code: 0
  Result: web smoke test passed; index.pck 4.2 MB (4.1 MB gzipped)

Manual checks:
- Screenshots: the Warden, skeletons and dummies face the right way, the
  greatsword and blade sit in the hands, walls stand on their colliders,
  torches and banners hang on the walls, the web build is no longer washed out.

Not tested:
- Any physical phone: frame rate with skinned characters, readability at
  arm's length.
- The Android APK with the new art (CI builds it).

Blockers:
- None.

Known risks:
- Draw calls nearly doubled. Each character is 6 to 10 skinned meshes plus
  shadows. Merge meshes or drop small-part shadows if a phone struggles.
- Clips are sped up to fit fast actions (up to 3×), so some read as hurried.
- Desktop Compatibility rendering crashes in the sandbox, so the web look was
  tuned in headless Chromium only.

Recommended next task:
- Owner playtest of the web preview; then the Milestone 3 specification.

Acceptance criteria:
- [x] Third-party assets are CC0, with licence files and provenance
- [x] Gameplay unchanged: all previous tests pass; animation is presentation only
- [x] The project imports, runs and exports (desktop, web)
- [ ] Verified on a phone
```

## 13. Milestone 3, step 1: encounters (branch `feature/m3-encounters`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: 3 (first dungeon), step 1 of 6: encounters
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- docs/dungeons/ashen_crypt.md: the Milestone 3 specification (layout,
  enemies, encounters, the Ashen Lord's phases, victory and defeat, Ash
  rewards, replay, acceptance checks, build order).
- The Hollow is renamed Skeleton Warrior (scene, data, material, tests, docs).
- EncounterData / WaveData resources and EncounterController: waves in order,
  the next one 1.5 s after the last enemy of the current one dies.
- EnemyController: RISING state (inert and invulnerable for 0.8 s, with the
  skeleton spawn clip) and `hunting` (no aggro or leash limits).
- RunController: victory when every encounter is cleared, defeat on death,
  first result stands; kills and play time.
- The main scene's endless spawner is replaced by a two-wave Ossuary Hall
  encounter (3 + 3 Skeleton Warriors). Victory reuses the death screen with
  "The hall is cleared" and Play again. EnemySpawner removed.
- Training dummies render as stone statues, so they no longer look like
  enemies.

Commands run:
- Command: tools/test.sh (twice)
  Exit code: 0
  Result: 157 passed, 0 failed (7 new; the 6 spawner tests were removed with it)
- Command: probes: waves advancing with survivors; rising without
  invulnerability; a second result overriding the first
  Exit code: 1
  Result: the matching tests failed; files restored and compared byte for byte
- Command: rendered run under Xvfb (software Vulkan)
  Exit code: 0
  Result: skeletons rise, wave 2 follows wave 1, victory screen after 6 kills

Not tested:
- On a phone.

Known risks:
- The arena is still the open test arena; rooms and gates come in step 2.

Recommended next task:
- Step 2: the crypt (rooms, corridors, gates, room triggers).

Acceptance criteria (spec, so far):
- [x] 1. Waves advance in order, only when the current wave is fully dead
- [x] 3. Rising enemies cannot deal or take damage
- [x] 8. Victory and defeat are mutually exclusive
- [ ] The rest: later steps
```

## 14. Milestone 3, step 2: the crypt (branch `feature/m3-crypt`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: 3 (first dungeon), step 2 of 6: the crypt
Status: Validated, verified in runtime (desktop software Vulkan and the web
build in headless Chromium); not verified on device

Changes:
- Level (scripts/world/level.gd): a level scene names its player start and the
  encounters that win the run. main.tscn no longer contains a level; Main
  instances `level_scene` as "Level". The game plays the Ashen Crypt; tests
  play the old arena, which became a Level holding its dummies and encounter.
- The Ashen Crypt (scenes/dungeon/crypt.tscn): Gatehouse 12×12, Ossuary Hall
  20×20, Cultist Chapel 20×24, Ashen Throne 28×28, joined by 4×8 m corridors.
  CryptRoom builds floors, walls, collision and torches from a size and the
  kind of north/south edge.
- CryptGate: KayKit doorway with a door; a closed door blocks bodies and the
  navigation mesh, which rebakes (threaded where the build has threads).
- CombatRoom: entering shuts the door behind and the exit, starts the
  encounter; clearing opens both and heals 30 (new Health.heal(), shown by the
  HUD).
- See-through walls: a cutout shader on north walls, gates and tall pillars
  opens a dithered hole around the hero (OcclusionFocus on the Warden).
- Placeholder encounters until steps 3 to 5: Chapel 4 + 4 and Throne 4 + 6
  Skeleton Warriors. Victory reads "The crypt is cleared".
- The test runner now fails a suite that does not load; before, a parse error
  in a test file dropped its tests and only logged an error.

Commands run:
- Command: tools/test.sh (several runs)
  Exit code: 0
  Result: 163 passed, 0 failed (6 new in test_crypt.gd)
- Command: probes: a door that never stops blocking; no heal on clear; no
  rebake; a test file that does not parse
  Exit code: 1
  Result: the matching tests failed; files restored and compared byte for byte
- Command: rendered walk through every room under Xvfb (software Vulkan)
  Exit code: 0
  Result: rooms, doors, torches and banners in place; the hero shows through
  the tall wall in each corridor; the Ossuary door is shut while it is fought
- Command: tools/export-web.sh, then tools/web/smoke.js
  Exit code: 0
  Result: the crypt draws in the Compatibility renderer with the cutout shader
- Command: cost probe in the rendered crypt
  Exit code: 0
  Result: 151 to 234 draw calls depending on the room (old arena about 192);
  a full navigation rebake takes 12 to 17 ms on this desktop CPU

Not tested:
- On a phone (frame rate, readability of the see-through patch).
- Doors and rebakes in the browser: the web smoke test only loads the game.

Known risks:
- An intermittent Jolt warning ("job system exceeded the maximum number of
  jobs") appeared in about half of the full test runs, in a Guard test this
  change does not touch. It is not a failure; likely thread contention in the
  sandbox.
- The draw-call count rose; profile on a phone before adding more lights.

Recommended next task:
- Step 3: the Dark Cultist.

Acceptance criteria (spec, so far):
- [x] 1. Waves advance in order, only when the current wave is fully dead
- [x] 2. A room's gates close on entry and open only when it is cleared
- [x] 3. Rising enemies cannot deal or take damage
- [x] 8. Victory and defeat are mutually exclusive
- [ ] The rest: later steps
```
