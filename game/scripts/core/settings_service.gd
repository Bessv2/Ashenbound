extends Node
## Autoload "Settings": owns the active GameSettings, persists them to
## user://settings.cfg and applies the engine-wide (graphics) options.
##
## Systems that depend on a setting connect to `changed` and read what they
## need, so this service does not need to know about them.

signal changed(settings: GameSettings)

const SETTINGS_PATH := "user://settings.cfg"
## On phones the 3D scene is drawn at most this many pixels tall. Phone screens
## have two to three times the pixels the game is designed for (720 tall),
## and every one of them costs shading time; the interface stays sharp.
const PHONE_3D_HEIGHT := 810.0

var current: GameSettings = GameSettings.new()


func _ready() -> void:
	load_from(SETTINGS_PATH)
	apply()
	# Rotating or resizing the window changes how many pixels the cap allows.
	get_tree().root.size_changed.connect(_apply_scale)


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
	_apply_scale()
	changed.emit(current)


## The 3D render scale for a window `pixel_height` tall: the player's
## render_scale, further capped on phones to PHONE_3D_HEIGHT pixels.
static func scale_3d(render_scale: float, pixel_height: float, phone: bool) -> float:
	if not phone or pixel_height <= PHONE_3D_HEIGHT:
		return render_scale
	return clampf(render_scale * PHONE_3D_HEIGHT / pixel_height, 0.33, render_scale)


## Whether this is a phone or tablet: the Android app, or a browser on one.
static func is_phone() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _apply_scale() -> void:
	var height := float(DisplayServer.window_get_size().y)
	get_tree().root.scaling_3d_scale = scale_3d(current.render_scale, height, is_phone())
