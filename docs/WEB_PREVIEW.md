# Web preview

A browser build of the game, for playtesting the **feel** on any phone with
nothing to install: open a link, turn the phone sideways, play. It exists
because the emulator in CI cannot draw the game (see
[DEVICE_TESTING.md](DEVICE_TESTING.md#without-a-phone-the-ci-emulator)) and a
real phone is not always free to take an APK.

**It is a preview, not the product.** The game ships on Android with the
Mobile (Vulkan) renderer. The browser runs the Compatibility (WebGL 2)
renderer, so lighting and effects can look different, and a phone browser is
slower than a native app. Judge controls, layout, readability and game feel
here; judge visuals and frame rate on an Android build.

## Play it

1. Open the link (see [Publishing](#publishing)).
2. Hold the phone sideways. In portrait, a hint asks you to turn it.
3. Tap **Fullscreen** at the top for a bigger view. On Android Chrome this also
   locks the screen to landscape. On iPhone, use **Share > Add to Home Screen**
   instead, because Safari has no page fullscreen.

The first load downloads about 10 MB, then runs from the cache.

## What was checked

- **Runs in a browser:** exported with Godot 4.7.2, loaded in headless Chromium
  with software WebGL 2 on a 844×390 touch screen. The arena, enemies and every
  HUD button render, a touch drag on the stick moves the Warden, and a hit
  lands on an enemy. This is verified in runtime, **not** on a physical phone.
- **Rotate hint:** shows in portrait and not in landscape.
- **Smoke test:** `tools/web/smoke.js` boots the build and fails if the engine
  does not start, the page raises an error or the screenshot is blank. It was
  checked to fail on a build with a corrupted data file. CI runs it on every
  change.

## Not checked

- Frame rate and touch latency on a real phone browser.
- Two fingers at once (stick plus a button) in a browser.
- Audio (the game has none yet).
- The Fullscreen button and orientation lock on a real phone.
- iPhone Safari.

## Build it yourself

Needs Godot 4.7.2 with the **web export templates** installed (Editor > Manage
Export Templates), then:

```bash
tools/export-web.sh                    # writes build/web/
cd build/web && python3 -m http.server 8000
```

Open <http://localhost:8000/>. A phone on the same network can open
`http://<your-computer's-IP>:8000/`. Check the page with
`node tools/web/smoke.js build/web` (needs the `playwright` npm package).

The export uses the **Web preview** preset: release template, single-threaded.
Single-threaded needs no special server headers, so any static host works.
`tools/export-web.sh` also adds the rotate hint and Fullscreen button
(`tools/web/preview_overlay.html`).

## Known export pitfall

Exported builds used to lose every list of text (`PackedStringArray`) in the
game data: in the crypt no enemy rose, so no room could be cleared and its
doors stayed shut. The cause and the guard are in
[BUILD_ANDROID.md](BUILD_ANDROID.md#troubleshooting).

## Publishing

CI builds the preview on every run and uploads it as the **ashenbound-web**
artifact. **Every push to `main` (every merge) also publishes it** to GitHub
Pages, so the preview always matches `main`; the owner asked for this on
2026-10-23, after the preview had sat a day behind. Until then publishing was
manual, and it still can be, to preview another branch:

1. **Once:** in the repository, **Settings > Pages**, set **Source** to **Deploy
   from a branch**, branch **gh-pages**, folder **/ (root)**.
2. **Another branch:** **Actions > Web preview > Run workflow**, pick the
   branch, tick **publish**. The next merge to `main` replaces it again.
3. A minute after the build, the game is at
   `https://<owner>.github.io/<repository>/` (here
   <https://bessv2.github.io/Ashenbound/>). Reload fully to drop the old
   copy.

The publish step replaces the whole `gh-pages` branch with the new build, so
there is one preview at a time. The repository is public, so the preview is
public too; unlisted, but anyone with the link can play it.
