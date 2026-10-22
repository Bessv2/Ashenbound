extends "res://tests/framework/test_case.gd"
## Tests for the Dreadhunter against docs/characters/dreadhunter.md: the
## crossbow, Deadfall (the snare and its eruption), Charged Shot (a piercing
## line), the Carrion Raven, the skill tree, and playing the class in a run.

const DreadhunterScene := preload("res://scenes/player/dreadhunter.tscn")
const DummyScene := preload("res://scenes/enemies/training_dummy.tscn")
const SkeletonScene := preload("res://scenes/enemies/skeleton_warrior.tscn")
const TREE := preload("res://resources/skills/dreadhunter_tree.tres")

var hunter: PlayerController
var deadfall: DeadfallAbility
var shot: ChargedShotAbility
var raven: RavenAbility


func _ready() -> void:
	add_level(50.0)
	hunter = DreadhunterScene.instantiate()
	add_child(hunter)
	deadfall = hunter.get_node("Deadfall")
	shot = hunter.get_node("ChargedShot")
	raven = hunter.get_node("Raven")


func _exit_tree() -> void:
	Profile.save_path = ""
	Profile.reset()


func _dummy(at: Vector3, health: int = 500) -> TrainingDummy:
	var dummy: TrainingDummy = DummyScene.instantiate()
	dummy.position = at
	add_child(dummy)
	dummy.health.max_health = health
	dummy.health.current = health
	return dummy


## A Skeleton Warrior that stands still unless something slows it (its AI
## off), so a test can count what hits it.
func _skeleton(at: Vector3) -> EnemyController:
	var skeleton: EnemyController = SkeletonScene.instantiate()
	skeleton.position = at
	add_child(skeleton)
	skeleton.health.max_health = 500
	skeleton.health.current = 500
	skeleton.set_physics_process(false)
	return skeleton


func test_the_dreadhunter_shoots_from_range() -> void:
	check(hunter.health.max_health == 90, "90 health")
	check(hunter.abilities.size() == 3 and deadfall.display_name == "SNARE" and shot.display_name == "SHOT"
			and raven.display_name == "RAVEN", "three abilities")
	var far := _dummy(Vector3(-3, 0, 10), 50)
	await wait_physics_frames(2)
	check(hunter.attack is RangedAttack and hunter.attack.try_start(Vector3.FORWARD), "the crossbow fires, facing away")
	check(await wait_until(func() -> bool: return far.health.current < 50, 120), "aim assist sends the bolt to the target 10.4 m behind")
	check(far.health.current == 42, "for 8: %d" % far.health.current)


func test_deadfall_holds_what_stands_in_it_then_erupts() -> void:
	var caught := _skeleton(Vector3(0, 0, -6))
	var beside := _skeleton(Vector3(2, 0, -6))
	var apart := _skeleton(Vector3(7, 0, -6))
	await wait_physics_frames(2)
	check(deadfall.try_activate(Vector3.FORWARD), "the snare is set")
	var trap := deadfall.last_trap
	check(trap != null and trap.global_position.distance_to(Vector3(0, 0, -6)) < 0.01, "under the nearest enemy")
	await wait_physics_frames(2)
	check(caught.speed_multiplier < 0.1 and beside.speed_multiplier < 0.1, "both in its 3 m are held: %s, %s" % [caught.speed_multiplier, beside.speed_multiplier])
	check(is_equal_approx(apart.speed_multiplier, 1.0), "7 m away is free")
	check(caught.health.current == 500, "no damage while it holds")
	await wait_physics_frames(roundi(2.1 * Engine.physics_ticks_per_second))
	check(caught.health.current == 500 - 24 and beside.health.current == 500 - 24, "the eruption: 6 bolts × 4 each: %d" % caught.health.current)
	check(apart.health.current == 500, "nothing outside")
	await wait_physics_frames(roundi(0.6 * Engine.physics_ticks_per_second))
	check(is_equal_approx(caught.speed_multiplier, 1.0) and find_children("DeadfallTrap", "DeadfallTrap", false, false).is_empty(),
			"then the snare is gone and the hold wears off")
	check(caught.health.current == 500 - 24, "it erupts once")


func test_deadfall_with_no_enemy_goes_down_ahead() -> void:
	await wait_physics_frames(2)
	check(deadfall.try_activate(Vector3.RIGHT), "always cast")
	check(deadfall.last_trap.global_position.distance_to(Vector3(4, 0, 0)) < 0.01, "4 m ahead: %s" % deadfall.last_trap.global_position)


func test_charged_shot_draws_then_pierces_a_line() -> void:
	var first := _dummy(Vector3(0, 0, -4))
	var second := _dummy(Vector3(0.3, 0, -9))
	var aside := _dummy(Vector3(3, 0, -7))
	await wait_physics_frames(2)
	check(shot.try_activate(Vector3.FORWARD) and shot.is_busy(), "it draws")
	check(first.health.current == 500, "nothing until it is loosed")
	await wait_physics_frames(roundi(0.55 * Engine.physics_ticks_per_second))
	check(not shot.is_busy() and first.health.current == 476 and second.health.current == 476,
			"both in the line take 24: %d, %d" % [first.health.current, second.health.current])
	check(aside.health.current == 500 and shot.last_hit.size() == 2, "3 m aside is missed")


func test_a_wall_stops_the_charged_shot() -> void:
	var near := _dummy(Vector3(0, 0, -4))
	var behind := _dummy(Vector3(0, 0, -10))
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3, 0.5)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 1.5, -7)
	add_child(wall)
	await wait_physics_frames(2)
	shot.try_activate(Vector3.FORWARD)
	await wait_physics_frames(roundi(0.55 * Engine.physics_ticks_per_second))
	check(near.health.current == 476 and behind.health.current == 500, "the wall stops it: %d, %d" % [near.health.current, behind.health.current])


func test_dodging_cancels_the_draw() -> void:
	var target := _dummy(Vector3(0, 0, -5))
	await wait_physics_frames(2)
	shot.try_activate(Vector3.FORWARD)
	await wait_physics_frames(5)
	Input.action_press(GameplayActions.DODGE)
	await wait_physics_frames(2)
	Input.action_release(GameplayActions.DODGE)
	await wait_physics_frames(roundi(0.6 * Engine.physics_ticks_per_second))
	check(not shot.is_busy() and target.health.current == 500, "no shot after a dodge: %d" % target.health.current)


func test_the_raven_strikes_the_nearest_enemy_until_its_time_is_up() -> void:
	var target := _dummy(Vector3(0, 0, -5))
	_dummy(Vector3(0, 0, -15))
	await wait_physics_frames(2)
	check(raven.try_activate(Vector3.FORWARD) and raven.raven() != null, "the raven comes")
	await wait_physics_frames(roundi(2.5 * Engine.physics_ticks_per_second))
	check(target.health.current == 500 - 3 * 6, "three dives of 6 in 2.5 s: %d" % target.health.current)
	var bird := raven.raven()
	bird.renew()
	check(hunter.get_children().filter(func(c: Node) -> bool: return c is Raven).size() == 1, "one raven at a time")
	await wait_physics_frames(roundi(8.3 * Engine.physics_ticks_per_second))
	check(raven.raven() == null, "gone after 8 s")
	var left := target.health.current
	await wait_physics_frames(60)
	check(target.health.current == left, "and no more dives")


func test_the_raven_leaves_when_the_hero_dies() -> void:
	_dummy(Vector3(0, 0, -5))
	raven.try_activate(Vector3.FORWARD)
	await wait_physics_frames(2)
	hunter.health.apply_damage(1000)
	await wait_physics_frames(3)
	check(raven.raven() == null, "no raven after death")


func test_the_dreadhunter_tree_changes_the_kit() -> void:
	while Profile.points_available("dreadhunter") < 9:
		Profile.add_xp(Profile.xp_to_next(Profile.level))
	for id in ["steady_aim", "drawn_shaft", "drawn_shaft", "snare_craft", "snare_craft", "bramble_spikes",
			"deadfall_mastery", "hunters_bond", "hunters_bond"]:
		check(Profile.learn(TREE, id) == "", "learn %s" % id)
	check(is_equal_approx(deadfall.hold_time, 2.0 * 1.2), "Snare Craft ×2: holds 20%% longer: %s" % deadfall.hold_time)
	check(deadfall.bolt_damage == 5 and deadfall.bolts == 8, "Bramble Spikes and Mastery: 8 bolts of 5: %d × %d" % [deadfall.bolts, deadfall.bolt_damage])
	check(shot.shot_damage() == roundi(24 * 1.3), "Drawn Shaft ×2: +30%%: %d" % shot.shot_damage())
	check(raven.strike_damage() == roundi(6 * 1.2), "Hunter's Bond ×2: +20%%: %d" % raven.strike_damage())


func test_playing_the_dreadhunter_swaps_the_hero() -> void:
	hunter.free()
	Profile.select_class("dreadhunter")
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var hero: PlayerController = main.get_node("Player")
	check(hero.scene_file_path == DreadhunterScene.resource_path, "the Dreadhunter plays")
	check((main.get_node("HUD").get_node("%CleaveButton") as TouchActionButton).label == "SNARE", "the HUD shows its abilities")
	hero.health.apply_damage(1000)
	check((main.get_node("Run") as RunController).result == RunController.Result.DEFEAT, "its death ends the run")
