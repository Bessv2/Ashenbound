# Device testing

How to test ASHENBOUND on a physical Android phone with Claude Code running on
your own computer. Claude installs the game, plays a scripted session through
`adb`, collects screenshots, logs and frame statistics, and reports. You
handle what a script cannot judge: how it feels in the hand.

This is what moves milestones from **verified in runtime** to **verified on
device** (charter section 7).

## Without a phone: the CI emulator

Every CI run also plays the same script on an Android emulator (x86_64, API 34)
inside GitHub Actions, using `tools/device-test.sh` with `ALLOW_EMULATOR=1` and
an x86_64 build of the game (the preset **Android x86_64 (CI emulator)**). The
screenshots, `summary.md`, `errors.txt` and `logcat.txt` are uploaded as the
**emulator-device-test** artifact on the run.

It catches crashes, a game that will not start, and controls that miss their
buttons. It cannot tell you anything about **feel** or **frame rate**: an
emulator runs on a desktop CPU with software graphics. Those still need a real
phone, yours or a spare. The emulator step is experimental and is allowed to
fail without failing the run, so check its summary in the job log.

To run the same thing locally against an emulator you started yourself:

```bash
PRESET="Android x86_64 (CI emulator)" APK="$PWD/build/android/ashenbound-debug-x86_64.apk" \
  tools/export-android-debug.sh
ALLOW_EMULATOR=1 tools/device-test.sh build/android/ashenbound-debug-x86_64.apk
```

## One-time setup (owner)

1. **Phone:**
   1. Open **Settings > About phone** and tap **Build number** seven times to
      unlock **Developer options**.
   2. In **Developer options**, turn on **USB debugging**.
   3. The phone must be 64-bit (arm64) with Android 7.0 or newer.
2. **Computer:**
   - Install **Android platform-tools**, which provide `adb`:
     <https://developer.android.com/tools/releases/platform-tools>. Unzip it
     and add the folder to your `PATH`.
   - Alternatively, use a package manager: `brew install android-platform-tools`
     on macOS, or `sudo apt install adb` on Debian and Ubuntu.
   - On Windows, also install **Git for Windows**, which includes Git Bash:
     the device-test script is a bash script.
3. **Connect:**
   1. Plug the phone in over USB.
   2. Accept the **Allow USB debugging** prompt on the phone.
   3. Run `adb devices` and check that the phone is listed as `device`, not
      `unauthorized`.
4. **Repository:**

   ```bash
   git clone https://github.com/Bessv2/Ashenbound.git
   cd Ashenbound
   git checkout feature/device-testing
   ```

5. **Claude Code:** install the desktop app or the CLI (see
   <https://code.claude.com/docs>), open it in the `Ashenbound` folder, and
   say: *"Run the device test in docs/DEVICE_TESTING.md."*

You do **not** need Godot, a JDK or the Android SDK to test: use a prebuilt
APK. They are only needed to rebuild the game on your computer (see
[BUILD_ANDROID.md](BUILD_ANDROID.md)).

## Getting an APK

Either of these works:

- **The demo APK sent in the chat:** save it as
  `build/android/ashenbound-debug.apk`, or pass its path to the script.
- **CI:** download **ashenbound-debug.apk** from the latest green run of
  this branch, under the repository's **Actions** tab.

Builds from different machines are signed with different debug keys. If
installing fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, run
`adb uninstall com.ashenbound.game` first.

## Procedure (for the Claude Code session)

### 1. Automated run

```bash
tools/device-test.sh [path/to/ashenbound-debug.apk]
```

The script does the following:

1. Checks that the phone is authorized and runs arm64 apps.
2. Records the model, Android version, screen size and refresh rate.
3. Installs and launches the game.
4. Plays a scripted session:
   1. moves with the stick;
   2. attacks;
   3. uses DODGE, CLEAVE, GUARD and BRAND;
   4. pauses with the **II** button and resumes with Back;
   5. sends the app to the background with Home and returns;
   6. walks a square for about 40 s while attacking.
5. Writes `build/device-test/<timestamp>/`:

   | File | Contents |
   |---|---|
   | `summary.md` | Device, whether it crashed, frame statistics, error count |
   | `01-start.png` … `11-end.png` | One screenshot per step |
   | `perf.txt` | The game's `PERF` lines: average FPS, slowest frame, draw calls, nodes and memory for each 5 s interval |
   | `errors.txt` | Godot errors, script errors and crashes from the log |
   | `steps.txt` | What was done when |
   | `logcat.txt` | The full device log |

The exit code is non-zero only if the game crashed or did not start.

### 2. Check the screenshots

Look at each screenshot and answer:

| Screenshot | What to check |
|---|---|
| `01-start` | Landscape and fullscreen. Nothing is hidden by a camera cutout. All five round buttons and the **II** button are fully on screen. |
| `02-moved` | The Warden has moved up the screen from the start. |
| `04-dodge`, `05-cleave`, `06-guard`, `07-brand` | Each tapped button shows its dark cooldown sweep. `06-guard` shows the ember ring at the Warden's feet. |
| `08-paused` | The pause menu is open. |
| `09-resumed` | The pause menu is closed. |
| `10-after-home` | The game came back **paused**. Leaving the app must pause it. |
| `11-end` | The game is still running. |

**If a tap missed its button:** the phone probably has a camera cutout that
insets the HUD. Measure the inset in `01-start.png` (the gap between the
screen edge and the HUD), then rerun with `SAFE_LEFT=<px>` and/or
`SAFE_RIGHT=<px>`.

### 3. Hand checks (owner)

`adb` taps use a single finger, and a script cannot judge feel. Ask the owner
to play for about 5 minutes and answer these:

1. Can the right thumb reach ATTACK, DODGE, CLEAVE, GUARD and BRAND without
   hitting the wrong one?
2. Does the stick respond immediately and stop the moment the finger lifts?
   Does a second finger elsewhere leave it undisturbed?
3. Can you hold the stick and ATTACK at the same time? (A script cannot test
   two fingers.)
4. Can you read the Hollows, their red warnings, the damage numbers and the
   HUD at arm's length?
5. Does anything feel late or sluggish: attacks, dodges, abilities?

### 4. Record the results

Update these files:

- **[CURRENT_STATUS.md](CURRENT_STATUS.md):**
  - mark Milestone 1 and the Milestone 2 device check as **verified on
    device**, naming the phone, or list what failed;
  - add the measured FPS.
- **[IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md):** a new section in
  the charter's milestone report format, with the commands run, their exit
  codes, `summary.md`'s numbers, the hand-check answers, and any problems
  found.
- **Each problem found:** fix it in a focused change, or list it under Known
  risks.

Do **not** commit anything under `build/`, which is ignored. Copy a
screenshot into `docs/images/` only when it documents something.

## How to read the frame statistics

PerfLog runs only in debug builds, so `PERF` lines appear only when testing a
debug APK. A debug build is somewhat slower than a release build, so treat
the numbers as a lower bound.

- **`fps`:** frames per 5 s interval. The charter's target is 60 on a
  representative mid-range phone. Phones with 90 or 120 Hz screens may report
  more.
- **`worst_ms`:** the slowest single frame in the interval. Values regularly
  above 33 ms are visible stutters.
- **`draw_calls`:** draw calls in the last frame. A software-rendered desktop
  run shows about 106 for the arena with Hollows. Much higher on the phone
  would point at rendering cost.
- **`static_mb`:** static memory. If it keeps rising across intervals during
  the soak, that suggests a leak worth investigating.
