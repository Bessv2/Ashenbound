class_name Materials
extends RefCounted
## The six crafting materials of the concept sheet, each with one job
## (docs/CRAFTING.md):
## - iron ore: weapons and armour;
## - wood: weapons, and the mine's upgrades;
## - leather: armour, gloves and boots;
## - herbs: amulets, relics and enchanting;
## - crystal: jewellery, enchanting and ascending;
## - soul shards: ascending an item's rarity, and relics. Only champions,
##   elites and bosses drop them, so the rarest step needs active play.

const IRON_ORE := "iron_ore"
const WOOD := "wood"
const LEATHER := "leather"
const HERBS := "herbs"
const CRYSTAL := "crystal"
const SOUL_SHARD := "soul_shard"
const ORDER: Array[String] = [IRON_ORE, WOOD, LEATHER, HERBS, CRYSTAL, SOUL_SHARD]

const INFO := {
	IRON_ORE: {"name": "Iron Ore", "color": Color(0.72, 0.74, 0.78)},
	WOOD: {"name": "Wood", "color": Color(0.72, 0.5, 0.3)},
	LEATHER: {"name": "Leather", "color": Color(0.66, 0.4, 0.28)},
	HERBS: {"name": "Herbs", "color": Color(0.45, 0.78, 0.38)},
	CRYSTAL: {"name": "Crystal", "color": Color(0.35, 0.7, 0.95)},
	SOUL_SHARD: {"name": "Soul Shard", "color": Color(0.72, 0.45, 0.95)},
}
## Costs may also ask for these, alongside materials.
const GOLD := "gold"
const ASH := "ash"


static func is_material(id: String) -> bool:
	return INFO.has(id)


static func name_of(id: String) -> String:
	if id == GOLD:
		return "Gold"
	if id == ASH:
		return "Ash"
	return INFO[id].name if INFO.has(id) else id


static func color_of(id: String) -> Color:
	if id == GOLD:
		return Color("#D9A44C")
	if id == ASH:
		return Color("#A77BD6")
	return INFO[id].color if INFO.has(id) else Color.WHITE


## The icon key of `id` (a material, gold or Ash).
static func icon_of(id: String) -> String:
	return id


## "3 Iron Ore, 1 Crystal" (gold and Ash too), in the order above.
static func describe(amounts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in [GOLD, ASH] + ORDER:
		if int(amounts.get(id, 0)) > 0:
			parts.append("%d %s" % [int(amounts[id]), name_of(id)])
	return ", ".join(parts)
