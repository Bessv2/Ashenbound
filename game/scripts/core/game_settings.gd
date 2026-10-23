class_name GameSettings
extends Resource
## Player-adjustable options. Loaded, applied and saved by the Settings autoload.
##
## Values read from disk are validated and clamped, so a hand-edited or stale
## settings file cannot put the game in an invalid state.

const CONTROLS := "controls"
const GRAPHICS := "graphics"
const AUDIO := "audio"

@export_group("Controls")
## Fraction of the joystick radius around the center that is ignored.
@export_range(0.0, 0.5, 0.01) var joystick_dead_zone: float = 0.15
## Scales joystick deflection. Above 1 reaches full speed before the rim.
@export_range(0.5, 2.0, 0.05) var joystick_sensitivity: float = 1.0

@export_group("Graphics")
## 3D render resolution relative to the screen. Lower is faster.
@export_range(0.5, 1.0, 0.05) var render_scale: float = 1.0
## Frame rate cap. 0 means uncapped (still limited by V-Sync).
@export_range(0, 240, 1) var max_fps: int = 60
## Camera shake on heavy hits. Off for players it bothers.
@export var screen_shake: bool = true
## The look (ArtStyle.Look): 0 classic, 1 look A, 2 look B. Applies to the
## next run.
@export_range(0, 2, 1) var art_style: int = 0

@export_group("Audio")
## Music loudness, 0 (off) to 1.
@export_range(0.0, 1.0, 0.05) var music_volume: float = 0.7
## Effects loudness (combat, the world and the interface), 0 (off) to 1.
@export_range(0.0, 1.0, 0.05) var effects_volume: float = 1.0


func write_to(config: ConfigFile) -> void:
	config.set_value(CONTROLS, "joystick_dead_zone", joystick_dead_zone)
	config.set_value(CONTROLS, "joystick_sensitivity", joystick_sensitivity)
	config.set_value(GRAPHICS, "render_scale", render_scale)
	config.set_value(GRAPHICS, "max_fps", max_fps)
	config.set_value(GRAPHICS, "screen_shake", screen_shake)
	config.set_value(GRAPHICS, "art_style", art_style)
	config.set_value(AUDIO, "music_volume", music_volume)
	config.set_value(AUDIO, "effects_volume", effects_volume)


## Reads known keys from config. Missing or malformed values keep their
## current value; out-of-range values are clamped.
func read_from(config: ConfigFile) -> void:
	joystick_dead_zone = _read_number(config, CONTROLS, "joystick_dead_zone", joystick_dead_zone, 0.0, 0.5)
	joystick_sensitivity = _read_number(config, CONTROLS, "joystick_sensitivity", joystick_sensitivity, 0.5, 2.0)
	render_scale = _read_number(config, GRAPHICS, "render_scale", render_scale, 0.5, 1.0)
	max_fps = int(_read_number(config, GRAPHICS, "max_fps", max_fps, 0, 240))
	var shake: Variant = config.get_value(GRAPHICS, "screen_shake", screen_shake)
	screen_shake = shake if shake is bool else screen_shake
	art_style = int(_read_number(config, GRAPHICS, "art_style", art_style, 0, 2))
	music_volume = _read_number(config, AUDIO, "music_volume", music_volume, 0.0, 1.0)
	effects_volume = _read_number(config, AUDIO, "effects_volume", effects_volume, 0.0, 1.0)


static func _read_number(
		config: ConfigFile, section: String, key: String, fallback: float,
		min_value: float, max_value: float) -> float:
	var value: Variant = config.get_value(section, key, fallback)
	if not (value is float or value is int):
		return fallback
	return clampf(value, min_value, max_value)
