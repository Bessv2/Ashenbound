extends "res://tests/framework/test_case.gd"
## Tests for the Reaver against docs/characters/reaver.md: Veil Rend (dash,
## cut, mark), Fan of Blades, Hemorrhage, the skill tree, and playing the
## class in a run.

const ReaverScene := preload("res://scenes/player/reaver.tscn")
const DummyScene := preload("res://scenes/enemies/training_dummy.tscn")
const REAVER_TREE := preload("res://resources/skills/reaver_tree.tres")

var reaver: PlayerController
var veil: VeilRendAbility
var fan: CleaveAbility
var bleed: BleedAbility


func _ready() -> void:
	add_level(40.0)
	reaver = ReaverScene.instantiate()
	add_child(reaver)
	veil = reaver.get_node("VeilRend")
	fan = reaver.get_node("Fan")
	bleed = reaver.get_node("Hemorrhage")


func _exit_tree() -> void:
	Profile.save_path = ""
	Profile.reset()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	Input.action_release(action)


func _dummy(at: Vector3) -> TrainingDummy:
	var dummy: TrainingDummy = DummyScene.instantiate()
	dummy.position = at
	add_child(dummy)
	return dummy


func test_the_reaver_is_quick_and_fragile() -> void:
	check(reaver.health.max_health == 85, "85 health against the Warden's 100")
	check(reaver.stats.move_speed > 6.0 and reaver.dodge.data.cooldown < 0.9, "faster, and dodges more often")
	check(reaver.abilities.size() == 3 and veil.display_name == "VEIL" and fan.display_name == "FAN" and bleed.display_name == "BLEED",
			"three abilities")
	var target := _dummy(Vector3(0, 0, -1.4))
	await wait_physics_frames(2)
	check(reaver.attack.try_start(Vector3.FORWARD), "twin slash")
	check(await wait_until(func() -> bool: return target.health.current < 50, 60), "lands")
	check(target.health.current == 43, "for 7: %d" % target.health.current)


func test_veil_rend_dashes_through_cuts_and_marks_what_it_passes() -> void:
	var first := _dummy(Vector3(0, 0, -2))
	var second := _dummy(Vector3(0.6, 0, -4.5))
	var aside := _dummy(Vector3(3.5, 0, -3))
	await wait_physics_frames(2)
	var start := reaver.global_position
	var hurt := [false]
	reaver.health.damaged.connect(func(_a: int, _r: int) -> void: hurt[0] = true)
	_tap(GameplayActions.ABILITY_1)
	await wait_physics_frames(3)
	check(veil.is_busy() and reaver.health.invulnerable, "dashing, unhurt")
	reaver.health.apply_damage(30)
	check(not hurt[0], "a hit during the dash does nothing")
	check(await wait_until(func() -> bool: return not veil.is_busy(), 60), "the dash ends")
	await wait_physics_frames(1)
	var travelled := (reaver.global_position - start) * Vector3(1, 0, 1)
	check_near(travelled.length(), 6.0, 0.4, "about 6 m through the enemies: %.2f" % travelled.length())
	check(not reaver.health.invulnerable and reaver.collision_mask == 5, "vulnerable and solid again")
	check(first.health.current == 36 and second.health.current == 36, "both on the path cut for 14: %d, %d" % [first.health.current, second.health.current])
	check(aside.health.current == 50, "the one aside untouched")
	check(Marked.of(first) != null and Marked.of(second) != null and Marked.of(aside) == null, "the cut ones are marked")
	first.health.apply_damage(20)
	check(first.health.current == 36 - 25, "a marked target takes +25%%: %d" % first.health.current)
	await wait_physics_frames(roundi(4.2 * Engine.physics_ticks_per_second))
	check(Marked.of(second) == null and is_equal_approx(second.health.damage_multiplier, 1.0), "the mark fades and takes its bonus with it")


func test_a_dodge_during_veil_rend_keeps_its_own_invulnerability() -> void:
	await wait_physics_frames(2)
	check(veil.try_activate(Vector3.FORWARD), "dashing")
	await wait_physics_frames(2)
	_tap(GameplayActions.DODGE)
	await wait_physics_frames(2)
	check(reaver.dodge.is_active() and not veil.is_busy(), "the dodge cancelled the dash")
	check(reaver.health.invulnerable, "and is still unhurt")
	check(reaver.collision_mask == 5, "solid again")


func test_fan_of_blades_hits_all_around() -> void:
	var ahead := _dummy(Vector3(0, 0, -1.8))
	var behind := _dummy(Vector3(0, 0, 1.8))
	var far := _dummy(Vector3(0, 0, 3.5))
	await wait_physics_frames(2)
	_tap(GameplayActions.ABILITY_2)
	await wait_physics_frames(40)
	check(ahead.health.current == 38 and behind.health.current == 38, "12 to each side: %d, %d" % [ahead.health.current, behind.health.current])
	check(far.health.current == 50, "out of reach untouched")


func test_hemorrhage_bleeds_alongside_a_burn() -> void:
	var target := _dummy(Vector3(0, 0, -2))
	await wait_physics_frames(2)
	Burning.apply(target.health, 1, 0.5, 20)
	check(bleed.try_activate(Vector3.FORWARD), "bleeds the nearest")
	var effects := target.get_children().filter(func(c: Node) -> bool: return c is Burning).map(func(c: Node) -> String: return c.name)
	check(effects.has("Burning") and effects.has("Bleeding"), "burning and bleeding at once: %s" % [effects])
	var far := _dummy(Vector3(0, 0, 8))
	target.free()
	await wait_physics_frames(int(bleed.cooldown * Engine.physics_ticks_per_second) + 2)
	check(not bleed.try_activate(Vector3.FORWARD) and far.health.current == 50, "nothing within 2.8 m: no bleed, no cooldown")


func test_the_reaver_tree_changes_the_kit() -> void:
	while Profile.points_available("reaver") < 9:
		Profile.add_xp(Profile.xp_to_next(Profile.level))
	for id in ["open_veins", "hemorrhage", "hemorrhage", "light_feet", "phantom_step", "flanker", "veil_rend_mastery",
			"mark_for_death", "mark_for_death"]:
		check(Profile.learn(REAVER_TREE, id) == "", "learn %s" % id)
	check(bleed.damage_per_tick == 7, "Hemorrhage ×2: 5 × 1.3 → 7 per tick, got %d" % bleed.damage_per_tick)
	var stats: CharacterStats = reaver.get_node("Stats")
	check(stats.value("dash_cooldown_pct") > 0 and veil.cooldown_scale < 1.0, "Phantom Step shortens Veil Rend: %.2f" % veil.cooldown_scale)
	var target := _dummy(Vector3(0, 0, -2))
	await wait_physics_frames(2)
	veil.try_activate(Vector3.FORWARD)
	await wait_until(func() -> bool: return not veil.is_busy(), 60)
	await wait_physics_frames(1)
	var mark := Marked.of(target)
	check(mark != null and is_equal_approx(mark.bonus, 0.25 + 2 * stats.value("mark_damage_pct") / 200.0), "Mark for Death adds to the mark: %s" % (mark.bonus if mark else -1.0))
	check(target.health.current < 50 - 14, "Open Veins and Veil Rend Mastery raise the cut: %d" % target.health.current)


func test_playing_the_reaver_swaps_the_hero_for_the_run() -> void:
	reaver.free()
	Profile.select_class("reaver")
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var hero: PlayerController = main.get_node("Player")
	check(hero.scene_file_path == ReaverScene.resource_path, "the Reaver plays")
	check(get_tree().get_nodes_in_group(PlayerController.GROUP).size() == 1, "one hero only")
	check((main.get_node("CameraRig") as IsometricCameraRig).target == hero, "the camera follows it")
	var hud := main.get_node("HUD")
	check((hud.get_node("%CleaveButton") as TouchActionButton).label == "VEIL", "the HUD shows its abilities")
	hero.health.apply_damage(1000)
	check((main.get_node("Run") as RunController).result == RunController.Result.DEFEAT, "its death ends the run")


func test_the_skill_screen_offers_to_play_another_class() -> void:
	reaver.free()
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var panel: SkillTreePanel = main.get_node("Skills")
	var chosen: Array[String] = []
	# Main would start a new run; here only the request is checked.
	panel.class_chosen.disconnect(main.play_class)
	panel.class_chosen.connect(func(id: String) -> void: chosen.append(id))
	main.get_node("HUD").skills_requested.emit()
	check(panel.current_tree().class_id == "warden", "opens on the class played")
	panel.show_tree(1)
	var play: Button = panel.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Play Reaver")[0]
	check(play.visible, "Play Reaver is offered")
	play.pressed.emit()
	check(chosen == ["reaver"], "and asks for the Reaver")
	panel.show_tree(0)
	check(not play.visible, "not for the class being played")
	panel.close_requested.emit()
	Profile.select_class("nobody")
	check(main.hero_class_of(Profile) == "warden", "an unknown class plays the Warden")
