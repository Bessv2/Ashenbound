extends "res://tests/framework/test_case.gd"
## The concept sheet's menus: the Character window, the inventory grid with
## icons and the purse, and the dungeon cards on the title screen.

const TitleScene := preload("res://scenes/title.tscn")


func _give_items(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in count:
		var base: ItemBase = Profile.catalog.bases[i % Profile.catalog.bases.size()]
		Profile.inventory.add(Profile.catalog.roll(base, 5, i % 4, rng))


func test_the_sheet_reads_the_numbers_a_player_needs() -> void:
	var stats: Dictionary[String, int] = {ItemStats.WEAPON_DAMAGE: 20, ItemStats.DAMAGE_PCT: 50,
			ItemStats.MAX_HEALTH: 30, ItemStats.ARMOR: 12, ItemStats.CRIT_CHANCE: 7}
	var final := CharacterStats.combine(stats, {} as Dictionary[String, int])
	var rows := CharacterStats.sheet(final, 100, 10)
	var by_key := {}
	for row in rows:
		by_key[row.key] = row.value
		check(Icons.of(row.icon) != null, "%s has an icon" % row.key)
	check(by_key.health == "130", "health is the class's plus the gear's: %s" % by_key.health)
	# Weapon 20 against the bare-handed 10 doubles it; +50% damage on top.
	check(by_key.attack == "30", "attack is the basic attack's damage, scaled: %s" % by_key.attack)
	check(by_key.armor == "12" and by_key.crit_chance == "7%", "armour and crit chance")
	check(by_key.crit_damage == "150%", "crit damage counts the base 50%%: %s" % by_key.crit_damage)


func test_the_title_preview_matches_the_hero_in_a_run() -> void:
	_give_items(6)
	for i in 3:
		Profile.equip_from_bag(Profile.inventory.items[0].uid)
	Profile.add_xp(400)
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var stats := main.get_node("Player/Stats") as CharacterStats
	var preview := CharacterStats.preview(preload("res://scripts/main.gd").HERO_SCENES["warden"], "warden", Profile)
	check(stats.rows() == preview, "the same numbers in and out of a run")


func test_the_character_window_opens_from_the_hud_and_pauses() -> void:
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	(main.get_node("HUD") as Hud).character_requested.emit()
	var panel := main.get_node("Character") as CharacterPanel
	check(panel.visible and get_tree().paused, "open, and the game waits")
	var hero: PlayerController = main.get_node("Player")
	check(panel.value_of("health") == str(hero.health.max_health), "it shows the hero's health: %s" % panel.value_of("health"))
	(panel.find_child("Close", true, false) as Button).pressed.emit()
	check(not panel.visible and not get_tree().paused, "closing resumes")


func test_the_bag_is_a_grid_of_item_icons_with_the_purse() -> void:
	_give_items(4)
	Profile.gold = 12480
	var panel := InventoryPanel.new()
	add_child(panel)
	panel.open()
	var cells := panel.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.tooltip_text != "" and b.icon != null)
	check(cells.size() >= 4, "every bag item is an icon: %d" % cells.size())
	var amounts := panel.find_children("Amount", "Label", true, false)
	check(amounts.any(func(l: Label) -> bool: return l.text == "12,480"), "the gold is in the header")
	var weapon: ItemInstance = Profile.inventory.items.filter(func(item: ItemInstance) -> bool:
		return Profile.catalog.base(item.base_id).slot == ItemBase.Slot.WEAPON)[0]
	check(panel.power_line(weapon).ends_with("Damage"), "a weapon's card leads with its damage: %s" % panel.power_line(weapon))
	panel.free()


func test_dungeon_cards_show_icons_and_level_ranges() -> void:
	var title: TitleScreen = TitleScene.instantiate()
	add_child(title)
	title.enter_requested.disconnect(title._go_to_crypt)
	var crypt := title.find_child(Dungeons.CRYPT, true, false) as Button
	var catacombs := title.find_child(Dungeons.CATACOMBS, true, false) as Button
	check(crypt.icon == Icons.of("region_crypt") and crypt.text.contains("Lv 1-10"), "the crypt's card: %s" % crypt.text)
	check(catacombs.disabled and catacombs.text.contains("Clear the crypt"), "a shut dungeon says how to open it")
	Profile.complete_tier(1)
	check(catacombs.text.contains("Lv 5-15") and not catacombs.disabled, "and opens with its range: %s" % catacombs.text)
	(title.find_child("CharacterButton", true, false) as Button).pressed.emit()
	check(title.character_panel().visible, "the Character window opens from the title")
	title.character_panel().close()
	(title.find_child("BagButton", true, false) as Button).pressed.emit()
	check(title.inventory_panel().visible, "and so does the bag")
	title.free()


func test_amounts_are_grouped() -> void:
	check(WindowFrame.format_amount(12480) == "12,480" and WindowFrame.format_amount(78) == "78"
			and WindowFrame.format_amount(1000000) == "1,000,000", "thousands are separated")
