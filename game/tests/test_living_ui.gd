extends "res://tests/framework/test_case.gd"
## Tests for the HUD's motion (docs/UI.md): the health trail, banners for
## rooms and level-ups, the hero's name, and the ability buttons' ready flash.

const CryptScene := preload("res://scenes/dungeon/crypt.tscn")


func _exit_tree() -> void:
	Profile.save_path = ""
	Profile.reset()


func test_health_drops_at_once_and_its_trail_follows() -> void:
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var hud: Hud = main.get_node("HUD")
	var hero: PlayerController = main.get_node("Player")
	var bar: ProgressBar = hud.get_node("%HealthBar")
	hero.health.apply_damage(30)
	check(bar.value == 70 and hud.health_trail_value() == 100, "the bar drops at once, the trail waits: %s / %s" % [bar.value, hud.health_trail_value()])
	check(await wait_until(func() -> bool: return hud.health_trail_value() == 70, 180), "then the trail catches up: %s" % hud.health_trail_value())
	hero.health.heal(20)
	check(await wait_until(func() -> bool: return bar.value == 90, 120), "healing fills the bar: %s" % bar.value)


func test_a_room_announces_itself_when_its_fight_starts() -> void:
	var main := instantiate_main(false, CryptScene)
	add_child(main)
	await wait_physics_frames(2)
	var hud: Hud = main.get_node("HUD")
	var ossuary: EncounterController = main.level.get_node("Encounters/Ossuary")
	ossuary.start()
	check(hud.banner().current_title() == "THE OSSUARY", "the room's name: %s" % hud.banner().current_title())
	var throne: EncounterController = main.level.get_node("Encounters/Throne")
	check(throne.title_color.r > throne.title_color.g * 2.0, "the boss's banner is red")


func test_a_level_gained_is_a_banner_and_the_hero_is_named() -> void:
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var hud: Hud = main.get_node("HUD")
	check((hud.get_node("Root/TopBar/Row/TitleBlock/Title") as Label).text == "WARDEN", "the hero's class at the top left")
	Profile.add_xp(Profile.xp_to_next(1))
	check(hud.banner().current_title() == "LEVEL 2", "the level-up banner: %s" % hud.banner().current_title())


func test_an_ability_button_flashes_when_ready_again() -> void:
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var hud: Hud = main.get_node("HUD")
	var hero: PlayerController = main.get_node("Player")
	var guard: Ability = hero.get_node("Guard")
	var button: TouchActionButton = hud.get_node("%GuardButton")
	check(button.ring_color.b > button.ring_color.r, "Guard's button is steel blue")
	check(guard.try_activate(Vector3.FORWARD), "Guard")
	await wait_physics_frames(2)
	check(not button.is_flashing_ready(), "no flash while cooling down")
	check(await wait_until(func() -> bool: return button.is_flashing_ready(), roundi(8.0 * Engine.physics_ticks_per_second)),
			"a flash when it is ready again")
