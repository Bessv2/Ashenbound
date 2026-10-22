extends "res://tests/framework/test_case.gd"
## Tests for gold, salvage and upgrades (docs/LOOT.md, Gold, salvage and
## upgrades): no item is lost or duplicated, every price is paid once, and an
## upgrade changes the hero's numbers.

const SAVE := "user://test_forge_profile.json"


func _exit_tree() -> void:
	for path in [SAVE, "user://test_forge_profile.backup.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	Profile.save_path = ""
	Profile.reset()


func _cuirass(uid: String, rarity: int = Rarity.Tier.RARE) -> ItemInstance:
	var item := ItemInstance.new()
	item.uid = uid
	item.base_id = "iron_cuirass"
	item.rarity = rarity
	item.item_level = 3
	item.base_stats = {ItemStats.ARMOR: 10, ItemStats.MAX_HEALTH: 10}
	return item


func test_each_rank_adds_a_tenth_and_at_least_one() -> void:
	check(Forge.upgraded(10, 1) == 11 and Forge.upgraded(10, 5) == 15, "10 → 11 → … → 15")
	check(Forge.upgraded(2, 1) == 3, "a small stat still gains 1")
	check(Forge.upgraded(40, 2) == 48, "40 at +2 is 48")
	check(Forge.upgraded(7, 0) == 7 and Forge.upgraded(0, 3) == 0, "rank 0 and empty stats stay")
	var item := _cuirass("a")
	item.affixes = [{"stat": ItemStats.ARMOR, "value": 5}]
	item.upgrade = 2
	check(item.total_stats() == {ItemStats.ARMOR: 12 + 7, ItemStats.MAX_HEALTH: 12}, "totals include the rank: %s" % item.total_stats())


func test_an_upgrade_costs_once_and_the_hero_follows() -> void:
	var item := _cuirass("worn")
	Profile.inventory.add(item)
	Profile.equip_from_bag("worn")
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var hero: PlayerController = main.get_node("Player")
	check(hero.health.max_health == 110 and hero.health.armor == 10, "worn at +0")
	check(Profile.upgrade_item(item) == "Not enough gold.", "no gold, no upgrade")
	Profile.gold = 1000
	check(Profile.upgrade_item(item) == "Not enough Ash.", "no Ash, no upgrade")
	Profile.ash = 100
	var gold_cost := Forge.upgrade_gold(item)
	var ash_cost := Forge.upgrade_ash(item)
	check(Profile.upgrade_item(item) == "", "upgraded")
	check(item.upgrade == 1 and Profile.gold == 1000 - gold_cost and Profile.ash == 100 - ash_cost,
			"paid %d gold and %d Ash once" % [gold_cost, ash_cost])
	check(hero.health.max_health == 111 and hero.health.armor == 11, "the hero follows: %d health, %d armour" % [hero.health.max_health, hero.health.armor])
	Profile.gold = 100000
	while Profile.upgrade_item(item) == "":
		pass
	check(item.upgrade == Forge.MAX_UPGRADE and Profile.upgrade_item(item) == "Fully upgraded.", "+5 at most")
	check(Profile.upgrade_item(_cuirass("stranger")) == "Not yours.", "only owned items")


func test_salvage_asks_twice_and_turns_an_item_into_gold_once() -> void:
	Profile.inventory.add(_cuirass("spare", Rarity.Tier.EPIC))
	Profile.inventory.add(_cuirass("worn"))
	Profile.equip_from_bag("worn")
	var value := Forge.salvage_gold(Profile.inventory.items[0])
	check(value == roundi((4 + 2 * 3) * 8.0), "an Epic item level 3 is worth %d" % value)
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var panel: InventoryPanel = main.get_node("Inventory")
	main.get_node("HUD").inventory_requested.emit()
	panel.select_bag_item("spare")
	check(panel.press_salvage() == 0 and Profile.inventory.has("spare"), "the first tap only asks")
	panel.select_slot(Equipment.Slot.CHEST)
	panel.select_bag_item("spare")
	check(panel.press_salvage() == 0 and Profile.inventory.has("spare"), "selecting again asks again")
	check(panel.press_salvage() == value and not Profile.inventory.has("spare") and Profile.gold == value,
			"the second tap salvages for %d gold" % value)
	check(panel.selected_item() == null, "nothing selected after")
	check(Profile.salvage("spare") == 0 and Profile.gold == value, "it cannot be salvaged twice")
	check(Profile.salvage("worn") == 0 and Profile.equipment.item_in(Equipment.Slot.CHEST) != null, "worn items are not salvaged")
	panel.close_requested.emit()


func test_upgrades_and_gold_survive_a_save() -> void:
	Profile.save_path = SAVE
	var item := _cuirass("kept")
	item.upgrade = 3
	Profile.inventory.add(item)
	Profile.gold = 321
	Profile.save_profile()
	Profile.reset()
	check(Profile.load_profile() == OK and Profile.gold == 321, "gold comes back")
	check(Profile.inventory.items.size() == 1 and Profile.inventory.items[0].upgrade == 3, "and the +3")
	var old := item.to_dict()
	old.erase("up")
	check(ItemInstance.from_dict(old).upgrade == 0, "an item saved before upgrades loads at +0")
	old["up"] = 99
	check(ItemInstance.from_dict(old).upgrade == Forge.MAX_UPGRADE, "a rank above +5 is pulled back")


func test_kills_earn_gold_paid_with_the_run() -> void:
	var main := instantiate_main(true)
	add_child(main)
	var encounter: EncounterController = main.get_node("Level/Enemies/Encounter")
	check(await wait_until(func() -> bool: return not encounter.living_enemies().is_empty(), 200), "skeletons rise")
	var skeleton := encounter.living_enemies()[0]
	var health := Health.of(skeleton)
	health.invulnerable = false
	health.apply_damage(1000)
	var run: RunController = main.get_node("Run")
	check(run.gold == 3, "a Skeleton Warrior is worth 3 gold: %d" % run.gold)
	var scaled: EnemyController = load("res://scenes/enemies/fallen_knight.tscn").instantiate()
	Difficulty.new(3).apply(scaled)
	check(scaled.gold_value == 50, "tier 3 doubles gold: %d" % scaled.gold_value)
	scaled.free()
	check(Profile.gold == 0, "nothing is paid while the run is on")
	main.get_node("Player").health.apply_damage(1000)
	check(run.is_over() and Profile.gold == 3, "the run's gold is paid at its end: %d" % Profile.gold)
	check(not run.claim_reward() and Profile.gold == 3, "and only once")
