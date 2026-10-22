class_name Forge
extends RefCounted
## The rules for salvaging and upgrading items (docs/LOOT.md, Gold, salvage
## and upgrades). Numbers only; Profile applies them, so an item is never
## lost or paid for twice.
##
## - Salvage turns a bag item into gold: more for a higher item level, a
##   rarer item and its upgrades.
## - Upgrade raises an item one rank, up to +5, for gold and Ash. Each rank
##   adds about 10% to every stat on the item (at least 1).

const MAX_UPGRADE := 5
## Value factor per rarity, Common to Mythic.
const RARITY_VALUE: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0, 32.0]


static func salvage_gold(item: ItemInstance) -> int:
	var base := (4.0 + 2.0 * item.item_level) * RARITY_VALUE[item.rarity]
	return roundi(base * (1.0 + 0.5 * item.upgrade))


## Gold for the next rank of `item`.
static func upgrade_gold(item: ItemInstance) -> int:
	return roundi((10.0 + 3.0 * item.item_level) * RARITY_VALUE[item.rarity] * (item.upgrade + 1))


## Ash for the next rank of `item`.
static func upgrade_ash(item: ItemInstance) -> int:
	return 2 * (item.upgrade + 1)


## What one stat of `value` becomes at `rank`: +10% per rank, at least 1.
static func upgraded(value: int, rank: int) -> int:
	if rank <= 0 or value == 0:
		return value
	var step := maxi(roundi(absi(value) * 0.1), 1)
	return value + signi(value) * step * rank
