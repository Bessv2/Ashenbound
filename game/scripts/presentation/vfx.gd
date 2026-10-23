class_name Vfx
extends RefCounted
## Short visual effects: sparks, smoke, debris, flames, shockwave rings,
## scorch marks and slash arcs. Visual only: they never touch Health. Each
## effect frees itself when done and runs on the physics clock, so it pauses
## with the game. CPU particles, so they behave the same in the Mobile and
## Compatibility (web) renderers. The sprites are Kenney's Particle Pack
## (CC0), packed by tools/art/make_particle_atlases.py.

const SPARK_SIZE := 0.1

const SmokeTexture := preload("res://assets/third_party/kenney_particles/smoke.png")
const FlameTexture := preload("res://assets/third_party/kenney_particles/flame.png")
const DebrisTexture := preload("res://assets/third_party/kenney_particles/debris.png")
const GlintTexture := preload("res://assets/third_party/kenney_particles/glint.png")
const RingTexture := preload("res://assets/third_party/kenney_particles/ring.png")
const ScorchTexture := preload("res://assets/third_party/kenney_particles/scorch.png")

static var _materials: Dictionary[Color, StandardMaterial3D] = {}
static var _sprite_materials: Dictionary[String, StandardMaterial3D] = {}


## A one-shot burst of `amount` glowing sparks from `at` (world), flying out
## at about `speed` m/s for `lifetime` seconds and shrinking as they cool.
## Added under `parent`.
static func burst(parent: Node, at: Vector3, color: Color, amount: int = 12,
		speed: float = 4.0, lifetime: float = 0.35, size: float = SPARK_SIZE) -> CPUParticles3D:
	var particles := _particles(parent, at, amount, lifetime)
	particles.spread = 75.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -9.0, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	particles.scale_amount_curve = _fade_curve()
	# The glint's soft edge needs a bigger quad than the old solid bit.
	particles.mesh = _sprite_quad(size * 3.2, _sprite_material("glint", GlintTexture, _bright(color, 2.2), true))
	particles.emitting = true
	return particles


## A cloud of `amount` smoke puffs at `at` that swell, turn and rise as they
## thin out over `lifetime` seconds. `color` tints them (dust, ash, soul-fire).
static func smoke(parent: Node, at: Vector3, color: Color, amount: int = 6, size: float = 1.2,
		lifetime: float = 1.0) -> CPUParticles3D:
	var particles := _particles(parent, at, amount, lifetime)
	particles.explosiveness = 0.85
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = size * 0.25
	particles.spread = 70.0
	particles.initial_velocity_min = 0.3
	particles.initial_velocity_max = 1.2
	particles.gravity = Vector3(0, 0.7, 0)
	particles.damping_min = 1.0
	particles.damping_max = 2.0
	particles.angle_min = -180.0
	particles.angle_max = 180.0
	particles.angular_velocity_min = -40.0
	particles.angular_velocity_max = 40.0
	particles.anim_offset_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.45))
	grow.add_point(Vector2(1.0, 1.0))
	particles.scale_amount_curve = grow
	particles.color_ramp = _alpha_ramp(color, 0.9, 0.2)
	particles.mesh = _sprite_quad(size, _sprite_material("smoke", SmokeTexture, Color.WHITE, false, 4, 2))
	particles.emitting = true
	return particles


## Chips and grit thrown from `at` that fall back down: bone, stone, earth.
static func debris(parent: Node, at: Vector3, color: Color, amount: int = 5, speed: float = 4.0,
		size: float = 0.5) -> CPUParticles3D:
	var particles := _particles(parent, at, amount, 0.6)
	particles.spread = 65.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -14.0, 0)
	particles.angle_min = -180.0
	particles.angle_max = 180.0
	particles.anim_offset_max = 1.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.1
	particles.color_ramp = _alpha_ramp(color, 1.0, 0.7)
	particles.mesh = _sprite_quad(size, _sprite_material("debris", DebrisTexture, Color.WHITE, false, 3, 1))
	particles.emitting = true
	return particles


## Tongues of fire licking up from `at` for `lifetime` seconds: a blast, a
## burning brand.
static func flames(parent: Node, at: Vector3, color: Color, amount: int = 8, size: float = 1.0,
		lifetime: float = 0.5) -> CPUParticles3D:
	var particles := _particles(parent, at, amount, lifetime)
	particles.explosiveness = 0.7
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = size * 0.4
	particles.spread = 20.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3(0, 2.0, 0)
	particles.anim_offset_max = 1.0
	particles.scale_amount_curve = _fade_curve()
	particles.mesh = _sprite_quad(size, _sprite_material("flame", FlameTexture, _bright(color, 2.0), true, 3, 2))
	particles.emitting = true
	return particles


## A dark burn on the floor at `at`, `radius` wide, that fades after a few
## seconds: where a blast went off.
static func scorch(parent: Node, at: Vector3, radius: float, seconds: float = 5.0) -> Decal:
	var decal := Decal.new()
	decal.name = "Scorch"
	decal.size = Vector3(radius * 2.0, 1.0, radius * 2.0)
	decal.texture_albedo = ScorchTexture
	decal.modulate = Color(0.05, 0.03, 0.02, 0.85)
	decal.cull_mask = 1
	parent.add_child(decal)
	decal.global_position = Vector3(at.x, at.y + 0.2, at.z)
	decal.rotation.y = randf() * TAU
	var tween := decal.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(seconds)
	tween.tween_property(decal, "modulate:a", 0.0, 1.5)
	tween.tween_callback(decal.queue_free)
	return decal


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


## A glowing shockwave ring on the floor at `at` (world) that grows to
## `radius` and fades in `seconds`: the area of a spell. Added under `parent`.
static func ring(parent: Node, at: Vector3, radius: float, color: Color, seconds: float = 0.45) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	# The texture's ring sits a little inside its edge.
	mesh.size = Vector2(2.3, 2.3)
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = mesh
	var material := _sprite_material("ring", RingTexture, _bright(color, 2.0), true).duplicate() as StandardMaterial3D
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.vertex_color_use_as_albedo = false
	ring_node.material_override = material
	ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring_node)
	ring_node.global_position = at + Vector3(0, 0.12, 0)
	ring_node.scale = Vector3(radius * 0.3, 1.0, radius * 0.3)
	var tween := ring_node.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(ring_node, "scale", Vector3(radius, 1.0, radius), seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material, "albedo_color:a", 0.0, seconds).from(1.0)
	tween.chain().tween_callback(ring_node.queue_free)
	return ring_node


static func _particles(parent: Node, at: Vector3, amount: int, lifetime: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = maxi(amount, 1)
	particles.lifetime = lifetime
	particles.direction = Vector3.UP
	particles.local_coords = false
	particles.process_mode = Node.PROCESS_MODE_PAUSABLE
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)
	particles.global_position = at
	particles.finished.connect(particles.queue_free)
	return particles


static func _sprite_quad(size: float, material: Material) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material
	return quad


## A camera-facing sprite material, shared per texture and colour: additive
## and glowing (sparks, fire) or alpha-blended (smoke, debris), with
## `columns` × `rows` frames of which each particle shows one.
static func _sprite_material(kind: String, texture: Texture2D, color: Color, additive: bool,
		columns: int = 1, rows: int = 1) -> StandardMaterial3D:
	var key := "%s:%s" % [kind, color.to_html()]
	if not _sprite_materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if additive:
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.particles_anim_h_frames = columns
		material.particles_anim_v_frames = rows
		material.particles_anim_loop = false
		material.vertex_color_use_as_albedo = true
		material.albedo_color = color
		material.albedo_texture = texture
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_sprite_materials[key] = material
	return _sprite_materials[key]


## `color` made brighter than white, so it glows through the bloom.
static func _bright(color: Color, factor: float) -> Color:
	return Color(color.r * factor, color.g * factor, color.b * factor, 1.0)


## Full size at birth, nothing at the end.
static func _fade_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


## `color` at `alpha`, held to `hold` of the life, then fading to clear.
static func _alpha_ramp(color: Color, alpha: float, hold: float = 0.0) -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, alpha))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	if hold > 0.0:
		ramp.add_point(hold, Color(color.r, color.g, color.b, alpha))
	return ramp


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
