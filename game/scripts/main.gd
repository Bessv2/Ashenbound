extends Node3D
## Entry point of the game scene. Connects the UI to game state; the UI only
## emits requests and never pauses the tree or restarts the game itself.

@onready var _pause_controller: PauseController = $PauseController
@onready var _player: PlayerController = $Player
@onready var _hud: Hud = $HUD
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _death_screen: DeathScreen = $DeathScreen
@onready var _run: RunController = $Run


func _ready() -> void:
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


func _on_run_ended(victory: bool) -> void:
	GameplayActions.release_all()
	if not victory:
		_death_screen.open()
		return
	# The run is won: nothing can hurt or move the Warden any more.
	_player.input_enabled = false
	_player.health.invulnerable = true
	_death_screen.open("The hall is cleared", "The ash settles, for now.", "Play again")
