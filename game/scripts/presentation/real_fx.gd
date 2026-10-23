class_name RealFx
extends RefCounted
## Look A's effects (ArtStyle.Look.HEROIC): realistic hits on cartoon bodies.
## White-hot sparks that streak along their velocity and fall, blood or bone
## dust depending on what was hit, a puff of smoke, a brief flash of light,
## blood pooling where the living fall, and fast motion-blur swings. Visual
## only: nothing here touches Health. Each effect frees itself and runs on
## the physics clock, so it pauses with the game.

const SPARK_HOT := Color(1.0, 0.95, 0.8)
const SPARK_COOL := Color(0.9, 0.35, 0.08)
const BLOOD := Color(0.32, 0.02, 0.02)
const BONE := Color(0.78, 0.74, 0.66)
const SMOKE := Color(0.32, 0.3, 0.3)

static var _blood_texture: Texture2D


## A hit landing at `at` on `parent`'s level: sparks, then blood (`flesh`) or
## bone chips and dust, smoke and a flash of light.
static func impact(parent: Node, at: Vector3, flesh: bool) -> void:
	_streaks(parent, at, 30, 11.0, 0.45)
	_glare(parent, at, 1.4, 0.09)
	if flesh:
		_droplets(parent, at, BLOOD, 22, 4.5, 0.7, 0.08)
	else:
		_droplets(parent, at, BONE, 16, 5.0, 0.6, 0.07)
	_smoke(parent, at, 8, 1.1, 0.7)
	_flash(parent, at, SPARK_COOL, 6.0, 4.5, 0.15)


## A body falling at `at`: heavy dust, debris, and for the living a pool of
## blood spreading on the floor.
static func death(parent: Node, at: Vector3, flesh: bool) -> void:
	_smoke(parent, at, 16, 1.6, 1.1)
	_droplets(parent, at, BLOOD if flesh else BONE, 22, 3.5, 0.8, 0.09)
	if flesh:
		pool(parent, Vector3(at.x, 0.0, at.z), 1.1)


## A swing: a thin, white-hot streak along the arc that fades in a tenth of
## a second, like motion blur.
static func swing(owner: Node3D, direction: Vector3, reach: float, arc_degrees: float, color: Color) -> void:
	Vfx.slash(owner, direction, reach, arc_degrees, color.lerp(SPARK_HOT, 0.6), 0.1)


## A dark stain on the floor at `at` that spreads to `radius` and fades after
## a few seconds.
static func pool(parent: Node, at: Vector3, radius: float) -> Decal:
	var decal := Decal.new()
	decal.name = "BloodPool"
	decal.size = Vector3(radius * 2.0, 1.0, radius * 2.0)
	decal.texture_albedo = _blood()
	decal.modulate = Color(0.45, 0.03, 0.03, 0.9)
	decal.cull_mask = 1
	parent.add_child(decal)
	decal.global_position = at + Vector3.UP * 0.2
	decal.scale = Vector3.ONE * 0.2
	var tween := decal.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(decal, "scale", Vector3.ONE, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(5.0)
	tween.tween_property(decal, "modulate:a", 0.0, 2.0)
	tween.tween_callback(decal.queue_free)
	return decal


## Sparks: thin bright streaks aligned with their velocity, falling under
## gravity and cooling from white to orange.
static func _streaks(parent: Node, at: Vector3, amount: int, speed: float, lifetime: float) -> CPUParticles3D:
	var particles := _particles(parent, at, amount, lifetime)
	particles.spread = 80.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -16.0, 0)
	particles.particle_flag_align_y = true
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.42, 0.035)
	mesh.material = _additive_material()
	particles.mesh = mesh
	var ramp := Gradient.new()
	ramp.set_color(0, SPARK_HOT)
	ramp.set_color(1, Color(SPARK_COOL.r, SPARK_COOL.g, SPARK_COOL.b, 0.0))
	particles.color_ramp = ramp
	particles.emitting = true
	return particles


## Droplets or chips: small solid bits thrown out and falling.
static func _droplets(parent: Node, at: Vector3, color: Color, amount: int, speed: float, lifetime: float,
		size: float) -> CPUParticles3D:
	var particles := _particles(parent, at, amount, lifetime)
	particles.spread = 70.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -14.0, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.3
	var mesh := SphereMesh.new()
	mesh.radius = size * 0.5
	mesh.height = size
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.25 if color == BLOOD else 0.8
	material.metallic_specular = 0.8
	mesh.material = material
	particles.mesh = mesh
	particles.emitting = true
	return particles


## Smoke: soft grey puffs that rise slowly, swell and thin out.
static func _smoke(parent: Node, at: Vector3, amount: int, size: float, lifetime: float) -> CPUParticles3D:
	var particles := _particles(parent, at, amount, lifetime)
	particles.explosiveness = 0.8
	particles.spread = 60.0
	particles.initial_velocity_min = 0.4
	particles.initial_velocity_max = 1.4
	particles.gravity = Vector3(0, 0.6, 0)
	particles.damping_min = 1.0
	particles.damping_max = 2.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.0))
	particles.scale_amount_curve = grow
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = FlameFx.soft_dot()
	mesh.material = material
	particles.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, Color(SMOKE.r, SMOKE.g, SMOKE.b, 0.55))
	fade.set_color(1, Color(SMOKE.r, SMOKE.g, SMOKE.b, 0.0))
	particles.color_ramp = fade
	particles.emitting = true
	return particles


## A white-hot glare at the point of contact for a few frames, like a camera
## catching the impact.
static func _glare(parent: Node, at: Vector3, size: float, seconds: float) -> void:
	var glare := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	glare.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = FlameFx.soft_dot()
	material.albedo_color = Color(1.6, 1.4, 1.1)
	material.no_depth_test = true
	glare.material_override = material
	glare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glare)
	glare.global_position = at
	var tween := glare.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(material, "albedo_color", Color(0, 0, 0), seconds)
	tween.tween_callback(glare.queue_free)


## A short burst of light at the impact, fading in `seconds`.
static func _flash(parent: Node, at: Vector3, color: Color, energy: float, light_range: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	parent.add_child(light)
	light.global_position = at + Vector3.UP * 0.3
	var tween := light.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(light, "light_energy", 0.0, seconds)
	tween.tween_callback(light.queue_free)


static func _particles(parent: Node, at: Vector3, amount: int, lifetime: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = Vector3.UP
	particles.local_coords = false
	particles.process_mode = Node.PROCESS_MODE_PAUSABLE
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)
	particles.global_position = at
	particles.finished.connect(particles.queue_free)
	return particles


static func _additive_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(2.0, 2.0, 2.0)
	return material


## A soft, ragged round stain.
static func _blood() -> Texture2D:
	if _blood_texture == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.09
		var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
				var edge := 0.75 + noise.get_noise_2d(x, y) * 0.35
				var a := clampf((edge - d) * 6.0, 0.0, 1.0)
				image.set_pixel(x, y, Color(1, 1, 1, a))
		_blood_texture = ImageTexture.create_from_image(image)
	return _blood_texture
