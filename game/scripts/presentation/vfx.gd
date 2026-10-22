class_name Vfx
extends RefCounted
## Short visual effects: particle bursts and slash arcs. Visual only: they
## never touch Health. Each effect frees itself when done and runs on the
## physics clock, so it pauses with the game. CPU particles, so they behave
## the same in the Mobile and Compatibility (web) renderers.

const SPARK_SIZE := 0.1

static var _materials: Dictionary[Color, StandardMaterial3D] = {}


## A one-shot burst of `amount` glowing bits from `at` (world), flying out at
## about `speed` m/s for `lifetime` seconds. Added under `parent`.
static func burst(parent: Node, at: Vector3, color: Color, amount: int = 12,
		speed: float = 4.0, lifetime: float = 0.35, size: float = SPARK_SIZE) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = Vector3.UP
	particles.spread = 75.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -9.0, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	particles.local_coords = false
	particles.process_mode = Node.PROCESS_MODE_PAUSABLE
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	mesh.material = _glow(color)
	particles.mesh = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles


## A glowing arc on the floor in front of `owner`, `reach` long and
## `arc_degrees` wide around `direction`, that flares and fades in `seconds`.
static func slash(owner: Node3D, direction: Vector3, reach: float, arc_degrees: float,
		color: Color, seconds: float = 0.18) -> MeshInstance3D:
	var arc := MeshInstance3D.new()
	arc.mesh = AttackTelegraph.build_sector(reach, arc_degrees, 18)
	var material := _glow(color).duplicate() as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc.material_override = material
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.add_child(arc)
	arc.top_level = true
	arc.global_position = owner.global_position + Vector3(0, 0.5, 0)
	arc.rotation = Vector3(0, MovementStats.yaw_of(direction), 0)
	arc.scale = Vector3.ONE * 0.7
	var tween := arc.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(arc, "scale", Vector3.ONE, seconds).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, seconds).from(0.85)
	tween.chain().tween_callback(arc.queue_free)
	return arc


## A glowing ring on the floor at `at` (world) that grows to `radius` and
## fades in `seconds`: the area of a spell. Added under `parent`.
static func ring(parent: Node, at: Vector3, radius: float, color: Color, seconds: float = 0.45) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.86
	mesh.outer_radius = 1.0
	mesh.rings = 32
	mesh.ring_segments = 4
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = mesh
	var material := _glow(color).duplicate() as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_node.material_override = material
	ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring_node)
	ring_node.global_position = at + Vector3(0, 0.12, 0)
	ring_node.scale = Vector3(radius * 0.3, 0.15, radius * 0.3)
	var tween := ring_node.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(ring_node, "scale", Vector3(radius, 0.15, radius), seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material, "albedo_color:a", 0.0, seconds).from(0.9)
	tween.chain().tween_callback(ring_node.queue_free)
	return ring_node


static func _glow(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
		_materials[color] = material
	return _materials[color]
