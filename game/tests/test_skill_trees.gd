extends "res://tests/framework/test_case.gd"
## Tests for XP, levels and skill trees (docs/SKILL_TREES.md, acceptance
## checks 1 to 4).

const WardenScene := preload("res://scenes/player/warden.tscn")
const DummyScene := preload("res://scenes/enemies/training_dummy.tscn")
const WARDEN_TREE := preload("res://resources/skills/warden_tree.tres")
const SAVE := "user://test_skills_profile.json"


func _exit_tree() -> void:
	for path in [SAVE, "user://test_skills_profile.backup.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	Profile.save_path = ""
	Profile.reset()


## Levels the hero up until `points` skill points are free.
func _give_points(points: int) -> void:
	while Profile.points_available(Profile.HERO_CLASS) < points:
		Profile.add_xp(Profile.xp_to_next(Profile.level))


func test_all_six_trees_are_complete() -> void:
	check(SkillTreePanel.TREE_PATHS.size() == 6, "one tree per class of the roster")
	for path in SkillTreePanel.TREE_PATHS:
		var tree: SkillTree = load(path)
		check(tree.validate().is_empty(), "%s: %s" % [tree.class_id, tree.validate()])
		check(tree.branches.size() == 3 and tree.nodes.size() == 15, "%s has 3 branches of 5" % tree.class_id)
		for branch in 3:
			check(tree.nodes.filter(func(n: SkillNode) -> bool: return n.branch == branch).size() == 5, "%s branch %d" % [tree.class_id, branch])
	for path in SkillTreePanel.TREE_PATHS:
		check((load(path) as SkillTree).playable, "%s is playable" % path.get_file())


func test_xp_levels_up_along_the_curve_and_each_level_gives_a_point() -> void:
	var levels: Array[int] = []
	Profile.leveled_up.connect(func(l: int) -> void: levels.append(l))
	check(Profile.add_xp(99) == 0 and Profile.level == 1, "99 XP is not enough")
	check(Profile.add_xp(1) == 1 and Profile.level == 2 and Profile.xp == 0, "100 reaches level 2")
	check(Profile.add_xp(283 + 520 + 10) == 2 and Profile.level == 4 and Profile.xp == 10, "one big gain crosses two levels")
	check(levels == [2, 3, 4], "each level announced once: %s" % [levels])
	check(Profile.points_available(Profile.HERO_CLASS) == 3, "three points at level 4")


func test_learning_needs_a_point_the_requirement_and_room() -> void:
	check(Profile.learn(WARDEN_TREE, "iron_skin") == "No skill points left.", "no points at level 1")
	_give_points(8)
	check(Profile.learn(WARDEN_TREE, "shield_wall").begins_with("Requires"), "Shield Wall needs Iron Skin")
	for i in 5:
		check(Profile.learn(WARDEN_TREE, "iron_skin") == "", "Iron Skin rank %d" % (i + 1))
	check(Profile.learn(WARDEN_TREE, "iron_skin") == "Fully learned.", "five ranks at most")
	check(Profile.learn(WARDEN_TREE, "shield_wall") == "", "now Shield Wall")
	check(Profile.points_available("warden") == 2, "6 of 8 points spent")
	var preview: SkillTree = (load(SkillTreePanel.TREE_PATHS[4]) as SkillTree).duplicate()
	preview.playable = false
	check(Profile.learn(preview, "penitence").contains("not playable"), "a tree marked not playable is read-only")


func test_learned_ranks_change_combat_and_reset_restores_them() -> void:
	add_level(30.0)
	var warden: PlayerController = WardenScene.instantiate()
	add_child(warden)
	var guard: GuardAbility = warden.get_node("Guard")
	var brand: BrandAbility = warden.get_node("Brand")
	var cleave: CleaveAbility = warden.get_node("Cleave")
	_give_points(10)
	for id in ["stalwart", "stalwart", "iron_skin", "shield_wall", "kindling", "searing_brand", "wildfire",
			"bloodied_edge", "heavy_swings"]:
		check(Profile.learn(WARDEN_TREE, id) == "", "learn %s" % id)
	check(warden.health.max_health == 120, "Stalwart ×2: 120 health, got %d" % warden.health.max_health)
	check(warden.health.armor == 6, "Iron Skin: 6 armour")
	check_near(guard.duration, 1.3, 0.0001, "Shield Wall: Guard lasts 1.3 s")
	check(brand.damage_per_tick == 5 and brand.tick_count == 10, "Searing Brand and Wildfire: 5 × 10 ticks")
	# +2% Kindling and +3% Bloodied Edge = +5%; Heavy Swings +15% on Cleave.
	check_near(cleave.attack.damage_scale, 1.05 * 1.15, 0.0001, "Cleave scales with damage and Heavy Swings")
	check_near(warden.attack.damage_scale, 1.05, 0.0001, "the basic attack only with damage")
	Profile.reset_skills("warden")
	check(warden.health.max_health == 100 and warden.health.armor == 0, "reset restores health and armour")
	check_near(guard.duration, 1.0, 0.0001, "and Guard")
	check(brand.damage_per_tick == 4 and brand.tick_count == 8, "and Brand")
	check(Profile.points_available("warden") == 10, "every point refunded")


func test_level_and_skills_survive_a_save_and_old_saves_load() -> void:
	Profile.save_path = SAVE
	_give_points(3)
	Profile.learn(WARDEN_TREE, "stalwart")
	Profile.add_xp(30)
	Profile.save_profile()
	var level: int = Profile.level
	var xp: int = Profile.xp
	Profile.reset()
	check(Profile.load_profile() == OK, "loads")
	check(Profile.level == level and Profile.xp == xp, "level and XP come back")
	check(int(Profile.ranks("warden").get("stalwart", 0)) == 1, "and the learned rank")
	var old := FileAccess.open(SAVE, FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 1, "ash": 7, "claimed": [], "inventory": [], "equipment": {}}))
	old.close()
	check(Profile.load_profile() == OK and Profile.level == 1 and Profile.ash == 7, "a version 1 save loads at level 1")


func test_kills_give_xp_and_the_hud_shows_it() -> void:
	var main := instantiate_main(true)
	add_child(main)
	var encounter: EncounterController = main.get_node("Level/Enemies/Encounter")
	check(await wait_until(func() -> bool: return not encounter.living_enemies().is_empty(), 200), "skeletons rise")
	var skeleton := encounter.living_enemies()[0]
	var health := Health.of(skeleton)
	health.invulnerable = false
	health.apply_damage(1000)
	check(Profile.xp == 10, "a Skeleton Warrior gives 10 XP: %d" % Profile.xp)
	var bar: ProgressBar = main.get_node("HUD").get_node("%XpBar")
	check(bar.max_value == 100, "the XP bar's span: %s" % bar.max_value)
	check(await wait_until(func() -> bool: return bar.value == 10, 120), "the XP bar fills to 10: %s" % bar.value)


func test_the_skill_screen_learns_and_pauses() -> void:
	_give_points(1)
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var panel: SkillTreePanel = main.get_node("Skills")
	main.get_node("HUD").skills_requested.emit()
	check(panel.visible and get_tree().paused, "the tree opens and the game waits")
	panel.select("stalwart")
	check(panel.learn_selected() == "", "Learn spends the point")
	check(int(Profile.ranks("warden").get("stalwart", 0)) == 1, "Stalwart rank 1")
	var hero: PlayerController = main.get_node("Player")
	check(hero.health.max_health == 110, "the hero follows: %d" % hero.health.max_health)
	panel.show_tree(4)
	panel.select("penitence")
	check(panel.learn_selected() == "" and int(Profile.ranks("reliquary").get("penitence", 0)) == 1,
			"another class's tree spends that class's own points")
	panel.close_requested.emit()
	check(not panel.visible and not get_tree().paused, "closing resumes")
