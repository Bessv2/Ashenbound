# Architecture

This document covers the current foundation (scenes, input, movement, camera,
pause and settings) and the first combat slice. It will grow as systems are
added.

## Scene structure

```
Main (Node3D)                         scenes/main.tscn, scripts/main.gd
├── PauseController (Node)            scripts/core/pause_controller.gd  [process: always]
├── TestArena (Node3D)                scenes/arena/test_arena.tscn
│   ├── WorldEnvironment              resources/environment/arena_environment.tres
│   ├── Moonlight (DirectionalLight3D, shadows)
│   ├── Floor (StaticBody3D)          44×44 m, top at y = 0, procedural flagstone shader
│   ├── Walls/{North,West}Wall        3 m tall (far side from the camera)
│   ├── Walls/{South,East}Wall        1 m tall (camera side, so they never hide the player)
│   └── Pillars/Pillar{N,S,E,W}       obstacles with an ember light on top
├── Player (CharacterBody3D)          scenes/player/player.tscn, scripts/player/player_controller.gd
│   ├── CollisionShape3D              capsule, radius 0.4 m, height 1.8 m
│   ├── Visual (Node3D)               turned to face movement or the attack; holds the meshes
│   │   └── WeaponPivot/Blade         scripts/player/weapon_swing.gd, placeholder swing
│   └── MeleeAttack (Node)            scripts/combat/melee_attack.gd + resources/combat/player_basic_attack.tres
├── Enemies (Node3D)
│   └── TrainingDummy{East,North,West} scenes/enemies/training_dummy.tscn, 5 m from the start
│       ├── Health (Node)             scripts/combat/health.gd, 50 HP
│       ├── Visual, HealthLabel (Label3D)
│       └── CollisionShape3D          layer 3 "enemy"
├── CameraRig (Node3D)                scenes/camera/isometric_camera_rig.tscn
│   └── Camera3D                      orthographic, size 16 m
├── HUD (CanvasLayer)                 ui/hud/hud.tscn
│   └── Root
│       ├── TopBar: Title, DebugLabel (debug builds only), PauseButton
│       ├── TouchJoystick             ui/hud/touch_joystick.gd, lower-left 560×420 px zone
│       ├── AttackButton              ui/hud/touch_action_button.gd, lower-right, holds `attack`
│       └── ControlsHint              keyboard hint, hidden on mobile
└── PauseMenu (CanvasLayer)           ui/pause_menu/pause_menu.tscn  [process: when paused]
```

`Settings` (`scripts/core/settings_service.gd`) is the only autoload.

### Who talks to whom

- The UI only *emits requests*. `Hud.pause_requested` and
  `PauseMenu.resume_requested` are connected in `main.gd` to
  `PauseController.set_paused()`. The UI never pauses the tree itself.
- `PauseController.paused_changed` opens and closes the pause menu.
- Gameplay never references the HUD. The joystick and the player communicate
  only through InputMap actions (see below).
- `PlayerController.camera` and `IsometricCameraRig.target` are node references
  wired in `main.tscn`. `PlayerController.attack` and `WeaponSwing.attack` are
  wired in `player.tscn`.
- On mobile, the HUD root is inset by the display safe area
  (`Hud.safe_area_insets()`), so controls stay clear of camera cutouts.

## Input mappings

Gameplay goes through these InputMap actions, defined in `project.godot`:

| Action | Keyboard (physical keys) | Touch |
|---|---|---|
| `move_left` | A, Left arrow | joystick left (analog strength) |
| `move_right` | D, Right arrow | joystick right (analog strength) |
| `move_forward` | W, Up arrow | joystick up (analog strength) |
| `move_back` | S, Down arrow | joystick down (analog strength) |
| `attack` | J, Space | **ATTACK** button (held) |
| `toggle_pause` | Escape, P | — (HUD **II** button; Android Back) |

`GameplayActions.ALL` lists the gameplay actions (movement and attack). They
are the ones released when the game pauses.

Keys are bound by **physical** position, so WASD stays in the same place on
AZERTY and other layouts.

Mouse-to-touch emulation (`input_devices/pointing/emulate_touch_from_mouse`) is
on, so the touch joystick can be tested on desktop with the mouse.

### Input flow

```
Keyboard ──► InputMap actions ◄── TouchJoystick (Input.action_press with strength)
                    │
          MovementInput.get_vector()        screen-space intent, length ≤ 1
                    │
          MovementInput.to_world_direction(intent, camera basis)
                    │
          PlayerController (_physics_process) ──► move_and_slide()
```

- `MovementInput.get_vector()` reads the actions with no additional dead zone.
  Keys are digital, and the joystick applies its own dead zone. The result is
  length-limited, so diagonal keys are normalized and analog input keeps its
  magnitude.
- `to_world_direction()` projects the camera's right and forward vectors onto
  the ground plane. Up on the stick always means "away from the camera",
  whatever the pitch.
- `TouchJoystick` handles multitouch through Godot's GUI touch routing. The
  first finger inside its zone owns the stick, and other fingers are ignored. It
  **releases only the actions it pressed itself**, because
  `Input.action_release()` clears an action for every device and would
  otherwise cancel a held key.

### Why not Godot's built-in `VirtualJoystick`

Godot 4.7 added a native `VirtualJoystick` control. It was evaluated and not
used, for two reasons:

1. It has no reset API. If the finger is lifted while the game is paused or
   backgrounded, the release never reaches the (paused) control, and the stick
   stays captured.
2. It releases any pressed movement action, which cancels keys held at the same
   time.

Revisit this when those are addressed upstream.

`TouchActionButton` (the **ATTACK** button) follows the same rules: one finger
by touch index, a round hit area, it releases the action only if it pressed it,
and it resets on pause, focus loss and when hidden.

## Movement

`PlayerController` (`CharacterBody3D`):

- Runs in `_physics_process`, using `delta` for everything, so speed does not
  depend on frame rate. Physics runs at 60 Hz; the test suite checks that the
  distance covered at 30, 60 and 120 Hz agrees within 2%.
- Acceleration and deceleration use `move_toward`, which is linear in time and
  reaches exactly zero when input is released, so there is no drift.
- Tuning values live in a `MovementStats` resource
  (`resources/player/player_movement.tres`). Defaults: 6 m/s top speed, 60 m/s²
  acceleration, 80 m/s² deceleration. Other characters can reuse the type with
  different data.
- Only the `Visual` child turns to face the movement direction (or the attack
  direction while attacking). The collision capsule never rotates.
- Collision layers: 1 `world` (floor, walls, pillars), 2 `player` and 3
  `enemy`. The player is on layer 2 and collides with layers 1 and 3.
- 3D physics uses Jolt (`physics/3d/physics_engine = "Jolt Physics"`).

## Combat

The first slice is one melee attack against training dummies. It is
deliberately small: no enemy AI, no player health, no loot.

- **`Health`** (Node): `max_health`, `current`, and the signals `damaged`,
  `died` and `revived`. `apply_damage()` returns the damage actually dealt and
  ignores dead targets. Attacks find it as a direct child of the body they hit
  (`Health.of(collider)`).
- **`AttackData`** (Resource): damage, reach, arc, windup, recovery, movement
  multiplier and aim-assist radius. The player's attack
  (`resources/combat/player_basic_attack.tres`) does 10 damage at 1.8 m in a
  120° arc, with a 0.12 s windup and 0.33 s recovery: one attack every 0.45 s.
- **`MeleeAttack`** (Node, child of the attacker): `try_start(facing)` runs
  windup → hit → recovery in `_physics_process`, carrying leftover time from
  one phase into the next. The hit uses a sphere shape query on `target_mask`
  (layer 3), keeps the bodies whose centers fall inside the arc, and damages
  each one once. The attacker's own body is excluded. Aim assist turns the attack
  toward the nearest living target within `aim_assist_radius`, which matters on
  touch screens where facing is imprecise. Signals: `started(direction)` and
  `struck(targets)`.
- **`PlayerController`** starts the attack while `attack` is held, so holding
  repeats it. It slows movement by the attack's multiplier, and snaps facing to
  the attack direction while the attack runs.
- **`TrainingDummy`** (StaticBody3D, layer 3): flashes white, spawns a floating
  `DamageNumber` and updates its health label when hit. When destroyed it hides,
  stops colliding and respawns with full health after `respawn_delay` (2.5 s).
- **Feedback** (`WeaponSwing`, `DamageNumber`, hit flash) uses tweens on the
  physics clock, so it pauses with the game and works with physics
  interpolation.

Known simplifications: the arc check uses target *centers*, so a large enemy
whose edge overlaps the arc but whose center is outside it is missed. Attacks
can only start on a physics tick, so each attack cycle can last up to one tick
longer than its data says: at most 33 ms at 30 Hz and 17 ms at 60 Hz. The test
suite checks that the number of attacks in 2 s is the same at 30, 60 and 120 Hz.

## Camera

`IsometricCameraRig`:

- Orthographic `Camera3D`, true isometric angle: yaw 45°, pitch −35.264°
  (atan(1/√2)).
- The rig's rotation is set once in `_ready()` and never changes. The rig only
  translates.
- It follows the target with exponential smoothing (`1 - exp(-k·delta)`), which
  behaves the same at any frame rate.
- Physics interpolation is enabled project-wide, so motion is smooth on
  90/120 Hz displays. The rig reads the target's *interpolated* transform in
  `_process` and has interpolation turned off for itself.

## Pause and focus

`PauseController` owns `get_tree().paused`:

- Pause sources: `toggle_pause` (Esc or P), the HUD **II** button, Android Back
  (`quit_on_go_back` is disabled), losing focus, and the app moving to the
  background. Regaining focus does **not** resume; the player resumes
  explicitly.
- Every pause transition calls `GameplayActions.release_all()`, which covers
  movement and attack. Input that ends while the game is paused (a lifted
  finger, a released key) never reaches gameplay, so anything held is dropped
  rather than left stuck.
- `TouchJoystick` and `TouchActionButton` reset themselves on
  `NOTIFICATION_PAUSED`, on application focus loss and when hidden.
- An attack in progress freezes with the game and finishes after resuming.

## Settings

- `GameSettings` (Resource) holds player options: joystick dead zone and
  sensitivity (controls), and render scale and FPS cap (graphics).
- The `Settings` autoload loads `user://settings.cfg` at startup (a missing file
  means defaults), applies graphics options to the engine, and emits `changed`.
  Values read from disk are type-checked and clamped.
- Systems pull what they need on `changed`. For example, the HUD forwards the
  joystick options to `TouchJoystick`. There is no settings screen yet.
  `Settings.save_to()` is ready for one.

## Rendering

- Mobile renderer (Vulkan), with automatic fallback to OpenGL ES 3 on devices
  without Vulkan.
- ETC2/ASTC texture compression is enabled, as required for Android export.
- Base resolution is 1280×720 with `canvas_items` stretch and `expand` aspect.
  The UI anchors to screen edges, so wider phones (20:9) show more of the arena
  instead of letterboxing.

## Tests

`game/tests/` contains a small headless runner (`run_tests.gd`) and suites
named `test_*.gd`. Each test method runs on a fresh suite instance in the scene
tree. Integration tests instantiate the real `main.tscn`. A test fails on a
failed `check` or on any engine or script error logged during it, captured with
a custom `Logger`. Warnings are printed under the test that logged them, and
counted in the summary, but do not fail it. Run them with `tools/test.sh`.

## Conventions

- Typed GDScript throughout. `class_name` is used only for types other code
  refers to.
- One responsibility per script; UI scripts live next to their scenes in `ui/`.
- Add folders when a system's implementation begins. Do not create empty module
  folders ahead of time.
