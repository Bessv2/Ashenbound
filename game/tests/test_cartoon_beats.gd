extends "res://tests/framework/test_case.gd"
## Look B's tone (owner, 2026-10-23): softer surfaces, still dark, with
## cartoon beats that change the pace. Visual only.


func before_look_b() -> void:
	ArtStyle.override_look = ArtStyle.Look.GRIM
	ArtStyle.clear_cache()


func test_look_b_surfaces_are_soft() -> void:
	before_look_b()
	var source := StandardMaterial3D.new()
	source.albedo_texture = preload("res://assets/third_party/kaykit/dungeon/wall_dungeon_texture.png")
	var world := ArtStyle.world_material(source, ArtStyle.Look.GRIM) as ShaderMaterial
	check(float(world.get_shader_parameter(&"relief")) <= 0.5, "gentle relief")
	check(float(world.get_shader_parameter(&"grain")) <= 0.5, "faint grain")
	check(float(world.get_shader_parameter(&"detail_relief")) <= 0.5 and float(world.get_shader_parameter(&"detail_strength")) <= 0.6,
			"the photographs at half strength")
	check(float(world.get_shader_parameter(&"wet_shine")) <= 0.6, "damp, not glittering")
	var base := Environment.new()
	base.adjustment_contrast = 1.0
	check(ArtStyle.environment_for(base).adjustment_contrast <= 1.05, "a softer contrast")


func test_a_slow_motion_beat_eases_back() -> void:
	before_look_b()
	HitStop.slow_motion(get_tree(), 0.5, 0.25)
	check_near(Engine.time_scale, 0.25, 0.001, "the game slows")
	await get_tree().create_timer(0.3, true, false, true).timeout
	check(Engine.time_scale > 0.25 and Engine.time_scale < 1.0, "and is easing back: %.2f" % Engine.time_scale)
	await get_tree().create_timer(0.3, true, false, true).timeout
	check_near(Engine.time_scale, 1.0, 0.001, "full speed again")


func test_the_classic_look_never_slows() -> void:
	ArtStyle.override_look = ArtStyle.Look.CLASSIC
	HitStop.slow_motion(get_tree(), 0.5, 0.25)
	check_near(Engine.time_scale, 1.0, 0.001, "no beat in the classic look")


func test_the_dead_are_knocked_flying_while_the_body_stays() -> void:
	before_look_b()
	add_level(20.0)
	var hero: PlayerController = load("res://scenes/player/warden.tscn").instantiate()
	add_child(hero)
	var enemy: EnemyController = load("res://scenes/enemies/skeleton_warrior.tscn").instantiate()
	add_child(enemy)
	enemy.global_position = Vector3(0, 0, -3)
	await wait_physics_frames(2)
	var start := enemy.global_position
	var visual := enemy.visual
	enemy.health.apply_damage(10000)
	await wait_physics_frames(15)
	check(visual.position.y > 0.5, "flung up: %.2f m" % visual.position.y)
	check(visual.position.z < -0.3, "away from the hero: %s" % visual.position)
	check(enemy.global_position.distance_to(start) < 0.05, "the body itself stays where it fell")
	await wait_physics_frames(40)
	check(visual.scale.length() < 0.2, "and pops away: %s" % visual.scale)


func test_a_wind_up_stretches_the_model() -> void:
	before_look_b()
	add_level(20.0)
	var enemy: EnemyController = load("res://scenes/enemies/fallen_knight.tscn").instantiate()
	add_child(enemy)
	await wait_physics_frames(2)
	var model := enemy.visual.get_node("Model") as Node3D
	var base := model.scale
	enemy.attack.try_start(Vector3.FORWARD)
	await wait_physics_frames(int(enemy.attack.data.windup * 60 * 0.6))
	check(absf(model.scale.y) > absf(base.y) * 1.08, "stretched tall in the wind-up: %.2f vs %.2f" % [model.scale.y, base.y])
	await wait_physics_frames(90)
	check(model.scale.is_equal_approx(base) or model.scale.distance_to(base) < 0.05, "and back to shape")
