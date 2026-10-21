extends Node3D
## Entry point of the game scene. Connects the UI to game state; the UI only
## emits requests and never pauses the tree itself.

@onready var _pause_controller: PauseController = $PauseController
@onready var _hud: Hud = $HUD
@onready var _pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	_hud.pause_requested.connect(_pause_controller.set_paused.bind(true))
	_pause_menu.resume_requested.connect(_pause_controller.set_paused.bind(false))
	_pause_controller.paused_changed.connect(_pause_menu.set_open)
	_pause_menu.set_open(_pause_controller.is_paused())
