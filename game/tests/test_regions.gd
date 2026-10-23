extends "res://tests/framework/test_case.gd"
## The five regions after the catacombs (docs/dungeons/regions.md) and the
## Demons: each level builds and bakes, has its four fights and its boss, and
## opens only after the dungeon before it is cleared.

const REGIONS := ["keep", "forest", "volcano", "temple", "ice"]


func test_every_region_builds_with_four_fights_and_a_boss() -> void:
	for id: String in REGIONS:
		var main := instantiate_main(false, load(Dungeons.scene_path(id)))
		add_child(main)
		await wait_physics_frames(3)
		var level: Level = main.level
		check(level.encounters.size() == 4, "%s has four fights: %d" % [id, level.encounters.size()])
		check(level.world_tint != Color.WHITE, "%s has its own colour cast" % id)
		var region := level.get_node("Navigation") as NavigationRegion3D
		check(region.navigation_mesh.get_polygon_count() > 20, "%s baked its navigation: %d polygons" % [id, region.navigation_mesh.get_polygon_count()])
		var player: Node3D = main.get_node("Player")
		var start := NavigationServer3D.map_get_closest_point(player.get_world_3d().navigation_map, player.global_position)
		check(start.distance_to(Vector3(player.global_position.x, start.y, player.global_position.z)) < 1.0, "%s starts the hero on walkable floor" % id)
		var boss_data: EncounterData = level.encounters[3].data
		var boss: Node = boss_data.waves[0].enemies[0].instantiate()
		check(boss is AshenLord and (boss as AshenLord).display_title.begins_with("THE "), "%s ends with a named boss" % id)
		boss.free()
		check((main.get_node("HUD") as Hud).minimap().rooms().size() == 9, "%s maps its nine rooms and corridors" % id)
		main.free()
		await wait_process_frames(2)


func test_a_regions_fight_raises_its_enemies() -> void:
	var main := instantiate_main(false, load(Dungeons.scene_path("volcano")))
	add_child(main)
	await wait_physics_frames(3)
	var encounter: EncounterController = main.level.encounters[0]
	encounter.start()
	check(await wait_until(func() -> bool: return get_tree().get_nodes_in_group(EnemyController.GROUP).size() >= 4, 240),
			"the first fight's demons rise")
	var kinds := get_tree().get_nodes_in_group(EnemyController.GROUP).map(func(e: Node) -> String: return e.name)
	check(kinds.any(func(n: String) -> bool: return n.begins_with("Demon")), "demons among them: %s" % [kinds])


func test_regions_open_one_after_another() -> void:
	check(Dungeons.is_open(Dungeons.CRYPT, Profile) and not Dungeons.is_open(Dungeons.KEEP, Profile), "only the crypt at first")
	check(Dungeons.lock_reason(Dungeons.KEEP, Profile) == "Clear the catacombs to open", Dungeons.lock_reason(Dungeons.KEEP, Profile))
	Profile.complete_tier(1)
	check(Dungeons.is_open(Dungeons.CATACOMBS, Profile) and not Dungeons.is_open(Dungeons.KEEP, Profile), "the crypt opens the catacombs")
	check(Profile.complete_dungeon(Dungeons.CATACOMBS) and Dungeons.is_open(Dungeons.KEEP, Profile), "the catacombs open the keep")
	check(not Profile.complete_dungeon(Dungeons.CATACOMBS), "a second clear changes nothing")
	for id in [Dungeons.KEEP, Dungeons.FOREST, Dungeons.VOLCANO, Dungeons.TEMPLE]:
		Profile.complete_dungeon(id)
	check(Dungeons.is_open(Dungeons.ICE, Profile), "and so on to the Ice Wastes")
	var saved := Profile.to_dict()
	Profile.reset()
	check(Profile._apply(JSON.parse_string(JSON.stringify(saved))) and Profile.has_cleared(Dungeons.TEMPLE), "the clears are saved")
	saved.erase("cleared_dungeons")
	check(Profile._apply(saved) and Profile.has_cleared(Dungeons.CRYPT) and not Profile.has_cleared(Dungeons.KEEP),
			"an older save with a cleared tier counts the crypt cleared")


func test_every_region_has_a_card_its_materials_and_an_icon() -> void:
	for id: String in REGIONS:
		check(Icons.of(Dungeons.INFO[id].icon) != null, "%s has an icon" % id)
		check(not Dungeons.materials_of(id).is_empty(), "%s drops materials" % id)
		var levels: Vector2i = Dungeons.INFO[id].levels
		check(levels.x < levels.y and levels.y <= Profile.MAX_LEVEL, "%s has a level range: %s" % [id, levels])


func test_demons_fight() -> void:
	add_level(30.0)
	for path in ["res://scenes/enemies/demon.tscn", "res://scenes/enemies/imp.tscn"]:
		var enemy: EnemyController = load(path).instantiate()
		add_child(enemy)
		check(enemy.health.max_health > 0 and enemy.attack != null, "%s is ready to fight" % enemy.name)
		check(enemy.is_in_group(EnemyController.GROUP) and enemy.champion_eligible, "%s can rise as a champion" % enemy.name)
	var demon: EnemyController = get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Demon"))[0]
	check(demon.special_attack != null and demon.special_attack.data.arc_degrees >= 359.0, "the demon has its ground slam")
