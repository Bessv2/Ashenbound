extends "res://tests/framework/test_case.gd"
## Materials, the crafting chain (Upgrade → Enchant → Craft → Legendary) and
## the gathering camps: docs/CRAFTING.md.

const CryptScene := preload("res://scenes/dungeon/crypt.tscn")

var _real_clock: Callable
## The fake clock's time, in unix seconds.
var _now := [1_000_000]


func _ready() -> void:
	_real_clock = Profile.clock
	Profile.clock = func() -> int: return _now[0]
	Profile.rng.seed = 11


func _exit_tree() -> void:
	Profile.clock = _real_clock


func _stock(amounts: Dictionary) -> void:
	for id: String in amounts:
		Profile.materials[id] = amounts[id]


func _item(slot: int, rarity: int) -> ItemInstance:
	var base: ItemBase = Profile.catalog.bases.filter(func(b: ItemBase) -> bool: return b.slot == slot)[0]
	var item := Profile.catalog.roll(base, 5, rarity, Profile.rng)
	Profile.inventory.add(item)
	return item


func test_every_material_and_camp_has_an_icon() -> void:
	for id in Materials.ORDER:
		check(Icons.of(Materials.icon_of(id)) != null, "%s has an icon" % id)
	for id in Camps.ORDER:
		check(Icons.of(Camps.INFO[id].icon) != null, "the %s has an icon" % id)


func test_crafting_pays_once_and_puts_the_item_in_the_bag() -> void:
	var base: ItemBase = Profile.catalog.base("iron_helm")
	var cost := Crafting.craft_cost(base, Crafting.craft_level(Profile.level))
	check(Profile.craft_problem("iron_helm").begins_with("Missing"), "nothing held, nothing crafted: %s" % Profile.craft_problem("iron_helm"))
	check(Profile.craft_item("iron_helm") == null and Profile.inventory.items.is_empty(), "and nothing is paid or made")
	Profile.gold = int(cost.gold) + 5
	_stock({"iron_ore": int(cost.iron_ore) + 1, "leather": int(cost.leather)})
	var item := Profile.craft_item("iron_helm")
	check(item != null and Profile.inventory.has(item.uid), "the helm is in the bag")
	check(item.rarity >= Rarity.Tier.UNCOMMON and item.base_id == "iron_helm", "Uncommon or better, of the kind chosen")
	check(Profile.gold == 5 and Profile.material("iron_ore") == 1 and Profile.material("leather") == 0,
			"paid exactly: %d gold, %d ore, %d leather" % [Profile.gold, Profile.material("iron_ore"), Profile.material("leather")])
	check(not Profile.materials.has("leather"), "a spent material leaves no zero behind")


func test_crafting_refuses_a_full_bag() -> void:
	_stock({"iron_ore": 999, "leather": 999})
	Profile.gold = 99999
	while not Profile.inventory.is_full():
		_item(ItemBase.Slot.RING, Rarity.Tier.COMMON)
	check(Profile.craft_problem("iron_helm") == "The bag is full." and Profile.craft_item("iron_helm") == null, "no room, no craft")
	check(Profile.material("iron_ore") == 999, "and nothing is paid")


func test_enchanting_rerolls_the_chosen_affix_into_a_new_stat() -> void:
	var item := _item(ItemBase.Slot.WEAPON, Rarity.Tier.RARE)
	check(item.affixes.size() >= 2, "a rare has affixes")
	var kept: Dictionary = item.affixes[0].duplicate()
	var old_stat: String = item.affixes[1].stat
	check(Profile.enchant_item(item, 1).begins_with("Missing"), "it costs crystal, herbs and gold")
	_stock({"crystal": 10, "herbs": 10})
	Profile.gold = 1000
	check(Profile.enchant_item(item, -1) != "", "an affix must be chosen")
	check(Profile.enchant_item(item, 1) == "", "enchanted")
	var stats := item.affixes.map(func(a: Dictionary) -> String: return a.stat)
	check(item.affixes[0] == kept, "the other affixes stay")
	check(item.affixes[1].stat != old_stat and stats.count(item.affixes[1].stat) == 1, "a stat the item did not have: %s" % item.affixes[1].stat)
	check(Profile.material("crystal") == 10 - Crafting.enchant_cost(item).crystal, "crystal paid")


func test_ascending_raises_rarity_up_to_legendary() -> void:
	var item := _item(ItemBase.Slot.CHEST, Rarity.Tier.COMMON)
	var armour: int = item.base_stats.armor
	_stock({"soul_shard": 50, "crystal": 50})
	Profile.gold = 99999
	check(Profile.ascend_item(item) == "" and item.rarity == Rarity.Tier.UNCOMMON, "Common to Uncommon")
	check(item.affixes.size() >= Rarity.AFFIX_COUNTS[Rarity.Tier.UNCOMMON][0], "with the affix an Uncommon carries")
	while Crafting.can_ascend(item):
		check(Profile.ascend_item(item) == "", "rises again")
	check(item.rarity == Rarity.Tier.LEGENDARY, "it stops at Legendary")
	check(item.base_stats.armor > armour, "its base stats grew: %d to %d" % [armour, item.base_stats.armor])
	check(item.affixes.size() >= Rarity.AFFIX_COUNTS[Rarity.Tier.LEGENDARY][0], "with a Legendary's affixes: %d" % item.affixes.size())
	check(Profile.ascend_item(item) == "Already Legendary.", "Mythic stays a drop")
	var stats := item.affixes.map(func(a: Dictionary) -> String: return a.stat)
	for stat in stats:
		check(stats.count(stat) == 1, "no stat twice: %s" % stat)


func test_salvage_gives_materials_back() -> void:
	var sword := _item(ItemBase.Slot.WEAPON, Rarity.Tier.RARE)
	var ring := _item(ItemBase.Slot.RING, Rarity.Tier.UNCOMMON)
	Profile.salvage(sword.uid)
	Profile.salvage(ring.uid)
	check(Profile.material("iron_ore") == 2 + Rarity.Tier.RARE, "a sword gives ore: %d" % Profile.material("iron_ore"))
	check(Profile.material("crystal") == 1, "a ring gives crystal: %d" % Profile.material("crystal"))


func test_camps_open_with_the_crypt_and_gather_on_the_clock() -> void:
	check(not Profile.camps_open() and Profile.camp_stock(Camps.MINE).is_empty(), "shut before the crypt is cleared")
	_now[0] += 3600
	Profile.complete_tier(1)
	check(Profile.camps_open() and Profile.camp_level(Camps.MINE) == 1, "a clear opens them at level 1")
	check(Profile.camp_stock(Camps.MINE).get("iron_ore", 0) == 0, "time before they opened earns nothing")
	_now[0] += 2 * 3600
	check(Profile.camp_stock(Camps.MINE).iron_ore == 16, "8 ore an hour: %s" % Profile.camp_stock(Camps.MINE))
	check(Profile.camp_stock(Camps.MINE).crystal == 1, "and half a crystal an hour")
	var taken := Profile.collect_camp(Camps.MINE)
	check(taken.iron_ore == 16 and Profile.material("iron_ore") == 16, "collected into the materials")
	check(Profile.collect_camp(Camps.MINE).get("iron_ore", 0) == 0, "collecting twice pays nothing more")


func test_a_camp_stops_at_its_cap_and_ignores_a_clock_turned_back() -> void:
	Profile.complete_tier(1)
	_now[0] += 100 * 3600
	check(Profile.camp_stock(Camps.LUMBER).wood == int(8 * Camps.CAP_HOURS), "8 hours at most: %s" % Profile.camp_stock(Camps.LUMBER))
	Profile.collect_camp(Camps.LUMBER)
	_now[0] -= 50 * 3600
	check(Profile.camp_stock(Camps.LUMBER).wood == 0, "a clock turned back earns nothing")


func test_upgrading_a_camp_collects_first_and_gathers_faster() -> void:
	Profile.complete_tier(1)
	_now[0] += 3600
	var cost := Camps.upgrade_cost(Camps.HUNT, 1)
	check(Profile.upgrade_camp(Camps.HUNT).begins_with("Missing"), "it costs gold and wood")
	Profile.gold = int(cost.gold)
	_stock({"wood": int(cost.wood)})
	check(Profile.upgrade_camp(Camps.HUNT) == "" and Profile.camp_level(Camps.HUNT) == 2, "now level 2")
	check(Profile.material("leather") == 5, "the hour at level 1 was collected first")
	check(Profile.gold == 0 and Profile.material("wood") == 0, "paid")
	_now[0] += 3600
	check(Profile.camp_stock(Camps.HUNT).leather == 7, "5 × 1.4 an hour now: %s" % Profile.camp_stock(Camps.HUNT))


func test_materials_and_camps_are_saved() -> void:
	Profile.complete_tier(1)
	_stock({"herbs": 4, "soul_shard": 2})
	Profile.camps[Camps.FORAGE].level = 3
	var saved := Profile.to_dict()
	Profile.reset()
	check(Profile._apply(JSON.parse_string(JSON.stringify(saved))), "the save loads")
	check(Profile.material("herbs") == 4 and Profile.material("soul_shard") == 2, "the materials came back")
	check(Profile.camp_level(Camps.FORAGE) == 3, "and the camps")
	saved.erase("materials")
	saved.erase("camps")
	saved["version"] = 3
	check(Profile._apply(saved) and Profile.materials.is_empty(), "an older save loads with no materials")
	check(Profile.camp_level(Camps.MINE) == 1, "and, its crypt cleared, its camps start working")


func test_kills_drop_the_dungeons_materials_and_bosses_drop_shards() -> void:
	var dropper := LootDropper.new()
	add_child(dropper)
	dropper.dungeon = Dungeons.CATACOMBS
	var ghoul: EnemyController = load("res://scenes/enemies/ghoul.tscn").instantiate()
	var totals := {}
	for i in 200:
		for id: String in dropper.roll_materials(ghoul):
			totals[id] = int(totals.get(id, 0)) + 1
	check(totals.has("leather") and totals.has("herbs"), "ghouls give the catacombs' leather and herbs: %s" % totals)
	check(not totals.has("iron_ore") and not totals.has("soul_shard"), "not the crypt's ore, and no shards from the common dead")
	ghoul.free()
	var lord: EnemyController = load("res://scenes/enemies/ashen_lord.tscn").instantiate()
	lord.add_to_group(&"boss")
	var found := dropper.roll_materials(lord)
	check(found.get("soul_shard", 0) >= LootDropper.BOSS_SHARDS and found.get("crystal", 0) >= LootDropper.BOSS_CRYSTALS,
			"a boss always gives shards and crystal: %s" % found)
	lord.free()


func test_a_run_pays_its_materials_once_with_its_rewards() -> void:
	var main := instantiate_main(false, CryptScene)
	add_child(main)
	await wait_physics_frames(2)
	var run: RunController = main.get_node("Run")
	run.add_materials({"iron_ore": 3, "crystal": 1})
	main.get_node("Player").health.apply_damage(100000)
	await wait_physics_frames(2)
	check(Profile.material("iron_ore") == 3 and Profile.material("crystal") == 1, "paid at the end: %s" % Profile.materials)
	check(not run.claim_reward(), "and only once")
	check(Profile.material("iron_ore") == 3, "still 3")
	check(main.summary_text().contains("Materials: 3 Iron Ore, 1 Crystal"), "the summary lists them")


func test_the_forge_and_camp_windows_work_from_the_title() -> void:
	Profile.complete_tier(1)
	var title: TitleScreen = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	title.enter_requested.disconnect(title._go_to_crypt)
	title.open_forge()
	var forge := title.forge_panel()
	forge.select_base("bone_ring")
	check(forge.press_craft() == null, "nothing to craft with")
	var cost := Crafting.craft_cost(Profile.catalog.base("bone_ring"), Crafting.craft_level(Profile.level))
	Profile.gold = int(cost.gold)
	_stock({"iron_ore": int(cost.iron_ore), "crystal": int(cost.crystal)})
	check(forge.press_craft() != null and Profile.inventory.items.size() == 1, "a ring crafted from the forge")
	forge.close()
	_now[0] += 3600
	title.open_camps()
	var taken := title.camps_panel().press_collect_all()
	check(taken.get("iron_ore", 0) == 8 and taken.get("wood", 0) == 8, "an hour of the mine and the lumber camp: %s" % taken)
	title.free()
