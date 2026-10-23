class_name Raven
extends Node3D
## The Carrion Raven a RavenAbility calls: a child of the hero that circles it
## and dives at the nearest enemy every strike interval. The dive's flight is
## presentation; the damage is dealt on the strike tick, here, through Health.

const CIRCLE_RADIUS := 1.4
const HEIGHT := 2.6
const CIRCLE_SPEED := 2.4

var ability: RavenAbility
## Strikes made since it was called or renewed.
var strikes: int = 0

var _life_left: float = 0.0
var _strike_left: float = 0.0
var _angle: float = 0.0
var _body: Node3D
var _dive: Tween


func _ready() -> void:
	top_level = true
	_body = _build_body()
	add_child(_body)
	global_position = _circle_point()
	Audio.play(&"wings", global_position)


## Restarts its time and its strike count down.
func renew() -> void:
	_life_left = ability.lifetime
	_strike_left = ability.strike_interval
	strikes = 0


## Seconds it has left.
func time_left() -> float:
	return maxf(_life_left, 0.0)


func _hero() -> Node3D:
	return get_parent() as Node3D


func _circle_point() -> Vector3:
	return _hero().global_position + Vector3(cos(_angle) * CIRCLE_RADIUS, HEIGHT, sin(_angle) * CIRCLE_RADIUS)


func _physics_process(delta: float) -> void:
	var hero_health := Health.of(_hero())
	_life_left -= delta
	if _life_left <= 0.0 or (hero_health and hero_health.is_dead()):
		Vfx.burst(_hero().get_parent(), global_position, RavenAbility.COLOR, 8, 2.0, 0.4)
		queue_free()
		set_physics_process(false)
		return
	_angle += CIRCLE_SPEED * delta
	if _dive == null or not _dive.is_running():
		global_position = global_position.lerp(_circle_point(), minf(delta * 8.0, 1.0))
		_body.rotation.y = -_angle
	_strike_left -= delta
	if _strike_left > 0.0:
		return
	_strike_left += ability.strike_interval
	var target := Targeting.nearest_living(_hero(), ability.reach, ability.target_mask)
	if target == null:
		return
	var at := (target.get_parent() as Node3D).global_position + Vector3.UP * 1.0
	target.apply_damage(ability.strike_damage(), _hero().global_position)
	strikes += 1
	_swoop(at)


## Flies to `at` and back to the circle. Visual only.
func _swoop(at: Vector3) -> void:
	if _dive:
		_dive.kill()
	_dive = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_dive.tween_property(self, "global_position", at, 0.12).set_ease(Tween.EASE_IN)
	_dive.tween_callback(func() -> void:
		Audio.play(&"crow", at)
		Vfx.burst(_hero().get_parent(), at, RavenAbility.COLOR, 8, 3.0, 0.25))
	_dive.tween_property(self, "global_position", _circle_point(), 0.25).set_ease(Tween.EASE_OUT)


## A dark bird of two swept wings and a body, with amber eyes.
static func _build_body() -> Node3D:
	var root := Node3D.new()
	root.name = "Body"
	root.scale = Vector3.ONE * 1.5
	# Near black, with a faint violet sheen so it reads against a dark floor.
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.08, 0.12)
	dark.roughness = 0.6
	dark.emission_enabled = true
	dark.emission = Color(0.4, 0.25, 0.6)
	dark.emission_energy_multiplier = 0.8
	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.11
	capsule.height = 0.5
	torso.mesh = capsule
	torso.material_override = dark
	torso.rotation.x = PI * 0.5
	root.add_child(torso)
	for side: float in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var plate := BoxMesh.new()
		plate.size = Vector3(0.55, 0.03, 0.22)
		wing.mesh = plate
		wing.material_override = dark
		wing.position = Vector3(side * 0.3, 0.04, 0.02)
		wing.rotation = Vector3(0.0, side * 0.35, side * 0.25)
		root.add_child(wing)
	var eye := StandardMaterial3D.new()
	eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye.albedo_color = RavenAbility.COLOR
	eye.emission_enabled = true
	eye.emission = RavenAbility.COLOR
	eye.emission_energy_multiplier = 3.0
	var glow := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	glow.mesh = sphere
	glow.material_override = eye
	glow.position = Vector3(0, 0.05, -0.26)
	root.add_child(glow)
	for node in root.get_children():
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
