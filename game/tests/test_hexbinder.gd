extends "res://tests/framework/test_case.gd"
## Tests for the Hexbinder against docs/characters/hexbinder.md: Hex Bolt,
## Black Testament (curses), Grasp of the Grave (slow), Unmake (detonation),
## the skill tree, and playing the class in a run.

const HexbinderScene := preload("res://scenes/player/hexbinder.tscn")
const DummyScene := preload("res://scenes/enemies/training_dummy.tscn")
const SkeletonScene := preload("res://scenes/enemies/skeleton_warrior.tscn")
const TREE := preload("res://resources/skills/hexbinder_tree.tres")

var hexbinder: PlayerController
var testament: BlackTestamentAbility
var grasp: GraspAbility
var unmake: UnmakeAbility


func _ready() -> void:
	add_level(40.0)
	hexbinder = HexbinderScene.instantiate()
	add_child(hexbinder)
	testament = hexbinder.get_node("BlackTestament")
	grasp = hexbinder.get_node("Grasp")
	unmake = hexbinder.get_node("Unmake")


func _exit_tree() -> void:
	Profile.save_path = ""
	Profile.reset()


## A training target with plenty of health, so curses and bursts can be
## counted without it dying.
func _dummy(at: Vector3, health: int = 500) -> TrainingDummy:
	var dummy: TrainingDummy = DummyScene.instantiate()
	dummy.position = at
	add_child(dummy)
	dummy.health.max_health = health
	dummy.health.current = health
	return dummy


func _curse_of(body: Node) -> Burning:
	for child in body.get_children():
		if child is Burning and child.name == BlackTestamentAbility.CURSE and not child.is_queued_for_deletion():
			return child
	return null


func test_the_hexbinder_casts_from_range() -> void:
	check(hexbinder.health.max_health == 80, "80 health: the most fragile so far")
	check(hexbinder.abilities.size() == 3 and testament.display_name == "CURSE" and grasp.display_name == "GRASP"
			and unmake.display_name == "UNMAKE", "three abilities")
	var far := _dummy(Vector3(3, 0, 8), 50)
	await wait_physics_frames(2)
	check(hexbinder.attack is RangedAttack and hexbinder.attack.try_start(Vector3.FORWARD), "Hex Bolt starts, facing away")
	check(await wait_until(func() -> bool: return far.health.current < 50, 120), "aim assist sends it to the target behind, 8.5 m away")
	check(far.health.current == 41, "for 9: %d" % far.health.current)


func test_black_testament_curses_the_group_around_the_nearest_enemy() -> void:
	var first := _dummy(Vector3(0, 0, -6))
	var near := _dummy(Vector3(1.5, 0, -7.5))
	var apart := _dummy(Vector3(6, 0, -6))
	await wait_physics_frames(2)
	check(testament.try_activate(Vector3.FORWARD), "cast on the nearest")
	check(first.health.current == 494 and near.health.current == 494, "the first hit, 6 each: %d, %d" % [first.health.current, near.health.current])
	check(_curse_of(first) != null and _curse_of(near) != null, "both cursed")
	check(_curse_of(apart) == null and apart.health.current == 500, "6 m away is outside the 3.5 m curse")
	await wait_physics_frames(roundi(1.05 * Engine.physics_ticks_per_second))
	check(first.health.current == 494 - 2 * 3, "the curse ticks 3 every 0.5 s: %d" % first.health.current)
	Burning.apply(first.health, 1, 0.5, 20)
	check(_curse_of(first) != null and first.get_children().filter(func(c: Node) -> bool: return c is Burning).size() == 2,
			"a burn does not replace the curse")


func test_black_testament_needs_a_target() -> void:
	_dummy(Vector3(0, 0, -20))
	await wait_physics_frames(2)
	check(not testament.try_activate(Vector3.FORWARD) and testament.cooldown_fraction() == 0.0, "nothing within 11 m: no cast, no cooldown")


func test_unmake_detonates_what_the_curses_had_left() -> void:
	var first := _dummy(Vector3(0, 0, -5))
	var second := _dummy(Vector3(1, 0, -6))
	var plain := _dummy(Vector3(-6, 0, -1))
	await wait_physics_frames(2)
	check(not unmake.try_activate(Vector3.FORWARD) and unmake.cooldown_fraction() == 0.0, "no curse in reach: no cast, no cooldown")
	testament.try_activate(Vector3.FORWARD)
	await wait_physics_frames(roundi(1.05 * Engine.physics_ticks_per_second))
	var left := _curse_of(first).ticks_left
	var before := first.health.current
	check(unmake.try_activate(Vector3.FORWARD), "Unmake")
	var burst := roundi(3 * left * 1.5)
	check(first.health.current == before - burst, "the rest of the curse ×1.5 at once: %d → %d (%d ticks left)" % [before, first.health.current, left])
	check(unmake.last_damage == 2 * burst, "both cursed bodies burst: %d" % unmake.last_damage)
	await wait_physics_frames(1)
	check(_curse_of(first) == null and _curse_of(second) == null, "the curses are spent")
	check(plain.health.current == 500 and _curse_of(plain) == null, "an uncursed target in reach is not hit")
	var after := first.health.current
	await wait_physics_frames(roundi(1.1 * Engine.physics_ticks_per_second))
	check(first.health.current == after, "no more ticks after the burst")


func test_grasp_hurts_and_slows_what_is_close() -> void:
	var skeleton: EnemyController = SkeletonScene.instantiate()
	skeleton.position = Vector3(0, 0, -2.5)
	add_child(skeleton)
	var far := _dummy(Vector3(0, 0, -7), 50)
	await wait_physics_frames(2)
	var full := skeleton.health.current
	check(grasp.try_activate(Vector3.FORWARD), "Grasp always casts")
	check(skeleton.health.current == full - 6 and far.health.current == 50, "6 within 4 m, nothing beyond")
	check(Slowed.of(skeleton) != null and is_equal_approx(skeleton.speed_multiplier, 0.4), "slowed to 40%%: %s" % skeleton.speed_multiplier)
	await wait_physics_frames(roundi(2.7 * Engine.physics_ticks_per_second))
	check(Slowed.of(skeleton) == null and is_equal_approx(skeleton.speed_multiplier, 1.0), "the slow ends and leaves nothing behind")


func test_the_hexbinder_tree_changes_the_kit() -> void:
	while Profile.points_available("hexbinder") < 10:
		Profile.add_xp(Profile.xp_to_next(Profile.level))
	for id in ["withering_word", "withering_word", "spreading_blight", "spreading_blight", "gathering_storm", "volatile_hex",
			"soul_leech", "hungering_souls", "hex_mastery", "black_testament_mastery"]:
		check(Profile.learn(TREE, id) == "", "learn %s" % id)
	check(testament.tick_count == 14, "Withering Word ×2: 12 → 14 ticks, got %d" % testament.tick_count)
	check(testament.damage_per_tick == 4, "Spreading Blight ×2: 3 → 4 per tick, got %d" % testament.damage_per_tick)
	check(is_equal_approx(testament.radius, 3.5 * 1.1) and testament.hit == 7, "Black Testament Mastery: wider, harder first hit")
	check(is_equal_approx(unmake.multiplier, 1.5 * 1.15), "Volatile Hex: a bigger burst: %s" % unmake.multiplier)
	hexbinder.health.apply_damage(40)
	var target := _dummy(Vector3(0, 0, -4))
	await wait_physics_frames(2)
	testament.try_activate(Vector3.FORWARD)
	var hurt := hexbinder.health.current
	unmake.try_activate(Vector3.FORWARD)
	check(unmake.last_healed == roundi(unmake.last_damage * 0.1) and hexbinder.health.current == hurt + unmake.last_healed,
			"Hungering Souls heals 10%% of the burst: %d of %d" % [unmake.last_healed, unmake.last_damage])
	check(target.health.current < 500, "and the burst landed")


func test_playing_the_hexbinder_swaps_the_hero() -> void:
	hexbinder.free()
	Profile.select_class("hexbinder")
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var hero: PlayerController = main.get_node("Player")
	check(hero.scene_file_path == HexbinderScene.resource_path, "the Hexbinder plays")
	check((main.get_node("HUD").get_node("%CleaveButton") as TouchActionButton).label == "CURSE", "the HUD shows its abilities")
	hero.health.apply_damage(1000)
	check((main.get_node("Run") as RunController).result == RunController.Result.DEFEAT, "its death ends the run")
