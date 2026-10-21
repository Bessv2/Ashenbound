class_name DeathScreen
extends CanvasLayer
## Shown when the player dies. Fades in after the fall animation and offers a
## restart. Emits a request; Main performs the restart.

signal restart_requested

## Time to let the death animation play before the screen appears.
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_delay: float = 0.8
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_duration: float = 0.5

@onready var _root: Control = $Root
@onready var _restart_button: Button = %RestartButton


func _ready() -> void:
	hide()
	_restart_button.pressed.connect(restart_requested.emit)


func open() -> void:
	show()
	_root.modulate.a = 0.0
	# Disabled until visible, so a stray tap during the fall cannot restart.
	_restart_button.disabled = true
	var tween := create_tween()
	tween.tween_interval(fade_delay)
	tween.tween_property(_root, "modulate:a", 1.0, fade_duration)
	tween.tween_callback(_enable_restart)


func _enable_restart() -> void:
	_restart_button.disabled = false
	_restart_button.grab_focus()
