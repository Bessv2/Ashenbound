class_name PauseMenu
extends CanvasLayer
## Overlay shown while the game is paused. Processes only while paused.

signal resume_requested

@onready var _resume_button: Button = %ResumeButton


func _ready() -> void:
	_resume_button.pressed.connect(resume_requested.emit)
	var shake := %ShakeButton as Button
	shake.pressed.connect(_toggle_shake)
	Settings.changed.connect(_show_shake.unbind(1))
	_show_shake()


## Turns camera shake on or off and saves the choice.
func _toggle_shake() -> void:
	Settings.current.screen_shake = not Settings.current.screen_shake
	Settings.save_to(Settings.SETTINGS_PATH)
	Settings.apply()


func _show_shake() -> void:
	(%ShakeButton as Button).text = "Screen shake: %s" % ("On" if Settings.current.screen_shake else "Off")


func set_open(open: bool) -> void:
	visible = open
	if open:
		# Lets keyboard and gamepad players resume with the accept key.
		_resume_button.grab_focus()
