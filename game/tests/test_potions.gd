extends "res://tests/framework/test_case.gd"
## Tests for health potions (docs/CHAMPIONS.md#health-potions): drinking,
## the cooldown, refills from kills, the HUD button and the end of a run.

const SkeletonScene := preload("res://scenes/enemies/skeleton_warrior.tscn")
const KnightScene := preload("res://scenes/enemies/fallen_knight.tscn")


func _exit_tree() -> void:
	GameplayActions.release_all()
	Profile.save_path = ""
	Profile.reset()


func _main() -> Node3D:
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	return main


func test_a_potion_heals_a_third_and_waits_before_the_next() -> void:
	var main: Node3D = await _main()
	var belt: PotionBelt = main.get_node("Potions")
	var hero: PlayerController = main.get_node("Player")
	check(belt.charges == 3 and belt.health == hero.health, "a full belt of three for the hero")
	check(belt.drink() == 0 and belt.charges == 3, "none is wasted at full health")
	hero.health.apply_damage(80)
	var expected := ceili(hero.health.max_health * PotionBelt.HEAL_SHARE)
	check(belt.drink() == expected and belt.charges == 2, "heals %d, one charge spent" % expected)
	check(belt.drink() == 0 and belt.charges == 2, "not again right away")
	await wait_physics_frames(roundi(PotionBelt.COOLDOWN * Engine.physics_ticks_per_second) + 2)
	check(belt.drink() > 0 and belt.charges == 1, "again after the cooldown")


func test_the_potion_key_drinks_once_per_press() -> void:
	var main: Node3D = await _main()
	var belt: PotionBelt = main.get_node("Potions")
	var hero: PlayerController = main.get_node("Player")
	hero.health.apply_damage(90)
	Input.action_press(GameplayActions.POTION)
	await wait_physics_frames(roundi(1.5 * Engine.physics_ticks_per_second))
	check(belt.charges == 2, "held down, it drinks once: %d left" % belt.charges)
	Input.action_release(GameplayActions.POTION)
	await wait_physics_frames(2)
	Input.action_press(GameplayActions.POTION)
	await wait_physics_frames(2)
	Input.action_release(GameplayActions.POTION)
	check(belt.charges == 1, "pressed again, another: %d left" % belt.charges)


func test_kills_refill_the_belt() -> void:
	var main: Node3D = await _main()
	var belt: PotionBelt = main.get_node("Potions")
	var skeleton: EnemyController = SkeletonScene.instantiate()
	add_child(skeleton)
	belt.on_kill(skeleton)
	check(belt.charges == 3 and belt.kills_toward_charge == 0, "a full belt does not bank kills")
	belt.charges = 1
	for i in PotionBelt.KILLS_PER_CHARGE - 1:
		belt.on_kill(skeleton)
	check(belt.charges == 1 and belt.kills_toward_charge == 5, "five kills: not yet")
	belt.on_kill(skeleton)
	check(belt.charges == 2 and belt.kills_toward_charge == 0, "the sixth fills one")
	var knight: EnemyController = KnightScene.instantiate()
	add_child(knight)
	belt.on_kill(knight)
	check(belt.charges == 3, "an elite fills one at once")
	belt.charges = 0
	var champion: EnemyController = SkeletonScene.instantiate()
	Champion.promote(champion, [Champion.Affix.HASTED])
	add_child(champion)
	belt.on_kill(champion)
	check(belt.charges == 1, "so does a champion")


func test_the_hud_shows_the_charges_and_an_empty_belt() -> void:
	var main: Node3D = await _main()
	var belt: PotionBelt = main.get_node("Potions")
	var hud: Hud = main.get_node("HUD")
	var hero: PlayerController = main.get_node("Player")
	var button: TouchActionButton = hud.get_node("%PotionButton")
	check(button.visible and button.action == GameplayActions.POTION and button.badge == "3", "POTION with 3")
	for i in 3:
		hero.health.apply_damage(30)
		check(belt.drink() > 0, "potion %d drunk" % (i + 1))
		await wait_physics_frames(roundi(PotionBelt.COOLDOWN * Engine.physics_ticks_per_second) + 2)
	check(button.badge == "0" and button.cooldown_fraction() == 1.0, "an empty belt dims the button")
	belt.charges = 0
	var skeleton: EnemyController = SkeletonScene.instantiate()
	Champion.promote(skeleton, [Champion.Affix.STONESKIN])
	add_child(skeleton)
	belt.on_kill(skeleton)
	check(button.badge == "1", "a refill shows: %s" % button.badge)
	check(await wait_until(func() -> bool: return button.is_flashing_ready(), 30), "and flashes the button")


func test_the_dead_drink_nothing_and_the_end_of_a_run_stops_the_key() -> void:
	var main: Node3D = await _main()
	var belt: PotionBelt = main.get_node("Potions")
	var hero: PlayerController = main.get_node("Player")
	hero.health.apply_damage(hero.health.max_health)
	check(belt.drink() == 0 and belt.charges == 3, "the dead drink nothing")
	await wait_physics_frames(5)
	check(not belt.input_enabled, "after the fall, the key does nothing")
