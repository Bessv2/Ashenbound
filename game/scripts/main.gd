extends Node3D
## Entry point of the game scene. Builds the run around a level, and connects
## the UI to game state; the UI only emits requests and never pauses the tree
## or restarts the game itself.

## The level played, instanced as the child "Level" when the scene starts.
@export var level_scene: PackedScene
## When false, no encounter starts by itself: a quiet level for practice and
## for tests. Encounters started by room triggers still start.
@export var encounters_start_by_themselves: bool = true

var level: Level

@onready var _pause_controller: PauseController = $PauseController
@onready var _player: PlayerController = $Player
@onready var _camera_rig: IsometricCameraRig = $CameraRig
@onready var _hud: Hud = $HUD
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _death_screen: DeathScreen = $DeathScreen
@onready var _run: RunController = $Run


func _ready() -> void:
	_load_level()
	_hud.pause_requested.connect(_pause_controller.set_paused.bind(true))
	_pause_menu.resume_requested.connect(_pause_controller.set_paused.bind(false))
	_pause_controller.paused_changed.connect(_pause_menu.set_open)
	_pause_menu.set_open(_pause_controller.is_paused())
	_hud.track_health(_player.health)
	_hud.track_dodge(_player.dodge)
	_hud.track_abilities(_player.abilities)
	_run.ended.connect(_on_run_ended)
	_death_screen.restart_requested.connect(restart)


## Starts the scene over from scratch.
func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _load_level() -> void:
	if level_scene == null:
		push_error("Main has no level to play.")
		return
	level = level_scene.instantiate() as Level
	level.name = "Level"
	if not encounters_start_by_themselves:
		for node in level.find_children("*", "Node3D", true, false):
			if node is EncounterController:
				node.auto_start = false
	add_child(level)
	move_child(level, 0)
	if level.player_start:
		_player.global_transform = level.player_start.global_transform
		_player.reset_physics_interpolation()
		_camera_rig.snap_to_target()
	_run.watch(level.encounters)


func _on_run_ended(victory: bool) -> void:
	GameplayActions.release_all()
	if not victory:
		_death_screen.open()
		return
	# The run is won: nothing can hurt or move the Warden any more.
	_player.input_enabled = false
	_player.health.invulnerable = true
	_death_screen.open(level.victory_title, "The ash settles, for now.", "Play again")
