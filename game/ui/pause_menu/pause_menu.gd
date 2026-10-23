class_name PauseMenu
extends CanvasLayer
## Overlay shown while the game is paused. Processes only while paused.

signal resume_requested
## Back to the title screen (the run is abandoned; what it earned is kept).
signal leave_requested

@onready var _resume_button: Button = %ResumeButton


func _ready() -> void:
	_resume_button.pressed.connect(resume_requested.emit)
	(%LeaveButton as Button).pressed.connect(leave_requested.emit)
	var shake := %ShakeButton as Button
	shake.pressed.connect(_toggle_shake)
	Settings.changed.connect(_show_shake.unbind(1))
	_show_shake()
	var music := %MusicSlider as HSlider
	var effects := %EffectsSlider as HSlider
	music.value = Settings.current.music_volume
	effects.value = Settings.current.effects_volume
	music.value_changed.connect(set_volume.bind(&"music_volume"))
	effects.value_changed.connect(set_volume.bind(&"effects_volume"))


## Sets volume `key` (GameSettings music_volume or effects_volume), heard at
## once, and saves it.
func set_volume(volume: float, key: StringName) -> void:
	Settings.current.set(key, clampf(volume, 0.0, 1.0))
	Settings.save_to(Settings.SETTINGS_PATH)
	Settings.apply()
	if key == &"effects_volume":
		Audio.play(&"ui_click")


## Turns camera shake on or off and saves the choice.
func _toggle_shake() -> void:
	Settings.current.screen_shake = not Settings.current.screen_shake
	Settings.save_to(Settings.SETTINGS_PATH)
	Settings.apply()


func _show_shake() -> void:
	(%ShakeButton as Button).text = "Screen shake: %s" % ("On" if Settings.current.screen_shake else "Off")


func set_open(open: bool) -> void:
	var opening := open and not visible
	visible = open
	if opening:
		UiFx.pop_layer(self)
		Audio.play(&"ui_open")
	if open:
		# Lets keyboard and gamepad players resume with the accept key.
		_resume_button.grab_focus()
