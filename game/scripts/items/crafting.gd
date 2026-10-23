class_name Crafting
extends RefCounted
## The concept sheet's chain: Upgrade → Enchant → Craft → Legendary
## (docs/CRAFTING.md). Numbers and rolls only; Profile applies them and pays,
## so an item or a material is never lost or spent twice.
##
## - Upgrade: Forge (gold and Ash, +1 rank up to +5).
## - Enchant: reroll one affix of an item into a stat it does not have.
## - Craft: make an item of a chosen kind at the hero's level, at least
##   Uncommon.
## - Ascend (the sheet's "Legendary" step): raise an item one rarity, up to
##   Legendary, adding the affixes the new rarity carries. Mythic stays a
##   drop.

## Craft costs at item level 1 by slot (ItemBase.Slot), before scaling.
const CRAFT_COSTS := {
	ItemBase.Slot.WEAPON: {"iron_ore": 12, "wood": 8, "crystal": 1, "gold": 60},
	ItemBase.Slot.HELMET: {"iron_ore": 10, "leather": 4, "gold": 40},
	ItemBase.Slot.CHEST: {"iron_ore": 14, "leather": 8, "gold": 50},
	ItemBase.Slot.GLOVES: {"iron_ore": 6, "leather": 6, "gold": 35},
	ItemBase.Slot.BOOTS: {"iron_ore": 6, "leather": 8, "gold": 35},
	ItemBase.Slot.RING: {"iron_ore": 4, "crystal": 3, "gold": 45},
	ItemBase.Slot.AMULET: {"herbs": 6, "crystal": 4, "gold": 50},
	ItemBase.Slot.RELIC: {"herbs": 8, "crystal": 4, "soul_shard": 1, "gold": 60},
}
## Soul shards to ascend to each rarity (Uncommon to Legendary).
const ASCEND_SHARDS := [0, 1, 2, 4, 8]
const MIN_CRAFT_RARITY := Rarity.Tier.UNCOMMON
const CRAFT_RARITY_BOOST := 2.0


## The item level a crafted item gets: the hero's level.
static func craft_level(hero_level: int) -> int:
	return maxi(hero_level, 1)


## What crafting `base` costs at `item_level`: materials grow 10% and gold
## 15% per level above 1.
static func craft_cost(base: ItemBase, item_level: int) -> Dictionary:
	var cost := {}
	var steps := maxi(item_level - 1, 0)
	for id: String in CRAFT_COSTS[base.slot]:
		var amount: int = CRAFT_COSTS[base.slot][id]
		if id == Materials.GOLD:
			cost[id] = roundi(amount * (1.0 + 0.15 * steps))
		elif id == Materials.SOUL_SHARD:
			cost[id] = amount
		else:
			cost[id] = roundi(amount * (1.0 + 0.1 * steps))
	return cost


## Rolls the crafted item.
static func craft(catalog: ItemCatalog, base: ItemBase, item_level: int, rng: RandomNumberGenerator) -> ItemInstance:
	return catalog.roll(base, item_level, Rarity.roll(rng, MIN_CRAFT_RARITY, CRAFT_RARITY_BOOST), rng)


## What enchanting one affix of `item` costs.
static func enchant_cost(item: ItemInstance) -> Dictionary:
	return {"crystal": 1 + item.rarity, "herbs": 2, "gold": 25 * (1 + item.rarity)}


## Rerolls affix `index` of `item` into a stat the item does not carry, with
## a fresh value at its item level. Returns false (changing nothing) when the
## index is wrong or no other stat fits the item.
static func enchant(catalog: ItemCatalog, item: ItemInstance, index: int, rng: RandomNumberGenerator) -> bool:
	if index < 0 or index >= item.affixes.size():
		return false
	var base := catalog.base(item.base_id)
	if base == null:
		return false
	var held := item.affixes.map(func(a: Dictionary) -> String: return a.stat)
	var pool: Array[AffixDef] = catalog.affixes.filter(func(a: AffixDef) -> bool:
		return a.slots.has(base.slot) and not held.has(a.stat))
	if pool.is_empty():
		return false
	var weights := PackedFloat32Array()
	for affix in pool:
		weights.append(affix.weight)
	var picked: AffixDef = pool[rng.rand_weighted(weights)]
	var span := ItemCatalog.scaled(picked.range_at_level_one, item.item_level)
	item.affixes[index] = {"stat": picked.stat, "value": rng.randi_range(span.x, span.y)}
	return true


## Whether `item` can rise a rarity.
static func can_ascend(item: ItemInstance) -> bool:
	return item.rarity < Rarity.Tier.LEGENDARY


## What raising `item` one rarity costs.
static func ascend_cost(item: ItemInstance) -> Dictionary:
	var next := mini(item.rarity + 1, Rarity.Tier.LEGENDARY)
	return {"soul_shard": ASCEND_SHARDS[next], "crystal": 2 * next, "gold": 100 * next}


## Raises `item` one rarity: its base stats grow by the new rarity's bonus,
## and it gains affixes up to the new rarity's fewest. Returns false at
## Legendary.
static func ascend(catalog: ItemCatalog, item: ItemInstance, rng: RandomNumberGenerator) -> bool:
	if not can_ascend(item):
		return false
	var base := catalog.base(item.base_id)
	var old_bonus: float = Rarity.BASE_BONUS[item.rarity]
	item.rarity += 1
	var new_bonus: float = Rarity.BASE_BONUS[item.rarity]
	for stat in item.base_stats:
		item.base_stats[stat] = roundi(item.base_stats[stat] * new_bonus / old_bonus)
	var wanted: int = Rarity.AFFIX_COUNTS[item.rarity][0]
	while item.affixes.size() < wanted and base:
		var held := item.affixes.map(func(a: Dictionary) -> String: return a.stat)
		var pool: Array[AffixDef] = catalog.affixes.filter(func(a: AffixDef) -> bool:
			return a.slots.has(base.slot) and not held.has(a.stat))
		if pool.is_empty():
			break
		var picked: AffixDef = pool[rng.randi_range(0, pool.size() - 1)]
		var span := ItemCatalog.scaled(picked.range_at_level_one, item.item_level)
		item.affixes.append({"stat": picked.stat, "value": rng.randi_range(span.x, span.y)})
	return true


## The materials salvaging `item` gives back, besides gold: ore from weapons,
## helms and chests, leather from gloves and boots, crystal from jewellery
## and relics. More for rarer items.
static func salvage_materials(item: ItemInstance, base: ItemBase) -> Dictionary:
	if base == null:
		return {}
	match base.slot:
		ItemBase.Slot.WEAPON, ItemBase.Slot.HELMET, ItemBase.Slot.CHEST:
			return {"iron_ore": 2 + item.rarity}
		ItemBase.Slot.GLOVES, ItemBase.Slot.BOOTS:
			return {"leather": 1 + item.rarity}
		_:
			return {"crystal": 1 + item.rarity / 2}
