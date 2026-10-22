class_name DeathScreen
extends CanvasLayer
## Shown when a run ends: when the player dies, and (with another title) on
## victory, with the run's summary. Fades in after a delay and offers a
## restart, and optionally a second choice (another crypt tier). Emits
## requests; Main performs the restart.

signal restart_requested
signal alternate_requested

## Time to let the death animation play before the screen appears.
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_delay: float = 0.8
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_duration: float = 0.5

@onready var _root: Control = $Root
@onready var _restart_button: Button = %RestartButton
@onready var _title: Label = $Root/Center/Panel/Items/Title
@onready var _flavor: Label = $Root/Center/Panel/Items/Flavor
@onready var _details: Label = %Details
@onready var _alternate_button: Button = %AlternateButton


func _ready() -> void:
	hide()
	_restart_button.pressed.connect(restart_requested.emit)
	_alternate_button.pressed.connect(alternate_requested.emit)


## Opens the screen after `delay` seconds (the fade delay when negative).
## Empty texts keep the defaults (the death texts); `details` is the summary
## (hidden when empty); `alternate` labels the second button (hidden when
## empty).
func open(title: String = "", flavor: String = "", button: String = "", details: String = "",
		delay: float = -1.0, alternate: String = "") -> void:
	_alternate_button.text = alternate
	_alternate_button.visible = alternate != ""
	_details.text = details
	_details.visible = details != ""
	if title != "":
		_title.text = title
	if flavor != "":
		_flavor.text = flavor
	if button != "":
		_restart_button.text = button
	show()
	_root.modulate.a = 0.0
	# Disabled until visible, so a stray tap during the fall cannot restart.
	_restart_button.disabled = true
	_alternate_button.disabled = true
	var tween := create_tween()
	tween.tween_interval(fade_delay if delay < 0.0 else delay)
	tween.tween_property(_root, "modulate:a", 1.0, fade_duration)
	tween.tween_callback(_enable_restart)


func _enable_restart() -> void:
	_restart_button.disabled = false
	_alternate_button.disabled = false
	_restart_button.grab_focus()
