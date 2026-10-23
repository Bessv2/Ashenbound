extends "res://tests/framework/test_case.gd"
## Tests for the two looks under comparison (docs/ART_STYLE_TEST.md): the
## setting, restyled materials, effects that never change combat, hit-stop,
## lunges, and the title screen's look buttons.

const CryptScene := preload("res://scenes/dungeon/crypt.tscn")
const SkeletonScene := preload("res://scenes/enemies/skeleton_warrior.tscn")
const WardenScene := preload("res://scenes/player/warden.tscn")
const TitleScene := preload("res://scenes/title.tscn")


func _exit_tree() -> void:
	ArtStyle.override_look = -1
	ArtStyle.clear_cache()
	HitStop.reset()
	Settings.current.art_style = 0
	Profile.save_path = ""
	Profile.reset()


func test_the_look_is_a_saved_setting() -> void:
	var settings := GameSettings.new()
	check(settings.art_style == ArtStyle.Look.GRIM, "look B by default (the owner's choice)")
	settings.art_style = ArtStyle.Look.GRIM
	var config := ConfigFile.new()
	settings.write_to(config)
	var loaded := GameSettings.new()
	loaded.read_from(config)
	check(loaded.art_style == ArtStyle.Look.GRIM, "it round-trips")
	config.set_value(GameSettings.GRAPHICS, "art_style", 9)
	loaded.read_from(config)
	check(loaded.art_style == 2, "out of range is clamped")
	Settings.current.art_style = ArtStyle.Look.HEROIC
	check(ArtStyle.current() == ArtStyle.Look.HEROIC, "the game follows the setting")


func test_characters_and_the_world_are_restyled_per_look() -> void:
	var source: StandardMaterial3D = load("res://resources/materials/warden_model.tres")
	check(ArtStyle.character_material(source, ArtStyle.Look.CLASSIC) == source, "classic leaves it")
	var heroic := ArtStyle.character_material(source, ArtStyle.Look.HEROIC) as ShaderMaterial
	check(heroic.shader == ArtStyle.ToonShader and heroic.next_pass != null, "look A: cel-shaded with an outline")
	check(ArtStyle.character_material(source, ArtStyle.Look.HEROIC) == heroic, "and shared, not rebuilt")
	var grim := ArtStyle.character_material(source, ArtStyle.Look.GRIM) as ShaderMaterial
	check(grim.shader == ArtStyle.GrimShader and grim.get_shader_parameter(&"albedo_texture") == source.albedo_texture,
			"look B: worn and real, on the same texture")
	var cutout: ShaderMaterial = load("res://resources/materials/dungeon_cutout.tres")
	var wall := ArtStyle.world_material(cutout, ArtStyle.Look.GRIM) as ShaderMaterial
	check(wall.shader == ArtStyle.GrimShader and wall.get_shader_parameter(&"cutout") == true,
			"look B's walls keep the see-through hole")
	check(ArtStyle.world_material(cutout, ArtStyle.Look.HEROIC) == cutout, "look A keeps the dungeon")


func test_each_look_builds_a_run_and_its_hits_only_look_different() -> void:
	for look in [ArtStyle.Look.CLASSIC, ArtStyle.Look.HEROIC, ArtStyle.Look.GRIM]:
		ArtStyle.override_look = look
		var main := instantiate_main(false, CryptScene)
		add_child(main)
		await wait_physics_frames(2)
		var hero: PlayerController = main.get_node("Player")
		hero.health.invulnerable = true
		var skeleton: EnemyController = SkeletonScene.instantiate()
		skeleton.position = hero.global_position + Vector3(0, 0, -1.4)
		skeleton.set_physics_process(false)
		main.level.add_child(skeleton)
		await wait_physics_frames(2)
		var before := skeleton.health.current
		hero.attack.try_start(Vector3.FORWARD)
		check(await wait_until(func() -> bool: return skeleton.health.current < before, 120), "look %d: the blow lands" % look)
		check(before - skeleton.health.current == 10, "look %d: for the same 10" % look)
		await wait_physics_frames(20)
		check(Engine.time_scale == 1.0, "look %d: any freeze has ended" % look)
		skeleton.health.apply_damage(1000)
		await wait_physics_frames(10)
		if look == ArtStyle.Look.GRIM:
			check(main.level.get_node("Navigation/Gates/Gatehouse").find_children("*", "MeshInstance3D", true, false).any(
					func(m: MeshInstance3D) -> bool: return m.material_override is ShaderMaterial or m.get_surface_override_material(0) is ShaderMaterial),
					"look B dresses the dungeon")
		main.free()
		await wait_physics_frames(2)


func test_hit_stop_freezes_briefly_and_only_in_the_new_looks() -> void:
	ArtStyle.override_look = ArtStyle.Look.CLASSIC
	HitStop.trigger(get_tree())
	check(Engine.time_scale == 1.0, "classic never freezes")
	ArtStyle.override_look = ArtStyle.Look.HEROIC
	HitStop.trigger(get_tree(), 0.05)
	check(HitStop.is_active() and Engine.time_scale < 0.1, "look A freezes")
	check(await wait_until(func() -> bool: return Engine.time_scale == 1.0, 30), "and resumes on its own")
	HitStop.trigger(get_tree(), 5.0)
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	main.free()
	check(Engine.time_scale == 1.0, "leaving a run always ends a freeze")


func test_attacks_lunge_the_visual_but_never_the_body() -> void:
	ArtStyle.override_look = ArtStyle.Look.GRIM
	add_level(30.0)
	var hero: PlayerController = WardenScene.instantiate()
	add_child(hero)
	await wait_physics_frames(2)
	var start := hero.global_position
	hero.attack.try_start(Vector3.FORWARD)
	var furthest := 0.0
	for i in 20:
		await wait_physics_frames(1)
		furthest = maxf(furthest, -hero.visual.position.z)
	check(furthest > 0.3, "the visual drives forward into the blow: %.2f m" % furthest)
	check(hero.global_position.distance_to(start) < 0.05, "the body stays where it was")
	await wait_physics_frames(30)
	check(hero.visual.position.length() < 0.01, "and it settles back")


func test_the_title_screen_chooses_and_saves_the_look() -> void:
	var title: TitleScreen = TitleScene.instantiate()
	add_child(title)
	title.enter_requested.disconnect(title._go_to_crypt)
	var row := title.find_child("Looks", true, false)
	check(row.has_node("Look0") and row.has_node("Look1") and row.has_node("Look2"), "Classic, Look A and Look B")
	title.choose_look(ArtStyle.Look.GRIM)
	check(Settings.current.art_style == ArtStyle.Look.GRIM, "the choice is the setting")
	var saved := ConfigFile.new()
	check(saved.load(Settings.SETTINGS_PATH) == OK and int(saved.get_value(GameSettings.GRAPHICS, "art_style", 0)) == 2,
			"and it is saved")
	title.choose_look(ArtStyle.Look.CLASSIC)
	title.free()


func test_look_b_lays_photographed_stone_on_the_tiled_floors_and_walls() -> void:
	ArtStyle.override_look = ArtStyle.Look.GRIM
	var main := instantiate_main(false, CryptScene)
	add_child(main)
	await wait_physics_frames(2)
	var tiles: Array[Node] = main.level.find_children("*", "MultiMeshInstance3D", true, false)
	check(tiles.size() > 10, "the crypt's floors and walls are tiled: %d chunks" % tiles.size())
	var dressed: Array[Node] = tiles.filter(func(t: MultiMeshInstance3D) -> bool:
		var material := t.material_override as ShaderMaterial
		return material != null and material.shader == ArtStyle.GrimShader and material.get_shader_parameter(&"use_detail") == true)
	check(dressed.size() == tiles.size(), "every chunk is dressed: %d of %d" % [dressed.size(), tiles.size()])
	var material := (dressed[0] as MultiMeshInstance3D).material_override as ShaderMaterial
	check(material.get_shader_parameter(&"detail_top_albedo") is Texture2D and material.get_shader_parameter(&"detail_side_normal") is Texture2D,
			"with real flagstones on top and rock on the sides")
	main.free()
	await wait_physics_frames(2)
	ArtStyle.override_look = ArtStyle.Look.HEROIC
	main = instantiate_main(false, CryptScene)
	add_child(main)
	await wait_physics_frames(2)
	check(main.level.find_children("*", "MultiMeshInstance3D", true, false).all(func(t: MultiMeshInstance3D) -> bool:
		return not (t.material_override is ShaderMaterial and (t.material_override as ShaderMaterial).shader == ArtStyle.GrimShader)),
			"look A keeps the dungeon as built")
	main.free()
	await wait_physics_frames(2)
