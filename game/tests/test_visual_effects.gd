extends "res://tests/framework/test_case.gd"
## Tests for the visual pass: effects are visual only and free themselves,
## and the camera shake follows the hero's hits and the player's setting.

const WardenScene := preload("res://scenes/player/warden.tscn")
const DummyScene := preload("res://scenes/enemies/training_dummy.tscn")


func _exit_tree() -> void:
	Settings.current.screen_shake = true


func _particles_under(node: Node) -> Array[Node]:
	return node.find_children("*", "CPUParticles3D", true, false)


func test_a_burst_frees_itself_and_a_slash_fades_out() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var burst := Vfx.burst(holder, Vector3.ZERO, Color.RED, 8, 3.0, 0.1)
	var slash := Vfx.slash(holder, Vector3.FORWARD, 2.0, 120.0, Color.ORANGE, 0.1)
	var burst_id := burst.get_instance_id()
	var slash_id := slash.get_instance_id()
	check(await wait_until(func() -> bool: return not is_instance_id_valid(burst_id) and not is_instance_id_valid(slash_id), 120),
			"both effects are gone after they play")
	holder.queue_free()


func test_a_swing_draws_an_arc_and_sparks_without_extra_damage() -> void:
	add_level(30.0)
	var warden: PlayerController = WardenScene.instantiate()
	add_child(warden)
	var dummy: Node3D = DummyScene.instantiate()
	add_child(dummy)
	dummy.global_position = warden.global_position + Vector3(0, 0, -1.2)
	await wait_physics_frames(2)
	var health := Health.of(dummy)
	var hits: Array[int] = []
	health.damaged.connect(func(amount: int, _left: int) -> void: hits.append(amount))
	check(warden.attack.try_start(Vector3.FORWARD), "the swing starts")
	check(await wait_until(func() -> bool: return not hits.is_empty(), 120), "the swing lands")
	var arcs := warden.get_children().filter(func(c: Node) -> bool: return c is MeshInstance3D and c.top_level)
	check(arcs.size() == 1, "one slash arc: %d" % arcs.size())
	check(not _particles_under(dummy).is_empty(), "the hit throws sparks")
	await wait_physics_frames(30)
	check(hits.size() == 1, "effects never deal damage: %s" % [hits])


func test_the_camera_shakes_when_the_hero_is_hurt_unless_turned_off() -> void:
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var rig: IsometricCameraRig = main.get_node("CameraRig")
	var hero: PlayerController = main.get_node("Player")
	hero.health.apply_damage(10)
	check(rig.trauma > 0.3, "a hit shakes the camera: %s" % rig.trauma)
	check(await wait_until(func() -> bool: return rig.trauma == 0.0, 240), "the shake settles")
	check(Vector2(rig.camera.position.x, rig.camera.position.y).is_zero_approx() and rig.camera.position.z == rig.distance, "and the camera returns to its place")
	Settings.current.screen_shake = false
	Settings.apply()
	hero.health.apply_damage(10)
	check(rig.trauma == 0.0, "no shake when the setting is off")


func test_smoke_debris_flames_rings_and_scorch_use_real_sprites_and_go() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var made: Array[Node] = [
		Vfx.smoke(holder, Vector3.ZERO, Color.GRAY, 4, 1.0, 0.2),
		Vfx.debris(holder, Vector3.ZERO, Color.WHITE, 3),
		Vfx.flames(holder, Vector3.ZERO, Color.ORANGE, 4, 1.0, 0.2),
		Vfx.ring(holder, Vector3.ZERO, 2.0, Color.CYAN, 0.1),
		Vfx.scorch(holder, Vector3.ZERO, 1.5, 0.1),
	]
	var textures := {
		0: Vfx.SmokeTexture, 1: Vfx.DebrisTexture, 2: Vfx.FlameTexture,
	}
	for i: int in textures:
		var particles := made[i] as CPUParticles3D
		var material := (particles.mesh as QuadMesh).material as StandardMaterial3D
		check(material.albedo_texture == textures[i], "%s is drawn from its sprite sheet" % particles.mesh)
		check(particles.anim_offset_max > 0.0, "each puff or tongue picks its own frame")
	check(((made[3] as MeshInstance3D).material_override as StandardMaterial3D).albedo_texture == Vfx.RingTexture, "the ring is a real shockwave")
	check((made[4] as Decal).texture_albedo == Vfx.ScorchTexture, "the scorch is a decal on the floor")
	var ids := made.map(func(n: Node) -> int: return n.get_instance_id())
	check(await wait_until(func() -> bool: return ids.all(func(id: int) -> bool: return not is_instance_id_valid(id)), 600),
			"every one frees itself")
	holder.queue_free()


func test_torches_burn_with_real_fire_and_smoke() -> void:
	var fire := FlameFx.new()
	add_child(fire)
	check(fire.get_node_or_null(^"Flame") != null, "the shader flame stays as the core")
	var tongues := fire.get_node_or_null(^"Tongues") as CPUParticles3D
	check(tongues != null and ((tongues.mesh as QuadMesh).material as StandardMaterial3D).albedo_texture == Vfx.FlameTexture,
			"fire tongues from the sprite sheet lick through it")
	check(fire.get_node_or_null(^"Smoke") != null, "smoke wisps rise from it")
	fire.queue_free()
	var bare := FlameFx.new()
	bare.tongue_count = 0
	bare.smoke_count = 0
	add_child(bare)
	check(bare.get_node_or_null(^"Tongues") == null and bare.get_node_or_null(^"Smoke") == null, "both can be turned off")
	bare.queue_free()
