extends "res://tests/framework/test_case.gd"
## Tests for saving the profile and for the inventory screen (docs/LOOT.md,
## acceptance checks 2, 4, 6 and 7, and the Milestone 4 gate).

const SAVE := "user://test_profile.json"

var catalog: ItemCatalog


func _ready() -> void:
	catalog = ItemCatalog.load_default()
	_clean_files()


func _exit_tree() -> void:
	_clean_files()
	Profile.save_path = ""
	Profile.reset()


func _clean_files() -> void:
	for path in [SAVE, "user://test_profile.backup.json", SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for file in DirAccess.get_files_at("user://"):
		if file.begins_with("test_profile.json.broken"):
			DirAccess.remove_absolute("user://" + file)


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	return rng


## A profile with Ash, a paid run, three bag items and two worn ones.
func _fill_profile() -> void:
	Profile.reset()
	Profile.save_path = SAVE
	Profile.grant_run_reward("run-1", 40)
	var rng := _rng()
	for i in 5:
		Profile.inventory.add(catalog.roll(catalog.bases[i], 3, i % 6, rng))
	Profile.equip_from_bag(Profile.inventory.items[0].uid)
	Profile.equip_from_bag(Profile.inventory.items[1].uid)


func test_the_profile_survives_a_save_and_a_load_unchanged() -> void:
	_fill_profile()
	check(Profile.save_profile() == OK, "saved")
	var saved := JSON.stringify(Profile.to_dict())
	Profile.reset()
	check(Profile.ash == 0 and Profile.inventory.items.is_empty(), "reset empties it")
	check(Profile.load_profile() == OK, "loaded")
	check(JSON.stringify(Profile.to_dict()) == saved, "identical after the round trip")
	check(Profile.ash == 40 and Profile.equipment.all().size() == 2 and Profile.inventory.items.size() == 3,
			"Ash, worn items and bag are back")
	check(not Profile.grant_run_reward("run-1", 40), "a run paid before the restart cannot be paid again")


func test_changes_save_themselves() -> void:
	_fill_profile()
	await wait_process_frames(2)
	var before: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	Profile.grant_run_reward("run-2", 5)
	await wait_process_frames(2)
	var after: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(int(after.ash) == int(before.ash) + 5, "the file follows the profile: %s → %s" % [before.ash, after.ash])


func test_a_broken_save_falls_back_to_the_backup_and_never_loses_the_file() -> void:
	_fill_profile()
	Profile.save_profile()
	var good := JSON.stringify(Profile.to_dict())
	Profile.save_profile()  # The first save becomes the backup.
	check(FileAccess.file_exists("user://test_profile.backup.json"), "a backup is kept")
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	Profile.reset()
	check(Profile.load_profile() == OK and JSON.stringify(Profile.to_dict()) == good, "the backup is loaded instead")
	for path in [SAVE, "user://test_profile.backup.json"]:
		var broken := FileAccess.open(path, FileAccess.WRITE)
		broken.store_string("[]")
		broken.close()
	check(Profile.load_profile() == ERR_FILE_CORRUPT, "both broken: a fresh start, no crash")
	check(Profile.ash == 0 and Profile.inventory.items.is_empty(), "fresh")
	var kept := Array(DirAccess.get_files_at("user://")).filter(func(f: String) -> bool: return f.begins_with("test_profile.json.broken"))
	check(kept.size() == 1, "the broken file is kept aside, not deleted")


func test_unknown_items_in_a_save_are_skipped_not_fatal() -> void:
	_fill_profile()
	var data := Profile.to_dict()
	data.inventory.append({"uid": "x", "base": "ashen_greatsword", "rarity": 2, "ilvl": 1, "stats": {"gold_find": 9}, "affixes": []})
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	Profile.reset()
	check(Profile.load_profile() == OK, "the save still loads")
	check(Profile.inventory.items.size() == 3, "with the bad item left out: %d" % Profile.inventory.items.size())


func test_the_inventory_screen_compares_equips_and_pauses() -> void:
	Profile.reset()
	var rng := _rng()
	var worn := ItemInstance.new()
	worn.uid = "worn"
	worn.base_id = "iron_cuirass"
	worn.base_stats = {ItemStats.ARMOR: 10, ItemStats.MAX_HEALTH: 10}
	var better := ItemInstance.new()
	better.uid = "better"
	better.base_id = "iron_cuirass"
	better.base_stats = {ItemStats.ARMOR: 14, ItemStats.MAX_HEALTH: 6}
	Profile.inventory.add(worn)
	Profile.equip_from_bag("worn")
	Profile.inventory.add(better)
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var hero: PlayerController = main.get_node("Player")
	check(hero.health.max_health == 110, "the worn cuirass counts: %d" % hero.health.max_health)
	var hud: Hud = main.get_node("HUD")
	var panel: InventoryPanel = main.get_node("Inventory")
	hud.inventory_requested.emit()
	check(panel.visible and get_tree().paused, "the bag opens and the game waits")
	check(not (main.get_node("PauseMenu") as CanvasLayer).visible, "without the pause menu")
	panel.select_bag_item("better")
	var lines := panel.comparison(panel.selected_item())
	check(lines.has({"stat": ItemStats.ARMOR, "delta": 4}) and lines.has({"stat": ItemStats.MAX_HEALTH, "delta": -4}),
			"+4 armour, -4 health against the worn one: %s" % [lines])
	panel.press_action()
	check(Profile.equipment.item_in(Equipment.Slot.CHEST) == better and Profile.inventory.has("worn"), "swapped")
	check(hero.health.max_health == 106, "the hero follows: %d" % hero.health.max_health)
	panel.press_action()
	check(Profile.equipment.item_in(Equipment.Slot.CHEST) == null and Profile.inventory.items.size() == 2, "unequipped back to the bag")
	panel.close_requested.emit()
	check(not panel.visible and not get_tree().paused, "closing resumes the game")


func test_a_restart_restores_the_hero_as_he_was() -> void:
	_fill_profile()
	var gear: Array = Profile.equipment.all()
	var expected_health: int = 100 + Profile.equipment.totals().get(ItemStats.MAX_HEALTH, 0)
	Profile.save_profile()
	Profile.reset()
	# A new launch: the profile loads before the game scene exists.
	check(Profile.load_profile() == OK, "loaded at launch")
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var hero: PlayerController = main.get_node("Player")
	check(Profile.equipment.all().size() == gear.size(), "the same gear is worn")
	check(hero.health.max_health == expected_health, "and counts: %d, expected %d" % [hero.health.max_health, expected_health])
