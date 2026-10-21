class_name Hud
extends CanvasLayer
## In-game overlay: title, pause button, touch joystick and a debug readout.
## Emits requests; it does not change game state itself.

signal pause_requested

@onready var _pause_button: Button = %PauseButton
@onready var _joystick: TouchJoystick = %TouchJoystick
@onready var _debug_label: Label = %DebugLabel
@onready var _controls_hint: Label = %ControlsHint


func _ready() -> void:
	_pause_button.pressed.connect(pause_requested.emit)
	_debug_label.visible = OS.is_debug_build()
	# Not DisplayServer.is_touchscreen_available(): mouse-to-touch emulation
	# (used to test the joystick on desktop) makes that true everywhere.
	_controls_hint.visible = not OS.has_feature("mobile")
	Settings.changed.connect(_apply_settings)
	_apply_settings(Settings.current)


func _process(_delta: float) -> void:
	if _debug_label.visible:
		var intent := MovementInput.get_vector()
		_debug_label.text = "FPS %d   move (%.2f, %.2f)" % [Engine.get_frames_per_second(), intent.x, intent.y]


func _apply_settings(settings: GameSettings) -> void:
	_joystick.dead_zone = settings.joystick_dead_zone
	_joystick.sensitivity = settings.joystick_sensitivity
