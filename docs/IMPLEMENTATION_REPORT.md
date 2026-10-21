# Implementation report: Task 1, Android project foundation

**Date:** 2026-10-21 · **Branch:** `ccr-f0dcdd15-eok91q`

## Outcome

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
  `scenes/player/player.tscn`, `scenes/camera/isometric_camera_rig.tscn`
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
| 4 | `godot --headless --path game --fixed-fps 60 --script res://tests/run_tests.gd` (via `tools/test.sh`) | 0 | **38 passed, 0 failed** on each of 4 runs, the last from a clean `.godot/` |
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

## 4. Known issues and limitations

1. **Not validated on Android hardware.** Touch was tested with synthetic
   events through the engine's input pipeline. Rendering was tested with
   software Vulkan on Linux, not on a phone GPU. Performance on devices is
   unmeasured.
2. **Container toolchain differs from the recommended one.** The editor binary
   is nixpkgs' build of the 4.7.2-stable source rather than the official
   binary; the export templates are official. Signing used apksigner 31.0.2
   instead of build-tools 36.1.0.
3. **The debug key is per machine.** An APK from another machine's debug key
   cannot be installed over this one without `adb uninstall` first.
4. **No display-cutout (safe area) handling yet.** HUD elements sit 24–32 px
   from the edges and could be partly covered on phones with a cutout in
   landscape.
5. **Keyboard and joystick on the same action.** If both press the same action
   and the stick is released, the action is released for both. This is an
   engine-level limitation of `Input.action_release()`, and it only matters on
   desktops with a touchscreen.
6. **One-time editor diff.** Hand-written scenes have no `unique_id` node
   attributes. The editor adds them the first time each scene is saved; commit
   that diff on its own.
7. `com.ashenbound.game` is a placeholder package name.

## 5. Next steps

1. Install the APK on a physical phone, work through the
   [manual checklist](BUILD_ANDROID.md#manual-device-checklist), and record the
   device model, GPU and FPS.
2. Add CI (GitHub Actions) that runs `tools/test.sh` and the debug export on
   every pull request.
3. Make the HUD safe-area aware (`DisplayServer.get_display_safe_area()`).
4. Settle the application ID, create an upload keystore outside the repository,
   and switch to a Gradle build for AAB when Play distribution is needed.
5. Once device validation passes, start the combat prototype. Combat, loot,
   inventory, authentication and backend work were intentionally not started.
