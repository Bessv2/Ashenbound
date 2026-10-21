# Building for Android

This guide covers the one-time toolchain setup, exporting a debug APK, and
installing it on a phone.

## Toolchain

These versions work together. They match what Godot 4.7.2 itself builds against
(`platform/android/java/app/config.gradle` at the `4.7.2-stable` tag).

| Component | Version | Notes |
|---|---|---|
| Godot editor | 4.7.2-stable, standard build | |
| Export templates | 4.7.2-stable | Must match the editor version exactly |
| JDK | OpenJDK 17 | Godot's Android toolchain targets Java 17 |
| Android SDK platform-tools | latest | Provides `adb` |
| Android SDK build-tools | 36.1.0 | Provides `apksigner`; Godot prefers build-tools matching the target SDK |
| Android SDK platform | android-36 | Only needed for Gradle builds (not used yet) |
| Min / target SDK | 24 / 36 | Godot 4.7 defaults, left unchanged in the preset |

The project uses Godot's **prebuilt APK template** (no Gradle build), so the
Android NDK, CMake and Android Studio are **not** required.

## 1. Install JDK 17

- **Linux (Debian/Ubuntu):** `sudo apt install openjdk-17-jdk-headless`
- **Windows / macOS:** install Eclipse Temurin 17 (<https://adoptium.net/>).

Check that it works with `java -version`, which should report version 17.

## 2. Install the Android SDK

Use either Android Studio's SDK Manager or the standalone command-line tools
(<https://developer.android.com/studio#command-line-tools-only>):

```bash
sdkmanager --sdk_root="$ANDROID_HOME" --licenses
sdkmanager --sdk_root="$ANDROID_HOME" "platform-tools" "build-tools;36.1.0" "platforms;android-36"
```

Typical SDK locations are `~/Android/Sdk` on Linux,
`%LOCALAPPDATA%\Android\Sdk` on Windows, and `~/Library/Android/sdk` on macOS.

## 3. Point Godot at the JDK and SDK

In the editor, open **Editor > Editor Settings > Export > Android** and set:

- **Java SDK Path**: the JDK 17 home, e.g. `/usr/lib/jvm/java-17-openjdk-amd64`
- **Android SDK Path**: the SDK root, the folder that contains `platform-tools/`

Alternatively, set `JAVA_HOME` and `ANDROID_HOME` **before the editor runs for
the first time**. Godot uses them as the defaults when it creates its editor
settings. The settings file is `editor_settings-4.7.tres` in
`~/.config/godot/` (Linux), `%APPDATA%\Godot\` (Windows) or
`~/Library/Application Support/Godot/` (macOS).

These are per-machine settings. They are not stored in the repository.

## 4. Debug keystore

Debug APKs must be signed. When the Java SDK path is valid, the editor creates a
debug keystore automatically (`~/.local/share/godot/keystores/debug.keystore` on
Linux) and records it in the editor settings. No action is needed in most
cases.

To create one manually:

```bash
keytool -genkeypair -v -keystore debug.keystore -storepass android \
  -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
  -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

Then set **Debug Keystore** under Editor Settings > Export > Android. For CI,
use environment variables instead of editor settings:
`GODOT_ANDROID_KEYSTORE_DEBUG_PATH`, `GODOT_ANDROID_KEYSTORE_DEBUG_USER`,
`GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD`.

Keystores (`*.keystore`, `*.jks`) are git-ignored. Never commit one.

## 5. Export the debug APK

From the command line:

```bash
tools/export-android-debug.sh
```

This is equivalent to:

```bash
godot --headless --path game --import
godot --headless --path game --export-debug "Android" ../build/android/ashenbound-debug.apk
apksigner verify --verbose build/android/ashenbound-debug.apk
```

The output path in the `--export-debug` command is relative to `game/`. To
export from the editor instead, use **Project > Export > Android > Export
Project** with **Export With Debug** checked.

Godot exits with a non-zero status and prints the reason when the configuration
is incomplete, for example `Invalid Android SDK path in Editor Settings` or a
missing template.

### What the `Android` preset sets (`game/export_presets.cfg`)

| Option | Value | Why |
|---|---|---|
| Gradle build | off | The prebuilt template needs no NDK or Gradle |
| Architectures | arm64-v8a only | Covers current Android phones; keeps the APK smaller |
| Package name | `com.ashenbound.game` | Placeholder; change it before publishing |
| Version | 0.1.0 (code 1) | |
| Immersive mode | on | Fullscreen, no system bars |
| Exclude filter | `tests/*` | Test code is not shipped |

Orientation comes from `display/window/handheld/orientation` in
`project.godot`. It is set to *sensor landscape*, which Godot writes to the
manifest as `userLandscape`: either landscape direction, respecting the user's
rotation lock.

### Or download the APK from CI

Every pull request and every push to `main` builds the same debug APK on GitHub
Actions (see `.github/workflows/ci.yml`). Open the run under the repository's
**Actions** tab and download **ashenbound-debug.apk** from its **Artifacts**
section. Artifacts are kept for 14 days. CI signs with a fresh debug key each
time, so uninstall the previous build before installing one from a different
run or machine.

## 6. Install and run on a phone

1. On the phone, enable **Developer options** and **USB debugging**, connect it
   by USB, and accept the debugging prompt.
2. Check that it is visible, install, and launch:

   ```bash
   adb devices
   adb install -r build/android/ashenbound-debug.apk
   adb shell monkey -p com.ashenbound.game -c android.intent.category.LAUNCHER 1
   ```

3. Read the game's log output with `adb logcat -s godot`.

With a device connected, the editor's one-click deploy (the Android button next
to the run buttons in the top-right corner) exports, installs and launches in one
step.

### Manual device checklist

- [ ] The game starts in landscape and fullscreen. With rotation lock off,
      turning the phone 180° flips the image.
- [ ] Dragging in the lower-left area moves the player; releasing stops it
      immediately.
- [ ] Up on the stick moves the player up the screen; the camera never rotates.
- [ ] A second finger placed elsewhere does not disturb the stick.
- [ ] The player cannot leave the arena or pass through the pillars.
- [ ] The **II** button pauses; **Resume** continues; the player is not moving
      after resume.
- [ ] Android Back pauses and resumes; it does not quit.
- [ ] Holding the stick, switching apps and coming back: the game is paused
      and the stick is released.
- [ ] The debug label in the top-left corner shows FPS (debug builds only).
- [ ] On a phone with a camera cutout, the HUD stays clear of it.
- [ ] Holding **ATTACK** next to a training dummy swings repeatedly; the dummy
      flashes, shows "10" and its health label drops; after 5 hits it
      disappears and respawns about 2.5 s later.
- [ ] Moving with the stick and holding **ATTACK** at the same time works; the
      player slows down while attacking.
- [ ] Pausing while holding **ATTACK** stops the attacks; after **Resume** the
      player does not keep attacking.
- [ ] Walking toward a Hollow (about 15 m from the start, in any direction)
      makes it chase you. Before it strikes, a red sector appears on the ground;
      stepping out of it in time avoids the hit.
- [ ] Tapping **DODGE** dashes the player a few meters toward the stick (or
      forward when the stick is idle). The button darkens and refills over
      about a second, and tapping it again before then does nothing.
- [ ] Dodging just before a Hollow's hit lands avoids it: no damage number
      appears and the health bar does not drop.
- [ ] **CLEAVE** sweeps the greatsword and hits every Hollow in front and to
      the sides (each shows 25); its button darkens for 4 s.
- [ ] **GUARD** shows an ember ring and the Warden stops moving. A Hollow's
      hit during it shows 2 instead of 12, and the Hollow takes 15 back.
- [ ] **BRAND** with a Hollow or dummy within about 7 m shows small ember
      damage numbers (4) every half second. With nothing nearby, the button
      does nothing and does not darken.
- [ ] The five buttons around **ATTACK** are easy to hit with a thumb and do
      not cover anything important.
- [ ] Standing with a pillar between you and a chasing Hollow: it walks around
      the pillar instead of pushing into it.
- [ ] Three hits kill a Hollow; it sinks into the floor and another appears
      a few seconds later at a spawn point away from you.
- [ ] The health bar drops when you are hit. At zero the player falls,
      "You have fallen" appears, and **Rise again** restarts with full health.

## Troubleshooting

- **"Could not find version of build tools that matches Target SDK, using
  …"**: an informational message. Godot found no `build-tools/36.*` and is using
  another installed version to sign. Install build-tools 36.1.0 to silence it.
- **Template errors**: the export templates must be exactly 4.7.2.stable. Check
  **Editor > Manage Export Templates**.
- **Black screen on old devices**: the project uses the Mobile renderer (Vulkan)
  and falls back to OpenGL ES 3 when Vulkan is unavailable
  (`rendering/rendering_device/fallback_to_opengl3`, which is on by default).
  Check `adb logcat -s godot` for the driver that was chosen.
- **`INSTALL_FAILED_UPDATE_INCOMPATIBLE`**: an APK with the same package name
  but a different signing key is installed. Uninstall it first with
  `adb uninstall com.ashenbound.game`.

## Release builds (not set up yet)

Google Play requires an Android App Bundle (AAB), which needs a Gradle build
(**Project > Install Android Build Template**, then enable *Use Gradle Build*)
plus the NDK and the android-36 platform. Release signing needs an upload
keystore kept outside the repository and passed with the
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` environment variables.

## Appendix: the toolchain used to validate this repository

The first debug APK was built in a sandboxed Linux container where Google's SDK
downloads (`dl.google.com`) and Godot's download sites were blocked. The
toolchain there was:

- Godot 4.7.2-stable editor and the official 4.7.2 export templates from the Nix
  binary cache (nixpkgs 26.05, `godot_4_7` and `godot_4_7-export-templates-bin`).
  The templates are the official release `.tpz`, fetched by Nix with a pinned
  hash.
- Ubuntu 24.04 packages: `openjdk-17-jdk-headless`, `adb`, `apksigner` and
  `zipalign`. These install `/usr/lib/android-sdk/` with `platform-tools/adb`
  and `build-tools/debian/apksigner` (apksigner 31.0.2), which is enough for
  Godot's non-Gradle export. Godot logs "using debian" for the build-tools.

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 ANDROID_HOME=/usr/lib/android-sdk
godot --headless --path game --import   # creates editor settings and the debug keystore
tools/export-android-debug.sh
```

This substitute is fine for debug builds. Use the official SDK components
listed above on development machines.
