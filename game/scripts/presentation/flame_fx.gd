class_name FlameFx
extends Node3D
## A living fire for torches and braziers: an animated flame (shader), embers
## drifting up, and a flicker on its light. Visual only, and cheap: one quad,
## a few CPU particles, and a light whose energy wobbles.

const FLAME_SHADER := preload("res://resources/shaders/flame.gdshader")

## The light to flicker (optional). Its energy is taken as the average.
@export var light: OmniLight3D
@export_range(0.1, 3.0, 0.05, "suffix:m") var size: float = 0.5
@export var core_color: Color = Color(1.0, 0.85, 0.45)
@export var edge_color: Color = Color(1.0, 0.35, 0.08)
@export_range(0, 64, 1) var ember_count: int = 10
## How much the light's energy wanders (0 to 1).
@export_range(0.0, 1.0, 0.01) var flicker: float = 0.22

static var _soft_dot: Texture2D

var _base_energy: float = 1.0
var _phase: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_phase = randf() * 100.0
	if light:
		_base_energy = light.light_energy
	_build_flame()
	if ember_count > 0:
		_build_embers()


## A small round glow with soft edges, for particles. Made once.
static func soft_dot() -> Texture2D:
	if _soft_dot == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 32
		texture.height = 32
		_soft_dot = texture
	return _soft_dot


func _process(delta: float) -> void:
	if light == null or not is_visible_in_tree():
		return
	_time += delta
	var t := _time + _phase
	var wobble := sin(t * 7.1) * 0.5 + sin(t * 12.7 + 1.3) * 0.3 + sin(t * 3.3 + 0.7) * 0.2
	light.light_energy = _base_energy * (1.0 + wobble * flicker)


func _build_flame() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(size * 0.7, size * 1.3)
	quad.center_offset = Vector3(0.0, size * 0.55, 0.0)
	var material := ShaderMaterial.new()
	material.shader = FLAME_SHADER
	material.set_shader_parameter(&"core_color", core_color)
	material.set_shader_parameter(&"edge_color", edge_color)
	material.set_shader_parameter(&"seed", _phase)
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	flame.mesh = quad
	flame.material_override = material
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)


func _build_embers() -> void:
	var embers := CPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = ember_count
	embers.lifetime = 1.6
	embers.randomness = 0.6
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = size * 0.25
	embers.direction = Vector3.UP
	embers.spread = 18.0
	embers.gravity = Vector3(0.0, 0.6, 0.0)
	embers.initial_velocity_min = 0.4
	embers.initial_velocity_max = 1.1
	embers.scale_amount_min = 0.4
	embers.scale_amount_max = 1.0
	embers.position.y = size * 0.6
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	embers.scale_amount_curve = curve
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.08, 0.08)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(edge_color.r, edge_color.g * 1.4, edge_color.b, 1.0) * 2.0
	material.albedo_texture = soft_dot()
	mesh.material = material
	embers.mesh = mesh
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(embers)
