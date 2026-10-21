extends Node3D
## Entry point of the game scene. Connects the UI to game state; the UI only
## emits requests and never pauses the tree or restarts the game itself.

@onready var _pause_controller: PauseController = $PauseController
@onready var _player: PlayerController = $Player
@onready var _hud: Hud = $HUD
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _death_screen: DeathScreen = $DeathScreen


func _ready() -> void:
	_hud.pause_requested.connect(_pause_controller.set_paused.bind(true))
	_pause_menu.resume_requested.connect(_pause_controller.set_paused.bind(false))
	_pause_controller.paused_changed.connect(_pause_menu.set_open)
	_pause_menu.set_open(_pause_controller.is_paused())
	_hud.track_health(_player.health)
	_player.health.died.connect(_on_player_died)
	_death_screen.restart_requested.connect(restart)


## Starts the scene over from scratch.
func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_player_died() -> void:
	GameplayActions.release_all()
	_death_screen.open()
