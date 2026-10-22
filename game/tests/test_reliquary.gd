extends "res://tests/framework/test_case.gd"
## Tests for the Reliquary against docs/characters/reliquary.md: the flail,
## Last Benediction (capped heal), the Hallowed Lantern, Martyr's Judgment
## (its health cost and safeguards), zeal below half health, the skill tree,
## and playing the class.

const ReliquaryScene := preload("res://scenes/player/reliquary.tscn")
const DummyScene := preload("res://scenes/enemies/training_dummy.tscn")
const TREE := preload("res://resources/skills/reliquary_tree.tres")

var hero: PlayerController
var bless: BenedictionAbility
var lantern: LanternAbility
var judge: JudgmentAbility


func _ready() -> void:
	add_level(40.0)
	hero = ReliquaryScene.instantiate()
	add_child(hero)
	hero.health.armor = 0
	bless = hero.get_node("Benediction")
	lantern = hero.get_node("Lantern")
	judge = hero.get_node("Judgment")


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


func test_the_reliquary_is_a_sturdy_melee_class() -> void:
	check(hero.health.max_health == 110, "110 health")
	check(not hero.attack is RangedAttack and hero.attack.data.damage == 9, "a 9-damage flail")
	check(bless.display_name == "BLESS" and lantern.display_name == "LANTERN" and judge.display_name == "JUDGE", "three abilities")
	var near := _dummy(Vector3(0, 0, -1.6))
	await wait_physics_frames(2)
	check(hero.attack.try_start(Vector3.FORWARD), "the flail swings")
	check(await wait_until(func() -> bool: return near.health.current < 500, 60) and near.health.current == 491, "for 9")


func test_last_benediction_strikes_around_and_heals_within_its_cap() -> void:
	var close := _dummy(Vector3(0, 0, -3))
	var far := _dummy(Vector3(0, 0, -8))
	await wait_physics_frames(2)
	hero.health.apply_damage(60)
	check(bless.try_activate(Vector3.FORWARD), "it always casts")
	check(close.health.current == 488 and far.health.current == 500, "12 within 5 m, nothing beyond")
	check(bless.last_healed == roundi(110 * 0.15) and hero.health.current == 50 + 17, "heals 15%%: %d" % bless.last_healed)
	bless._heal_scale = 10.0
	check(bless.heal_amount() == roundi(110 * BenedictionAbility.MAX_HEAL_SHARE), "never more than 30%% at once: %d" % bless.heal_amount())


func test_the_lantern_pulses_damage_and_heals_only_in_its_light() -> void:
	var inside := _dummy(Vector3(2, 0, 0))
	var outside := _dummy(Vector3(7, 0, 0))
	await wait_physics_frames(2)
	hero.health.apply_damage(40)
	check(lantern.try_activate(Vector3.FORWARD), "the lantern is set")
	await wait_physics_frames(roundi(2.1 * Engine.physics_ticks_per_second))
	check(inside.health.current == 500 - 2 * 5 and outside.health.current == 500, "two pulses of 5 inside its 4 m: %d" % inside.health.current)
	check(hero.health.current == 70 + 2 * 2, "and 2 per pulse to the hero in its light: %d" % hero.health.current)
	hero.global_position = Vector3(-9, 0, 0)
	var held := hero.health.current
	await wait_physics_frames(roundi(1.1 * Engine.physics_ticks_per_second))
	check(hero.health.current == held, "no heal out of its light")
	await wait_physics_frames(roundi(4.0 * Engine.physics_ticks_per_second))
	check(find_children("HallowedLantern", "HallowedLantern", true, false).is_empty() and inside.health.current == 500 - 6 * 5,
			"six pulses in 6 s, then it is gone: %d" % inside.health.current)


func test_judgment_pays_in_blood_but_never_the_last_drop() -> void:
	var first := _dummy(Vector3(0, 0, -6))
	var beside := _dummy(Vector3(1.5, 0, -6.5))
	await wait_physics_frames(2)
	check(judge.try_activate(Vector3.FORWARD), "it smites")
	check(judge.last_paid == 11 and hero.health.current == 99, "it costs 10%% of max health: %d" % judge.last_paid)
	check(first.health.current == 472 and beside.health.current == 472, "28 to the nearest and those beside it")
	await wait_physics_frames(roundi(6.1 * Engine.physics_ticks_per_second))
	hero.health.current = 22
	check(not judge.try_activate(Vector3.FORWARD) and judge.cooldown_fraction() == 0.0 and hero.health.current == 22,
			"at 20% health or less it is refused, with no cost and no cooldown")
	hero.health.current = 23
	judge.health_cost = 0.5
	check(judge.try_activate(Vector3.FORWARD) and hero.health.current == 1, "a cost never takes the last point")
	first.free()
	beside.free()
	await wait_physics_frames(2)
	hero.health.current = 100
	judge._cooldown_left = 0.0
	check(not judge.try_activate(Vector3.FORWARD) and hero.health.current == 100, "no enemy in reach: no cast, no cost")


func test_zeal_strikes_harder_below_half_health() -> void:
	while Profile.points_available("reliquary") < 5:
		Profile.add_xp(Profile.xp_to_next(Profile.level))
	for i in 5:
		check(Profile.learn(TREE, "blood_oath") == "", "Blood Oath %d" % (i + 1))
	var zeal := MartyrZeal.of(hero)
	check(is_equal_approx(zeal.factor(), 1.0), "no zeal at full health")
	hero.health.apply_damage(60)
	check(is_equal_approx(zeal.factor(), 1.3), "+30%% below half: %s" % zeal.factor())
	await wait_physics_frames(2)
	check(is_equal_approx(hero.attack.bonus_scale, 1.3), "the flail follows")
	check(judge.smite_damage() == roundi(28 * 1.3), "and so does the light: %d" % judge.smite_damage())


func test_the_reliquary_tree_changes_the_kit() -> void:
	while Profile.points_available("reliquary") < 9:
		Profile.add_xp(Profile.xp_to_next(Profile.level))
	for id in ["penitence", "mercy", "mercy", "benediction_mastery", "pale_flame", "lantern_light", "lantern_light", "sanctify", "judgment"]:
		check(Profile.learn(TREE, id) == "", "learn %s" % id)
	check(hero.health.max_health == 120, "Penitence: +10 health")
	check(bless.heal_amount() == roundi(120 * 0.15 * 1.35), "Mercy ×2 and Mastery: +35%% healing: %d" % bless.heal_amount())
	check(judge.smite_damage() == roundi(28 * 1.02 * 1.5), "Pale Flame, Lantern Light ×2, Judgment: %d" % judge.smite_damage())
	check(is_equal_approx(judge.cooldown_scale, 0.96), "Sanctify: cooldowns 4%% shorter")


func test_playing_the_reliquary_swaps_the_hero() -> void:
	hero.free()
	Profile.select_class("reliquary")
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var played: PlayerController = main.get_node("Player")
	check(played.scene_file_path == ReliquaryScene.resource_path, "the Reliquary plays")
	check((main.get_node("HUD").get_node("%CleaveButton") as TouchActionButton).label == "BLESS", "the HUD shows its abilities")
