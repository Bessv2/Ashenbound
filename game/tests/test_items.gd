extends "res://tests/framework/test_case.gd"
## Tests for the item model: the catalog data, rolling, rarity, and the save
## format (docs/LOOT.md).

var catalog: ItemCatalog


func _ready() -> void:
	catalog = ItemCatalog.load_default()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_the_catalog_is_valid_and_every_slot_can_fill_a_mythic() -> void:
	check(catalog.validate().is_empty(), "catalog problems: %s" % [catalog.validate()])
	var most: int = Rarity.AFFIX_COUNTS[Rarity.Tier.MYTHIC][1]
	for slot in ItemBase.Slot.values():
		var options := catalog.affixes.filter(func(a: AffixDef) -> bool: return a.slots.has(slot))
		check(options.size() >= most, "%s has %d affix stats, needs %d" % [ItemBase.SLOT_NAMES[slot], options.size(), most])
		check(catalog.bases.any(func(b: ItemBase) -> bool: return b.slot == slot), "a base for %s" % ItemBase.SLOT_NAMES[slot])


func test_rolled_items_stay_inside_their_ranges_and_rarity_rules() -> void:
	var rng := _rng(11)
	for item_base in catalog.bases:
		for rarity in Rarity.Tier.values():
			for item_level: int in [1, 5]:
				var item := catalog.roll(item_base, item_level, rarity, rng)
				var counts: Array = Rarity.AFFIX_COUNTS[rarity]
				check(item.affixes.size() >= counts[0] and item.affixes.size() <= counts[1],
						"%s %s: %d affixes" % [Rarity.name_of(rarity), item_base.id, item.affixes.size()])
				var stats_seen := {}
				for affix in item.affixes:
					check(not stats_seen.has(affix.stat), "%s: %s twice" % [item_base.id, affix.stat])
					stats_seen[affix.stat] = true
					var definition: AffixDef = catalog.affixes.filter(func(a: AffixDef) -> bool: return a.stat == affix.stat)[0]
					check(definition.slots.has(item_base.slot), "%s cannot carry %s" % [item_base.id, affix.stat])
					var span := ItemCatalog.scaled(definition.range_at_level_one, item_level)
					check(affix.value >= span.x and affix.value <= span.y, "%s %s = %d outside %s" % [item_base.id, affix.stat, affix.value, span])
					if rarity == Rarity.Tier.MYTHIC:
						check(affix.value == span.y, "a Mythic rolls the top of %s" % affix.stat)
				for stat in item_base.base_stats:
					var span := ItemCatalog.scaled(item_base.base_stats[stat], item_level)
					var bonus: float = Rarity.BASE_BONUS[rarity]
					var value: int = item.base_stats[stat]
					check(value >= roundi(span.x * bonus) and value <= roundi(span.y * bonus),
							"%s %s base %s = %d" % [Rarity.name_of(rarity), item_base.id, stat, value])


func test_an_item_survives_json_unchanged() -> void:
	var rng := _rng(5)
	for item_base in catalog.bases:
		var item := catalog.roll(item_base, 4, Rarity.Tier.LEGENDARY, rng)
		var text := JSON.stringify(item.to_dict())
		var back := ItemInstance.from_dict(JSON.parse_string(text))
		check(back != null, "%s parses back" % item_base.id)
		if back:
			check(back.to_dict() == item.to_dict(), "%s is identical after a round trip" % item_base.id)
			check(back.total_stats() == item.total_stats(), "%s totals match" % item_base.id)


func test_bad_item_data_is_refused() -> void:
	var good := catalog.roll(catalog.bases[0], 1, Rarity.Tier.RARE, _rng(3)).to_dict()
	check(ItemInstance.from_dict(good) != null, "good data loads")
	check(ItemInstance.from_dict("not an item") == null, "a string is not an item")
	var missing := good.duplicate(true)
	missing.erase("affixes")
	check(ItemInstance.from_dict(missing) == null, "a missing field is refused")
	var unknown := good.duplicate(true)
	unknown.stats["gold_find"] = 50
	check(ItemInstance.from_dict(unknown) == null, "an unknown stat is refused")


func test_rarity_rolls_follow_their_weights_and_minimum() -> void:
	var rng := _rng(99)
	var counts := [0, 0, 0, 0, 0, 0]
	for i in 20000:
		counts[Rarity.roll(rng)] += 1
	check_near(counts[Rarity.Tier.COMMON] / 20000.0, 0.6, 0.02, "Common share")
	check_near(counts[Rarity.Tier.RARE] / 20000.0, 0.11, 0.01, "Rare share")
	for i in 500:
		check(Rarity.roll(rng, Rarity.Tier.RARE) >= Rarity.Tier.RARE, "never below the minimum")


func test_totals_add_base_stats_and_affixes() -> void:
	var item := ItemInstance.new()
	item.base_stats = {ItemStats.ARMOR: 10, ItemStats.MAX_HEALTH: 5}
	item.affixes = [{"stat": ItemStats.MAX_HEALTH, "value": 7}, {"stat": ItemStats.DAMAGE_PCT, "value": 4}]
	check(item.total_stats() == {ItemStats.ARMOR: 10, ItemStats.MAX_HEALTH: 12, ItemStats.DAMAGE_PCT: 4}, "%s" % item.total_stats())
	check(ItemStats.describe(ItemStats.DAMAGE_PCT, 4) == "+4% Damage", ItemStats.describe(ItemStats.DAMAGE_PCT, 4))
	check(ItemStats.describe(ItemStats.MAX_HEALTH, 12) == "+12 Max health", ItemStats.describe(ItemStats.MAX_HEALTH, 12))
