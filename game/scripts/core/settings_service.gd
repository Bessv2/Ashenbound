extends Node
## Autoload "Settings": owns the active GameSettings, persists them to
## user://settings.cfg and applies the engine-wide (graphics) options.
##
## Systems that depend on a setting connect to `changed` and read what they
## need, so this service does not need to know about them.

signal changed(settings: GameSettings)

const SETTINGS_PATH := "user://settings.cfg"

var current: GameSettings = GameSettings.new()


func _ready() -> void:
	load_from(SETTINGS_PATH)
	apply()


## Loads settings from path. A missing file (first launch) is not an error and
## leaves the defaults in place.
func load_from(path: String) -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error == OK:
		current.read_from(config)
	elif error != ERR_FILE_NOT_FOUND:
		push_warning("Could not read settings from %s (%s); using defaults." % [path, error_string(error)])
	return error


func save_to(path: String) -> Error:
	var config := ConfigFile.new()
	current.write_to(config)
	return config.save(path)


## Pushes engine-wide options to the engine and notifies listeners.
func apply() -> void:
	Engine.max_fps = current.max_fps
	get_tree().root.scaling_3d_scale = current.render_scale
	changed.emit(current)
