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
