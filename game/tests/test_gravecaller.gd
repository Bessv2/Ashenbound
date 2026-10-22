extends "res://tests/framework/test_case.gd"
## Tests for the Gravecaller against docs/characters/gravecaller.md: the soul
## bolt, Raise the Forsaken (count, lifetime, targets, cleanup), Wraith Swarm
## (hits and marks), Soul Harvest (souls from nearby deaths), the skill tree,
## and playing the class.

const GravecallerScene := preload("res://scenes/player/gravecaller.tscn")
const DummyScene := preload("res://scenes/enemies/training_dummy.tscn")
const SkeletonScene := preload("res://scenes/enemies/skeleton_warrior.tscn")
const TREE := preload("res://resources/skills/gravecaller_tree.tres")

var hero: PlayerController
var raise: RaiseForsakenAbility
var wraiths: WraithSwarmAbility
var harvest: SoulHarvestAbility


func _ready() -> void:
	add_level(50.0)
	hero = GravecallerScene.instantiate()
	add_child(hero)
	raise = hero.get_node("RaiseForsaken")
	wraiths = hero.get_node("WraithSwarm")
	harvest = hero.get_node("SoulHarvest")


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


func test_the_gravecaller_casts_from_range() -> void:
	check(hero.health.max_health == 85 and hero.attack is RangedAttack, "85 health, a ranged soul bolt")
	check(raise.display_name == "RAISE" and wraiths.display_name == "WRAITHS" and harvest.display_name == "HARVEST", "three abilities")
	var far := _dummy(Vector3(3, 0, 7), 50)
	await wait_physics_frames(2)
	check(hero.attack.try_start(Vector3.FORWARD), "the bolt flies, facing away")
	check(await wait_until(func() -> bool: return far.health.current < 50, 120) and far.health.current == 43, "aim assist finds the target: 7")


func test_raised_skeletons_fight_for_the_hero_then_crumble() -> void:
	var target := _dummy(Vector3(0, 0, -6))
	await wait_physics_frames(2)
	check(raise.try_activate(Vector3.FORWARD) and raise.living().size() == 2, "two skeletons rise")
	var minion := raise.living()[0]
	check(minion.health.max_health == 40 and minion.collision_layer == 2, "40 health each, on the hero's side")
	check(await wait_until(func() -> bool: return target.health.current < 500, 240), "they walk to the enemy and strike it")
	check(get_tree().get_nodes_in_group(PlayerController.GROUP).size() == 1, "enemies never take them for the hero")
	raise._cooldown_left = 0.0
	var first_pair := raise.living()
	check(raise.try_activate(Vector3.FORWARD) and raise.living().size() == 2, "casting again raises a fresh pair")
	await wait_physics_frames(2)
	check(first_pair.all(func(m: Variant) -> bool: return not is_instance_valid(m)), "the old pair is gone: never more than two")
	await wait_physics_frames(roundi(15.2 * Engine.physics_ticks_per_second))
	check(raise.living().is_empty() and hero.find_children("*", "Minion", false, false).is_empty(), "they crumble after 15 s")


func test_raised_skeletons_go_when_the_hero_dies() -> void:
	await wait_physics_frames(2)
	raise.try_activate(Vector3.FORWARD)
	var pair := raise.living()
	hero.health.apply_damage(1000)
	await wait_physics_frames(3)
	check(pair.all(func(m: Variant) -> bool: return not is_instance_valid(m)), "none outlive the hero")


func test_a_skeleton_can_be_destroyed() -> void:
	await wait_physics_frames(2)
	raise.try_activate(Vector3.FORWARD)
	var minion := raise.living()[0]
	minion.health.apply_damage(1000)
	await wait_physics_frames(2)
	check(raise.living().size() == 1, "one falls, one stands")


func test_wraiths_strike_the_nearest_enemies_and_mark_them() -> void:
	var near := _dummy(Vector3(0, 0, -3))
	var middle := _dummy(Vector3(4, 0, 0))
	var far := _dummy(Vector3(0, 0, 9))
	var out := _dummy(Vector3(-14, 0, 0))
	await wait_physics_frames(2)
	check(wraiths.try_activate(Vector3.FORWARD), "the wraiths fly")
	check(near.health.current == 491 and middle.health.current == 491 and far.health.current == 491, "9 to each of the three nearest")
	check(out.health.current == 500, "nothing beyond 10 m")
	check(Marked.of(near) != null and is_equal_approx(near.health.damage_multiplier, 1.2), "marked to take 20%% more")
	near.health.apply_damage(10)
	check(near.health.current == 491 - 12, "and it does: %d" % near.health.current)
	for dummy in [near, middle, far]:
		dummy.free()
	await wait_physics_frames(2)
	wraiths._cooldown_left = 0.0
	check(not wraiths.try_activate(Vector3.FORWARD) and wraiths.cooldown_fraction() == 0.0, "no enemy in reach: no cast")


func test_one_enemy_takes_every_wraith() -> void:
	var lone := _dummy(Vector3(0, 0, -3))
	await wait_physics_frames(2)
	wraiths.try_activate(Vector3.FORWARD)
	check(lone.health.current == 500 - 9 - 2 * 11 and wraiths.last_hits.size() == 3,
			"three wraiths, the later two on a marked target: %d" % lone.health.current)


func test_souls_come_from_nearby_deaths_and_are_spent_at_once() -> void:
	check(not harvest.try_activate(Vector3.FORWARD) and harvest.cooldown_fraction() == 0.0, "no soul: no cast")
	var near: Array[EnemyController] = []
	for i in 3:
		var skeleton: EnemyController = SkeletonScene.instantiate()
		skeleton.position = Vector3(-3.0 + 3.0 * i, 0, -5)
		add_child(skeleton)
		skeleton.set_physics_process(false)
		near.append(skeleton)
	var distant: EnemyController = SkeletonScene.instantiate()
	distant.position = Vector3(0, 0, -16)
	add_child(distant)
	distant.set_physics_process(false)
	await wait_physics_frames(2)
	for skeleton in near:
		skeleton.health.apply_damage(1000)
	distant.health.apply_damage(1000)
	await wait_physics_frames(2)
	check(harvest.souls == 3 and harvest.badge_text() == "3", "three souls from deaths within 10 m, none from 16 m")
	var victim := _dummy(Vector3(2, 0, 0))
	await wait_physics_frames(2)
	hero.health.apply_damage(30)
	check(harvest.try_activate(Vector3.FORWARD), "harvest")
	check(victim.health.current == 500 - 18 and harvest.last_healed == 9, "6 × 3 souls to those around, 3 × 3 healed")
	check(harvest.souls == 0, "the souls are spent")


func test_the_gravecaller_tree_changes_the_kit() -> void:
	while Profile.points_available("gravecaller") < 10:
		Profile.add_xp(Profile.xp_to_next(Profile.level))
	for id in ["grave_discipline", "grave_discipline", "mass_grave", "restless_dead", "restless_dead", "chill_touch",
			"phantom_swarm", "reaping", "soul_well", "soul_well"]:
		check(Profile.learn(TREE, id) == "", "learn %s" % id)
	check(raise.summon_count() == 3 and raise.summon_health() == roundi(40 * 1.16), "Mass Grave and Discipline: 3 of 46 health")
	check(is_equal_approx(raise.summon_damage_scale(), 1.1), "Restless Dead ×2: +10%% summon damage")
	check(wraiths.wraith_count() == 4 and wraiths.wraith_damage() == roundi(9 * 1.1), "Phantom Swarm: 4 wraiths")
	harvest.souls = 2
	check(harvest.harvest_damage() == roundi(6 * 2 * 1.3), "Soul Well ×2: souls worth 30%% more: %d" % harvest.harvest_damage())


func test_playing_the_gravecaller_swaps_the_hero_and_shows_souls() -> void:
	hero.free()
	Profile.select_class("gravecaller")
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var played: PlayerController = main.get_node("Player")
	check(played.scene_file_path == GravecallerScene.resource_path, "the Gravecaller plays")
	var hud: Hud = main.get_node("HUD")
	check((hud.get_node("%CleaveButton") as TouchActionButton).label == "RAISE", "the HUD shows its abilities")
	var harvest_button := hud.get_node("%BrandButton") as TouchActionButton
	(played.get_node("SoulHarvest") as SoulHarvestAbility).souls = 4
	await wait_process_frames(2)
	check(harvest_button.badge == "4", "the HARVEST button counts the souls: %s" % harvest_button.badge)
	check((hud.get_node("%GuardButton") as TouchActionButton).badge == "", "other buttons have no badge")
