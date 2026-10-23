extends "res://tests/framework/test_case.gd"
## The HUD laid out like the concept sheet: icons on every button, the
## hero's portrait, and the minimap.

const CryptScene := preload("res://scenes/dungeon/crypt.tscn")


func test_every_class_has_its_icons() -> void:
	for class_id: String in preload("res://scripts/main.gd").HERO_SCENES:
		var hero: PlayerController = load(preload("res://scripts/main.gd").HERO_SCENES[class_id]).instantiate()
		check(Icons.for_attack(class_id) != null, "%s has an attack icon" % class_id)
		for ability in hero.abilities:
			check(Icons.for_ability(ability.display_name) != null, "%s's %s has an icon" % [class_id, ability.display_name])
		hero.free()
	for slot in ItemBase.SLOT_NAMES.size():
		check(Icons.for_slot(slot) != null, "slot %s has an icon" % ItemBase.SLOT_NAMES[slot])
	for key in ["bag", "skills", "dodge", "potion", "gold", "ash"]:
		check(Icons.of(key) != null, "%s has an icon" % key)
	check(Icons.of("no_such_icon") == null, "an unknown icon is null, not an error")


func test_buttons_show_icons_and_the_portrait_the_class() -> void:
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var hud: Hud = main.get_node("HUD")
	check((hud.get_node("%AttackButton") as TouchActionButton).icon == Icons.for_attack("warden"), "the attack shows the greatsword")
	check((hud.get_node("%CleaveButton") as TouchActionButton).icon == Icons.for_ability("CLEAVE"), "Cleave shows its icon")
	check((hud.get_node("%BagButton") as Button).icon != null, "the bag button is an icon")
	var portrait := hud.get_node("%Portrait") as HeroPortrait
	check(portrait.icon == Icons.for_attack("warden") and portrait.level == 1, "the portrait shows the class and level")


func test_the_minimap_is_hidden_without_rooms() -> void:
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	check(not (main.get_node("HUD") as Hud).minimap().visible, "the arena has no rooms to map")


func test_the_minimap_reveals_rooms_as_the_hero_reaches_them() -> void:
	var main := instantiate_main(false, CryptScene)
	add_child(main)
	await wait_physics_frames(2)
	var map := (main.get_node("HUD") as Hud).minimap()
	var rooms := map.rooms()
	check(map.visible and rooms.size() >= 6, "the crypt's rooms and corridors are mapped: %d" % rooms.size())
	await wait_process_frames(10)
	var player: Node3D = main.get_node("Player")
	var at := Vector2(player.global_position.x, player.global_position.z)
	var near := -1
	var far := -1
	for i in rooms.size():
		if rooms[i].grow(Minimap.REVEAL_MARGIN).has_point(at):
			near = i
		elif rooms[i].get_center().distance_to(at) > 40.0:
			far = i
	check(near >= 0 and map.is_seen(near), "the room the hero starts in is shown")
	check(far >= 0 and not map.is_seen(far), "a room far ahead is not shown yet")


func test_the_map_turns_with_the_camera() -> void:
	var map := Minimap.new()
	map.yaw_degrees = 45.0
	# The camera looks north-west, so north-west is straight up on the map.
	var up := map.to_map(Vector2(-1, -1), Vector2.ZERO, 1.0)
	check_near(up.x, 0.0, 0.001, "no sideways part")
	check(up.y < 0.0, "points up")
	map.free()
