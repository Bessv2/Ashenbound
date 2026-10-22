class_name ScreenFx
extends CanvasLayer
## The frame over the world (resources/shaders/screen_fx.gdshader): vignette,
## grain, and a red pulse at the edges that grows as the tracked Health runs
## low. Below the HUD, ignores input. Visual only.

const SHADER := preload("res://resources/shaders/screen_fx.gdshader")
## Below this share of health the edges start to pulse.
const DANGER_BELOW := 0.4

var _rect: ColorRect
var _material: ShaderMaterial
var _health: Health
var _danger: float = 0.0


func _ready() -> void:
	# Above the 3D world, under the HUD (layer 1) and every menu.
	layer = 0
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)


func track(health: Health) -> void:
	_health = health


## How strongly the edges pulse now (0 to 1).
func danger() -> float:
	return _danger


func _process(delta: float) -> void:
	var target := 0.0
	if _health and not _health.is_dead() and _health.max_health > 0:
		var fraction := float(_health.current) / _health.max_health
		target = clampf((DANGER_BELOW - fraction) / DANGER_BELOW, 0.0, 1.0)
	_danger = move_toward(_danger, target, delta * 2.0)
	_material.set_shader_parameter(&"danger", _danger)
