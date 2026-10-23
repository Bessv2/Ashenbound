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

## 15. Milestone 3, step 3: the Dark Cultist (branch `feature/m3-cultist`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: 3 (first dungeon), step 3 of 6: the Dark Cultist
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- RangedAttack (extends MeleeAttack) fires a Projectile at the end of its
  windup; ProjectileAttackData holds speed, range, width and height.
- Projectile: a ray-swept shot that damages the first target it touches,
  stops at walls and at its range, and is spent on an invulnerable target.
- AttackTelegraph draws a strip along the bolt's path for projectile attacks.
- EnemyBehavior.retreat_distance (back away from a close player unless
  cornered) and needs_line_of_sight (no casting through walls).
- The Dark Cultist: KayKit Skeleton Mage with a skull staff, robe recoloured
  black-violet (tools/art/make_cultist_texture.py), violet eyes, 24 HP, a 0.7 s
  shadow bolt for 10 damage at 10 m/s over 12 m.
- Encounters: one Cultist in the Ossuary's second wave, two in the Chapel's
  first.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 168 passed, 0 failed (5 new in test_dark_cultist.gd)
- Command: probes: no line-of-sight check; no retreat; never cornered; bolts
  ignoring walls
  Exit code: 1
  Result: the matching tests failed; files restored and compared byte for byte
- Command: rendered fight in the Chapel under Xvfb (software Vulkan)
  Exit code: 0
  Result: two Cultists show their line telegraphs, then violet bolts fly

Not tested:
- On a phone.

Recommended next task:
- Step 4: the Fallen Knight.

Acceptance criteria (spec, so far):
- [x] 1. Waves advance in order
- [x] 2. Gates close on entry and open on clear
- [x] 3. Rising enemies cannot deal or take damage
- [x] 4. The Cultist's bolt is telegraphed, travels, can be dodged, and walls stop it
- [x] 8. Victory and defeat are mutually exclusive
- [ ] The rest: later steps
```

## 16. Milestone 3, step 4: the Fallen Knight (branch `feature/m3-knight`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: 3 (first dungeon), step 4 of 6: the Fallen Knight elite
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- EnemyController.special_attack, used every EnemyBehavior.special_every-th
  attack.
- AttackData.knockback and PlayerController.push(): a timed shove, exact at
  any tick rate, stopped by walls, overridden by a dodge.
- Health.apply_damage(amount, from) and direction_multiplier; FrontalGuard
  halves hits from the front (120°) while the body is not attacking.
- EliteBar: name and health bar over an elite, facing the camera.
- The Fallen Knight: 140 HP, 2.6 m/s, cleave 26 (0.9 s), shield bash 8 with a
  3 m push every third attack, shield-up idle; the KayKit Skeleton Warrior at
  1.25× with axe and large shield, darkened, ember eyes. Leads the Chapel's
  second wave.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 174 passed, 0 failed (6 new in test_fallen_knight.gd)
- Command: probes: guard up mid-swing; no knockback; no special attack
  Exit code: 1
  Result: the matching tests failed; files restored and compared byte for byte
- Command: rendered Chapel second wave under Xvfb (software Vulkan)
  Exit code: 0
  Result: the Knight with shield and axe, its cleave sector, name and bar

Not tested:
- On a phone.

Recommended next task:
- Step 5: the Ashen Lord.

Acceptance criteria (spec, so far):
- [x] 1, 2, 3, 4, 8 (see step 3)
- [x] 5. The Fallen Knight's front damage reduction applies only from the
      front and only while it is not attacking
- [ ] The rest: later steps
```

## 17. Milestone 3, step 5: the Ashen Lord (branch `feature/m3-ashen-lord`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: 3 (first dungeon), step 5 of 6: the boss
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- AshenLord (extends EnemyController): 600 HP, three phases at 60 % and 30 %,
  each entered once and in order (one roar each, inert and invulnerable).
  Cinder Cleave (30, 1.0 s, 160°), Ash Slam (35, 1.2 s, 4 m circle) when the
  player is within 3 m, Ember Ring (20, expands to 10 m over 2 s) every third
  attack in phase 2 and every other in phase 3. Phase 2 summons three
  Skeleton Warriors at the braziers; phase 3 winds up 25 % faster and moves
  30 % faster. The KayKit Knight at 1.7×, ash-dark with ember emission; rises
  from a throne.
- EncounterController.adopt(): summoned adds count toward the encounter; they
  die with the Lord.
- RingAttack and EmberRing; MeleeAttack.windup_scale; EnemyController
  speed_multiplier.
- Fixed: EnemyController asked for the next attack twice per attack, so a
  subclass that remembers its choice recorded a different attack from the
  one that started. It now chooses once.
- BossBar at the top of the HUD.
- The Throne encounter is the Lord alone (rise 1.5 s).

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 180 passed, 0 failed (6 new in test_ashen_lord.gd)
- Command: probes: no queued phase after a roar; adds not adopted; ring
  hitting every tick
  Exit code: 1
  Result: the matching tests failed; files restored and compared byte for byte
- Command: rendered boss fight under Xvfb (software Vulkan)
  Exit code: 0
  Result: rise, slam circle, three adds in phase 2, the expanding ring, boss bar

Not tested:
- On a phone; boss balance in real play.

Recommended next task:
- Step 6: run summary and Ash, multi-run tests (Milestone 3 gate).

Acceptance criteria (spec, so far):
- [x] 1, 2, 3, 4, 5, 8
- [x] 6. The Ashen Lord enters each phase exactly once, in order
- [x] 7. Phase 2 summons exactly three adds, once; they die with the Lord
- [ ] 9, 10, 11: step 6
```

## 18. Milestone 3, step 6: run summary and Ash (branch `feature/m3-summary`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: 3 (first dungeon), complete
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- EnemyController.ash_value (1 / 2 / 10 / 50).
- RunController: damage taken, Ash, a run id, claim_reward().
- Profile autoload: lasting Ash; grant_run_reward() pays each run id once.
- The end screen shows time, kills, damage taken, Ash earned and held; a
  victory waits 2 s before it.
- Fixed: a killing blow on the Ashen Lord crossed his phase thresholds and
  summoned adds as he died.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 185 passed, 0 failed (5 new)
- Command: probes: paying a run twice; phases on a killing blow
  Exit code: 1
  Result: the matching tests failed; files restored and compared byte for byte
- Command: rendered full run under Xvfb (software Vulkan)
  Exit code: 0
  Result: summary "The crypt is cleared", 15 enemies, Ash earned 76

Not tested:
- On a phone. Pause and focus loss were tested in the arena, not per room.

Acceptance criteria (docs/dungeons/ashen_crypt.md):
- [x] 1. Waves advance in order, only when the current wave is dead
- [x] 2. Gates close on entry and open only when the room is cleared
- [x] 3. Rising enemies cannot deal or take damage
- [x] 4. The Cultist's bolt: telegraphed, travels, dodgeable, stopped by walls
- [x] 5. The Knight's guard: front only, not while attacking
- [x] 6. The Lord's phases: once each, in order, even from one hit
- [x] 7. Phase 2 summons three adds once; they die with him
- [x] 8. Victory and defeat are mutually exclusive
- [x] 9. The reward is paid once per run; a new run starts at zero
- [x] 10. Three consecutive runs in one session, no stale enemies, gates or timers
- [ ] 11. Pause, focus loss and the death screen in every room: covered in
      the arena by existing tests; per-room check is in the device checklist

Milestone gate: multiple consecutive runs complete correctly with no stale
state or duplicate rewards. Passes in automated tests; device check open.

Recommended next task:
- Milestone 4: loot design doc, then items and equipment.
```

## 19. Milestone 4, design and step 1: the item model (branch `feature/m4-items`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: 4 (first loot loop), step 1 of 5: item model
Status: Validated (no UI or gameplay yet)

Changes:
- docs/LOOT.md: the Milestone 4 design (items, rarity, stats, drops, UI,
  persistence, what comes after, build order, acceptance checks). Owner
  defaults are marked.
- ItemBase, AffixDef, ItemCatalog (9 bases covering the 9 slots, 9 affix
  stats, at least 5 per slot), ItemInstance with JSON round trip, Rarity
  (six tiers), ItemStats.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 191 passed, 0 failed (6 new in test_items.gd)
- Command: probes: duplicate affix stats; Mythic not rolling top values
  Exit code: 1
  Result: the matching test failed; file restored and compared byte for byte

Recommended next task:
- Step 2: CharacterStats and combat.
```

## 20. Milestone 4, steps 2 and 3: stats in combat and drops (branch `feature/m4-stats`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: 4 (first loot loop), steps 2 and 3 of 5
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- CharacterStats on the Warden: equipment (and a skill-tree bonus) to final
  numbers, applied to attacks (damage, crits, attack speed), abilities
  (cooldowns, Brand's power), movement, armour, max health, health on kill.
- Equipment (9 slots) and Inventory (30) in Profile; equip/unequip that
  never loses an item.
- DropTable per enemy (Skeleton 8%, Cultist 12%, Knight 2 items, Lord 3 Rare+),
  LootDropper, LootPickup (rarity beam, name, walk-over pickup), gathering at
  victory, "Items found" in the summary, pickup messages on the HUD.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 203 passed, 0 failed (12 new in test_character_stats.gd and test_loot.gd)
- Command: probes: armour ignored; equip losing the replaced item
  Exit code: 1
  Result: the matching tests failed; files restored and compared byte for byte
- Command: rendered loot in the Chapel under Xvfb
  Exit code: 0
  Result: beams in the five rarity colours, names readable

Not tested:
- On a phone.

Recommended next task:
- Steps 4 and 5: inventory screen, save and load.
```

## 21. Milestone 4, steps 4 and 5: inventory screen and saving (branch `feature/m4-inventory`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: 4 (first loot loop), complete
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- InventoryPanel: nine slots, bag grid, item card with per-stat comparison,
  Equip / Unequip, rarity frames; opened by the HUD's BAG button, pauses the
  game.
- Profile saving: versioned JSON, written atomically with a backup, loaded
  with fallback; broken files kept aside; unreadable items skipped.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 209 passed, 0 failed (6 new in test_save_and_inventory.gd). Two
  expected warnings come from the corrupt-save tests.
- Command: rendered inventory screen under Xvfb
  Exit code: 0
  Result: slots, bag and card fit 1280×720; buttons always visible

Acceptance (docs/LOOT.md):
- [x] 1. Affixes in range, count by rarity
- [x] 2. Items survive save and load unchanged
- [x] 3. Every stat changes combat; removing the item restores it
- [x] 4. Equip and unequip never lose or duplicate an item
- [x] 5. A drop is picked up once; a full bag leaves it
- [x] 6. A restart restores bag, equipment and Ash (simulated in tests)
- [x] 7. A corrupt save does not crash and does not delete data

Not tested:
- On a phone; saving in the browser preview (user:// is browser storage there).

Recommended next task:
- XP, levels and the skill trees.
```

## 22. XP, levels and skill trees (branch `feature/skill-trees`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: progression (owner request 2026-10-22; leads into Milestone 6)
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- docs/SKILL_TREES.md: XP curve, points, tree rules, three trees.
- SkillNode, SkillTree, SkillStats; trees for the Warden (playable),
  Reaver and Hexbinder (previews), 15 nodes in 3 branches each.
- Profile: level, XP, learned ranks, learn/reset, save version 2 with
  version 1 migration.
- CharacterStats takes the tree as a bonus; skill-only stats change Cleave,
  Guard, its counter and Brand.
- XP per kill; HUD level, points and XP bar; level-up message.
- SkillTreePanel (SKILLS button).

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 216 passed, 0 failed (7 new in test_skill_trees.gd)
- Command: rendered HUD and skill screens under Xvfb
  Exit code: 0
  Result: level and XP bar; tree with learned, open and locked nodes; preview tab

Acceptance (docs/SKILL_TREES.md): checks 1 to 4 pass in automated tests.

Not tested:
- On a phone.
```

## 23. Visual pass (branch `feature/visual-pass`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: presentation (owner request 2026-10-22: "better visuals")
Status: Validated, verified in runtime (desktop software Vulkan, web smoke test); not verified on device

Changes:
- Vfx: one-shot particle bursts and slash arcs, visual only, self-freeing,
  CPU particles so the web (Compatibility) build matches.
- HitFeedback: sparks on every hit; ash and ember burst when an enemy dies.
- AttackSwoosh on the Warden: an ember arc along each melee hit (basic
  attack, Cleave, Guard counter), gold on a critical hit.
- Camera shake from trauma: hero hurt, critical hits, elite and boss kills.
  A "Screen shake" toggle in the pause menu, saved with the settings.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 219 passed, 0 failed (3 new in test_visual_effects.gd); probes that
  disable the arc or ignore the setting fail the matching tests
- Command: tools/export-web.sh, then tools/web/smoke.js
  Exit code: 0, 0
  Result: web smoke test passed
- Command: rendered Cleave and a kill in the crypt under Xvfb
  Exit code: 0
  Result: the ember arc and the death burst are visible

Not tested:
- On a phone: effect cost on mobile GPUs, and whether the shake feels right.
```

## 24. Crypt tiers (branch `feature/crypt-tiers`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: gameplay loop (owner request 2026-10-22: "Up the gameplay loop")
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- docs/dungeons/tiers.md: tiers 1 to 10, unlock and choice rules, scaling.
- Difficulty: one place for the numbers; scales enemies as they spawn
  (health, every attack's damage_scale, Ash, XP).
- Bolts and the Lord's ring now deal damage through roll_damage(), so they
  scale like melee hits.
- Drops: item level, drop chance and rarity follow the tier.
- Profile: tier_unlocked and tier, complete_tier(), select_tier(); save
  version 3, older saves at tier 1.
- End screen: a second button; descend / replay after a win, retry / lower
  after a fall. The summary names the tier.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 225 passed, 0 failed (6 new in test_crypt_tiers.gd); probes that
  drop the damage scaling, the unlock, or the saved tier fail the matching
  tests
- Command: a tier 3 crypt run rendered under Xvfb
  Exit code: 0
  Result: 152 Ash (2 × 76), "Descend to tier 4" and "Replay tier 3" shown

Not tested:
- On a phone; balance of the higher tiers in real play.
```

## 25. Gold, salvage and upgrades (branch `feature/gold-upgrades`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: Milestone 4 follow-up (charter: "Add upgrade/salvage after basic persistence works")
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- Forge: salvage values, upgrade prices (gold and Ash), +10% per rank, +5 max.
- ItemInstance.upgrade, applied in total_stats(); saved as "up" (old items +0).
- Profile.gold, salvage(), upgrade_item(); worn upgrades refresh the hero.
- EnemyController.gold_value (3/5/25/100), scaled by tier; paid with the run.
- Bag card: Upgrade and Salvage (second tap confirms), prices on the card,
  gold next to Ash. Summary shows the gold earned.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 230 passed, 0 failed (5 new in test_gold_and_upgrades.gd); probes
  that skip the salvage confirmation, the hero refresh or the run's gold fail
  the matching tests
- Command: bag screen rendered under Xvfb
  Exit code: 0
  Result: first layout overflowed the screen with the long button texts;
  fixed (short labels, prices on the card) and re-captured

Not tested:
- On a phone; the gold economy in real play.
```

## 26. Offline rewards, provisional (branch `feature/offline-rewards`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: Milestone 6 groundwork (owner's vision; ahead of Milestone 5)
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device; provisional (device clock)

Changes:
- docs/OFFLINE_REWARDS.md: rules, cap, clock handling, server plan.
- OfflineRewards: half a run's XP, gold and Ash per hour of the highest tier
  cleared; 5-minute minimum, 8-hour cap.
- Profile: tier_cleared, last_seen (stamped on save), offline_seconds bank,
  bank_time_away() at launch and on Android resume, claim_offline(); saves
  on going to the background; a replaceable clock for tests.
- OfflinePanel ("While you were away"), opened by Main, pauses until Collect.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 237 passed, 0 failed (7 new in test_offline_rewards.gd); probes
  that bank a backwards clock, pay twice, or leave the screen up when
  unpaused fail the matching tests
- Command: the away screen rendered under Xvfb
  Exit code: 0
  Result: 5 h 20 min at tier 2: +3160 XP, +680 gold, +304 Ash

Not tested:
- On a phone: background/resume banking (NOTIFICATION_APPLICATION_RESUMED).
- Clock tampering beyond a backwards clock (accepted until Milestone 5).
```

## 27. Skill trees for the whole roster (branch `feature/six-trees`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: progression (owner request 2026-10-22: "a skill tree for the first 3 classes or all 6 classes")
Status: Validated, verified in runtime (desktop software Vulkan)

Changes:
- Dreadhunter, Reliquary and Gravecaller trees (15 nodes in the charter's 3
  branches each) as previews; class-specific stat keys added to SkillStats.
- The skill screen has six class tabs (narrower).

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 237 passed, 0 failed; every tree validates (known stats, same-branch
  requirements), 3 × 5 nodes, only the Warden's playable
- Command: the skill screen rendered under Xvfb
  Exit code: 0
  Result: six tabs fit at 1280×720; the Gravecaller tree and a node card shown

Not tested:
- On a phone (tab size on small screens).
```

## 28. The Reaver, second playable class (branch `feature/reaver`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: roster (charter 13.9 steps 2 and 3: combat abstraction review, then a second class)
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- Abstraction review, driven by the second class: each Ability applies its
  own skill stats (apply_stats); CharacterStats no longer names Warden nodes.
  Burning takes an effect name and colour (a bleed is not a burn).
- Reaver scene (KayKit Rogue, CC0), Twin Slash, faster dodge, 85 health.
- VeilRendAbility (dash through enemies, unhurt; cut and mark on the path),
  Marked, BleedAbility; Fan of Blades reuses CleaveAbility with its own data.
- Reaver tree playable. Profile.hero_class (saved); Main swaps the hero;
  the skill screen opens on the played class and offers "Play …".
- docs/characters/reaver.md.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 245 passed, 0 failed (8 new in test_reaver.gd; the refactor kept
  every Warden test green); probes that keep the enemy layer during the dash
  or skip the hero swap fail the matching tests
- Command: the Reaver in the crypt rendered under Xvfb
  Exit code: 0
  Result: Veil Rend through two skeletons: 14 each, both marked

Not tested:
- On a phone: dash feel, the mark's readability.
- Balance against the Warden in full runs.
```

## 29. Fix: exported builds lost text lists (owner playtest, 2026-10-22)

```text
ASHENBOUND MILESTONE REPORT

Milestone: bug fix (owner's web playtest: "I can't open doors, enemies aren't
moving, XP is not coming up when I kill one of the test dummies")
Status: Validated, verified in runtime (web build in headless Chromium)

Cause:
- Godot 4.7.2's export-time conversion of text resources to binary wrote every
  PackedStringArray empty. Wave spawn markers were lost, so the Ossuary's
  enemies never spawned ("no spawn marker named ''"), the room could never be
  cleared and its exit stayed shut. Skill branch names and the Warden's
  hidden model parts were lost too. Desktop and the tests read the text files
  directly, so they never saw it. A plain binary save/load keeps the arrays;
  only the export converter drops them.
- XP from the training targets: by design they give none (they respawn
  forever); XP comes from the crypt's enemies.

Changes:
- project.godot: editor/export/convert_text_resources_to_binary=false (also
  fixes the Android export, which uses the same converter).
- tools/check_export.gd, run by tools/export-web.sh: fails the export when the
  markers, branch names or hidden parts come out empty.

Commands run:
- Command: godot --main-pack build/web/index.pck --script (probe)
  Result: before: markers=[], branches=[], hidden=[]; after: all present
- Command: tools/export-web.sh with the old setting, then the new one
  Exit code: 1 ("export check FAILED: …"), then 0
- Command: the web build in headless Chromium, walking north with the keyboard
  Result: before: three "no spawn marker" errors, an empty Ossuary; after:
  skeletons rise, chase and attack; no errors
- Command: tools/test.sh
  Exit code: 0; 245 passed

Not tested:
- The Android APK on a phone (same setting; no device).
```

## 30. The Hexbinder, third playable class (branch `feature/hexbinder`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: roster (charter 13.9 step 4: status effects, durations, area spells)
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- Hexbinder hero (KayKit Mage, CC0): Hex Bolt (player-side RangedAttack with
  aim assist), 80 health.
- BlackTestamentAbility (area curse, a "Cursed" Burning), GraspAbility with a
  new Slowed effect, UnmakeAbility (detonates curses for their remaining
  damage, Soul Siphon heal). Targeting.living_around(); Vfx.ring().
- Hexbinder tree playable; Main lists the class; docs/characters/hexbinder.md.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 252 passed, 0 failed (7 new in test_hexbinder.gd)
- Command: the Hexbinder in the crypt rendered under Xvfb
  Result: a curse ring on two skeletons (6 each), then Unmake: 21 each

Not tested:
- On a phone; balance against the other classes in full runs.
```

## 31. Visuals and a living UI (branch `feature/visual-ui`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: presentation (owner request 2026-10-22: "make the visuals 100x
better and let's start to put some life into the UI")
Status: Validated, verified in runtime (desktop software Vulkan, web smoke test); not verified on device

Changes:
- World: FlameFx fires on torches, braziers and pillar embers; dust motes;
  darker, warmer grade with stronger bloom; ScreenFx vignette, grain and
  low-health pulse; hero outlines; hit squash; livelier damage numbers.
- HUD: health trail and flash, smooth XP, room/boss/level banners, the
  hero's class name, coloured ability buttons with press and ready motion,
  sliding toasts, popping panels.
- Title screen (the new start scene): class cards, tier, purse, Enter the
  crypt; Leave the crypt in the pause menu. device-test.sh presses Enter
  first.
- docs/UI.md.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 259 passed, 0 failed (4 new in test_living_ui.gd, 3 in
  test_title_screen.gd; the XP bar test now waits for the fill)
- Command: tools/export-web.sh; tools/web/smoke.js
  Result: export check passed; web smoke test passed
- Command: crypt, HUD and title rendered under Xvfb
  Result: fires and embers, vignette, the Ossuary banner, the health trail
  after a hit, coloured buttons; the title screen (a long class name was
  clipped and fixed)

Not tested:
- On a phone: frame rate with the fires, dust and frame; readability.
```

## 32. Champions and health potions (branch `feature/champions`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: gameplay loop (owner request 2026-10-22: "keep building more of
the gameplay")
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- Champions (docs/CHAMPIONS.md): encounters raise ordinary enemies as
  champions at the tier's chance (10% at tier 1, up to 35%), with 1 to 3
  affixes:
  - Hasted, Stoneskin, Vampiric;
  - Ember-wreathed: an aura;
  - Vengeful: a telegraphed eruption on death.
  Champions have 2.5× health and 1.2× damage, are worth 4× XP and gold and
  3× Ash, always drop a Rare or better, and carry a name, a bar, a ring and
  a glow. A toast announces them, and killing one shakes the camera.
- Health potions: three per run on F / 4 or the POTION button. Each heals
  35% with a 1 s cooldown. Six kills, or a champion, elite or boss kill,
  refill one. The button shows the charge count.
- Elites and bosses are marked `champion_eligible = false`; EliteBar takes
  a title colour.
- The test runner takes TEST_SUITES to run only some suites.
  `instantiate_main()` turns champions off, so tests of exact run rewards
  stay deterministic.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 275 passed, 0 failed (11 new in test_champions.gd, 5 in
  test_potions.gd)
- Probes: Stoneskin's reduction, the eruption's damage and the potion
  cooldown were each removed in turn; the matching test failed each time,
  then passed once the code was restored.
- Command: the crypt at tier 4 with every ordinary enemy a champion,
  rendered under Xvfb
  Result: the champion names, bars and rings read clearly; the Ember aura;
  a Vengeful kill's violet warning ring; the POTION button with its badge.

Not tested:
- On a phone: legibility of champion names, and reaching the POTION button
  with the thumb.
- Balance in full runs at higher tiers.
```

## 33. The Dreadhunter, fourth playable class (branch `feature/dreadhunter`)

```text
ASHENBOUND MILESTONE REPORT

Milestone: six-class roster (charter 13.4); owner request 2026-10-22: "keep
building more of the gameplay"
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

Changes:
- Dreadhunter hero (docs/characters/dreadhunter.md): the hooded Rogue with
  its two-handed crossbow, tinted forest green; 90 health; a crossbow
  basic attack (8 at 15 m).
- Deadfall (Trapper): a rune-snare that holds enemies for 2 s, then erupts
  for 6 × 4.
- Charged Shot (Precision): a 0.5 s draw, then a piercing line for 24,
  stopped by walls and cancelled by a dodge.
- Carrion Raven (Beastcraft): a primitive raven that dives every 0.8 s for
  6, for 8 s.
- The Dreadhunter tree is playable; every node acts. Node texts were
  adjusted to match.
- The title screen and Main list the class. Tests that used the Dreadhunter
  as the preview tree now use the Reliquary.

Commands run:
- Command: tools/test.sh
  Exit code: 0
  Result: 285 passed, 0 failed (11 new in test_dreadhunter.gd)
- Probes: I removed the eruption's damage, made the shot stop after its
  first target, and removed the raven's strike, one at a time. The matching
  test failed each time, then passed once the code was restored.
- Command: tools/export-web.sh; tools/web/smoke.js
  Result: export check passed; web smoke test passed
- Command: the crypt as the Dreadhunter, rendered under Xvfb
  Result: the snare ring under a skeleton; the shot's tracer and a 24; the
  raven circling the hero, made larger with a violet sheen after the first
  render showed it too dark.

Not tested:
- On a phone: thumb reach for SNARE, SHOT and RAVEN; the raven's
  readability.
- Balance against the other classes in full runs.
```

## 34. The Forgotten Catacombs, second dungeon (branch `feature/second-dungeon`)

```text
ASHENBOUND MILESTONE REPORT

Milestone / feature: second dungeon (owner request 2026-10-22: "keep going
with a second dungeon")
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

What changed:
- docs/dungeons/forgotten_catacombs.md: the spec.
- The Ghoul: a fast, frail claw enemy (18 HP, 4.8 m/s, 7 damage, 0.35 s
  windup), a recoloured, smaller Skeleton Warrior.
- The Hollow King: the AshenLord script with a three-bolt Soul Volley,
  Grave Spikes, a Soul Nova ring and four Ghoul adds; a 1.8× Skeleton Mage;
  700 HP.
- RangedAttack.volley fans projectiles across the arc; AttackTelegraph
  draws a sector for a volley. AshenLord.display_title names the boss bar.
- scenes/dungeon/catacombs.tscn, generated by tools/gen/catacombs.py:
  Stairwell, Gallery of Bones, Drowned Vault, Bone Pit and Hollow Throne,
  with cold soul-fire (new CryptRoom torch colours) and its own environment.
- Dungeons registry; Profile.dungeon (saved; older saves play the crypt);
  Main plays the chosen dungeon; a dungeon row on the title screen, where
  the catacombs open after a crypt clear.

Commands and tests:
- Command: tools/test.sh
  Exit code: 0
  Result: 292 passed, 0 failed (7 new in test_catacombs.gd)
- Command: the title screen, the Gallery and the Hollow Throne rendered
  under Xvfb
  Result: the dungeon row; cyan fires and teal fog; Ghouls; the Hollow
  King with his name on the boss bar and his volley's 40° telegraph.

Not tested:
- On a phone: readability of the darker palette; frame rate with the extra
  lights.
- Balance in full runs, per class and tier.

Recommended next task:
- The Reliquary and the Gravecaller, so all six classes are playable.
```

## 35. The Reliquary and the Gravecaller: the full roster (branch `feature/full-roster`)

```text
ASHENBOUND MILESTONE REPORT

Milestone / feature: six-class roster (charter v2.0 §5.5, §5.6); owner request
2026-10-22: "a fully playable test version of the game with mechanics we
talked about by today"
Status: Validated, verified in runtime (desktop software Vulkan); not verified on device

What changed:
- Reliquary (docs/characters/reliquary.md):
  - the Knight with a sword and shield, 110 health, a 9-damage flail;
  - Last Benediction: a capped heal plus damage;
  - Hallowed Lantern: a pulsing zone;
  - Martyr's Judgment: a health-cost smite. It is refused at 20% health or
    less and never takes the last point;
  - MartyrZeal: below half health, more damage (MeleeAttack.bonus_scale).
- Gravecaller (docs/characters/gravecaller.md):
  - the Mage with book and wand, 85 health, a soul bolt;
  - Raise the Forsaken: Minion skeletons with a defined count, lifetime,
    targets, collision and cleanup;
  - Wraith Swarm: hits plus Marked;
  - Soul Harvest: souls from nearby deaths, shown as a badge on the HUD
    button (Ability.badge_text, TouchActionButton.badge_source).
- Both trees are playable, and every node acts. Phantom Swarm now uses
  `wraith_count`, so it no longer shares Mass Grave's key.
- All six classes can be chosen on the title screen. Tests that relied on a
  preview tree now build a non-playable tree themselves.

Commands and tests:
- Command: tools/test.sh
  Exit code: 0
  Result: 308 passed, 0 failed (7 new in test_reliquary.gd, 9 in
  test_gravecaller.gd)
- Probes: I removed Judgment's health floor and last-point rule, the
  minions' lifetime, and the soul gathering, one at a time. The matching
  tests failed each time, then passed once the code was restored.
- Command: both classes rendered in the crypt under Xvfb
  Result:
  - Reliquary: the lantern's ring, Judgment's 28, and health 99/110 after
    the cost;
  - Gravecaller: teal skeletons fighting, wraith hits of 9 with marks, and
    the HARVEST badge.

Not tested:
- On a phone: the readability of minions against enemies, and the frame
  rate with summons out.
- Balance across the six classes in full runs.
```

## 36. Art style test: Look A against Look B (branch `feature/style-lab`)

```text
ASHENBOUND MILESTONE REPORT

Milestone / feature: art direction (owner, 2026-10-23: "too basic... too
cartoony", two directions; the owner chose "show me both first")
Status: Validated, verified in runtime (desktop software Vulkan; web build in Chromium); not verified on device

What changed:
- ArtStyle: Classic (the default), Look A and Look B, saved as
  GameSettings.art_style and chosen on the title screen.
- Look A: cel-shaded characters (toon_character.gdshader) with an ink
  outline. RealFx: spark streaks, glare, impact light, smoke, bone or blood,
  blood pools, white-hot swings. A flinch on being hit.
- Look B: worn, real surfaces for characters and the dungeon
  (grim_surface.gdshader, which also keeps the wall cutout), and a grimmer
  grade. ToonFx: comic stars, inked blobs, puffs, solid inked swings. A big
  squash on being hit.
- Both: HitStop on landed blows and big kills; CharacterAnimator lunges the
  model through each attack. All of it is presentation; numbers are
  unchanged.
- docs/ART_STYLE_TEST.md with side-by-side images; CURRENT_STATUS, UI,
  ART_DIRECTION.

Commands and tests:
- Command: tools/test.sh
  Exit code: 0
  Result: 314 passed, 0 failed (6 new in test_art_style.gd; the dungeon-row
  test now finds the dungeons by name)
- Command: the same blow and kill rendered in all three looks, plus both
  effect sets close up, under Xvfb
  Result: the images in docs/images/style_test_*.jpg
- Command: web exports with each look as the default, played into the crypt
  in Chromium
  Result: both render, with no shader errors in the console

Not tested:
- On a phone: frame rate and readability of either look.

Known limits:
- No new animation clips: realistic attack animations need mocap or an
  animator.
- Look B cannot make the cartoon-proportioned models realistic: it needs
  realistic rigged character assets.
```

## 37. Sound and music (branch `feature/audio`)

```text
ASHENBOUND MILESTONE REPORT

Milestone / feature: sound and music (owner, 2026-10-23: "I opened up
network access. Go wild.")
Status: Validated, verified in runtime (headless mix recorded and measured;
web build in Chromium); not listened to by a person; not verified on device

What changed:
- About 250 CC0 sound files from 29 packs (Kenney, OpenGameArt), cut,
  normalised and encoded by tools/audio/import_audio.py from the original
  downloads; sources in docs/AUDIO.md and packs.json.
- Audio autoload: cues, buses (Master with a limiter; Sfx: World with
  reverb, Ui, Ambience; Music), 16 pooled positional voices, crossfading
  music, ducking while paused, per-cue gaps and pitch variation.
- CharacterSounds on every hero, enemy and summon; sounds named in the data
  (AttackData windup and swing, Ability.sound, Projectile.impact_sound),
  written by tools/audio/assign_sounds.py.
- SoundDirector: music per dungeon, combat and boss tracks, tolls, gates,
  loot by rarity, potions, champions, level-ups.
- Pause menu: Music and Effects sliders (GameSettings, saved).
- Camera rig: an AudioListener3D at the hero.

Commands and tests:
- Command: tools/test.sh
  Exit code: 0
  Result: 325 passed, 0 failed (11 new in test_audio.gd)
- Command: probes (a misspelt cue; the combat music removed)
  Result: the matching tests failed, then passed once restored
- Command: a scripted 47 s Warden fight in the crypt, recorded from the
  master bus (AudioEffectRecord), measured with ffmpeg ebur128
  Result: -15.6 LUFS integrated, 8.8 LU range, sample peak -0.3 dBFS
- Command: tools/export-web.sh; tools/web/smoke.js; a play-through in
  Chromium
  Result: export check passed, smoke test passed, no console errors

Not tested:
- By ear: no person has listened yet.
- On a phone: the cost of the voices and the reverb, and the mix on a
  phone speaker.

Known limits:
- Web: sound starts after the first tap, and the reverb does not apply.
- Library music, not scored; no voice lines.
```

## 38. Effect sprites and photographed stone (branch `feature/vfx-pack`)

```text
ASHENBOUND MILESTONE REPORT

Milestone / feature: free resource packs, effects and surfaces (owner,
2026-10-23: "Go wild")
Status: Validated, verified in runtime (desktop software Vulkan); not
verified on device

What changed:
- Kenney Particle Pack (CC0) packed into six atlases by
  tools/art/make_particle_atlases.py.
- Vfx: sparks are now soft glints; new smoke, debris, flames and scorch
  decals; rings are a real shockwave texture. The calls are unchanged, so
  every ability and hit uses them.
- Classic deaths raise dust and bone chips; Vengeful blasts burn, smoke
  and scorch the floor; Judgment, Deadfall, Grasp, raised and crumbling
  skeletons, curses and soul spells add smoke or debris; burns lick fire
  on each tick; torches have real fire tongues and a smoke wisp; look A's
  smoke uses the real puffs.
- Look B: photographed stone (Poly Haven, CC0; tools/art/fetch_polyhaven.py)
  on floors and walls by world position, keeping the palette's colour.
- Fix: look B now dresses the tiled floors and walls (MultiMeshes), which
  it had been skipping.

Commands and tests:
- Command: tools/test.sh
  Exit code: 0
  Result: 317 passed, 0 failed (3 new: sprites and their cleanup, torches,
  and look B's tiles)
- Command: probe (tile dressing switched off)
  Result: the new test failed, then passed once restored
- Command: close-up and wide renders under Xvfb (torch, death, blast,
  look B's crypt)
  Result: as intended after two passes of tuning (denser death smoke,
  larger blast flames, each photograph normalised by its own brightness)

Not tested:
- On a phone: the cost of the extra particles and of look B's triplanar
  stone (nine texture reads per pixel).
```

## 39. Motion-captured animation for looks A and B (branch `feature/mocap`)

```text
ASHENBOUND MILESTONE REPORT

Milestone / feature: realistic attack animations (owner, 2026-10-23), from
free packs ("Go wild")
Status: Validated, verified in runtime (desktop software Vulkan); not
verified on device

What changed:
- Quaternius's Universal Animation Library 1 and 2, Standard (CC0),
  downloaded by tools/anim/fetch_ual.py.
- tools/anim/retarget_ual.gd: world-space rotation retarget onto the KayKit
  rig; 28 clips saved as game/assets/third_party/quaternius/mocap.res.
- CharacterAnimator: mocap_attacks, mocap_abilities, mocap_idle, mocap_run,
  mocap_hit and mocap_death, used in looks A and B; "A|B" alternates as a
  combo. Set on 13 scenes by tools/anim/assign_mocap.py.
- docs/ANIMATION.md; ART_STYLE_TEST, ART_ASSET_PIPELINE, CURRENT_STATUS.

Commands and tests:
- Command: tools/test.sh
  Exit code: 0
  Result: 334 passed, 0 failed with #40 and #41 merged in (6 new in test_mocap.gd)
- Command: probe (combo frozen)
  Result: the combo test failed, then passed once restored
- Command: the Warden posed through four clips, and a look A fight strip,
  under Xvfb
  Result: clean swings, no broken limbs; enemies swing their mocap combos

Not tested:
- On a phone.

Known limits:
- Chibi proportions under realistic motion: up close a hand can pass
  through the big head.
- No crossbow or two-handed greatsword clips in the free editions.
```

## 40. Look B as the default, made fast enough for phones; the preview follows main (branch `feature/look-b-perf`)

```text
ASHENBOUND MILESTONE REPORT

Milestone / feature: the owner chose look B but found it "extremely poor
performance"; the preview had not been published since 2026-10-22 ("Yes
have the preview always reflect all changes")
Status: Validated, verified in runtime (desktop software Vulkan; Chromium
emulating a phone); not verified on device

What changed:
- grim_surface.gdshader: baked noise texture instead of per-pixel noise;
  stone read along the dominant axis only (from nine reads to three).
- The stone photos and the noise: mipmaps and GPU compression; the web
  export carries ETC2 for phones.
- Settings: on phones the 3D scene renders at most 810 pixels tall.
- Look B is the default look; tests pin the classic look unless they pick
  one.
- web-preview.yml: every push to main publishes to GitHub Pages.

Commands and tests:
- Command: tools/test.sh
  Exit code: 0
  Result: 335 passed, 0 failed (1 new: the phone 3D cap)
- Command: frame-time benchmark, crypt opening view, software Vulkan
  Result: classic 138 ms; look B 222 ms before, 155 ms after
- Command: Chromium emulating a phone (DPR 3, Android user agent)
  Result: canvas 2400x1080; about 40% more frames per second with the cap

Not tested:
- On the owner's phone, where it was too slow.
```

## 41. Fog and phone shadows cut (branch `feature/perf-cuts`)

The owner still found look B laggy on their phone and asked to cut the
shadows and the fog.
- Fog is off in every environment resource, and look B no longer thickens it.
- On phones, `RendererLighting` turns off the moonlight's shadows. It was the
  only shadow-casting light; the torches never cast shadows.
- Torch lights and flames stay.

Checks:
- `tools/test.sh`: 335 passed, 0 failed.
- Web export, then Chromium emulating a phone (800 × 360 at 3× density, software
  WebGL), two runs each: main 1.2 frames a second, this branch 1.3–1.4.
  Software rendering only; not measured on a real phone.
