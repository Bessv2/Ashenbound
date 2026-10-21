class_name PauseMenu
extends CanvasLayer
## Overlay shown while the game is paused. Processes only while paused.

signal resume_requested

@onready var _resume_button: Button = %ResumeButton


func _ready() -> void:
	_resume_button.pressed.connect(resume_requested.emit)


func set_open(open: bool) -> void:
	visible = open
	if open:
		# Lets keyboard and gamepad players resume with the accept key.
		_resume_button.grab_focus()
