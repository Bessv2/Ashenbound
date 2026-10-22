class_name ItemInstance
extends RefCounted
## One item a player owns: which base it is, its rarity and item level, and
## the numbers it rolled. Plain data: it is saved as a Dictionary
## (to_dict / from_dict) and holds every rolled number, so changing a base's
## ranges later never changes items already owned.

const SAVE_VERSION := 1

var uid: String = ""
var base_id: String = ""
var rarity: int = Rarity.Tier.COMMON
var item_level: int = 1
## Stat key → value.
var base_stats: Dictionary[String, int] = {}
## [{"stat": key, "value": int}, ...]
var affixes: Array[Dictionary] = []
## Upgrade rank, 0 to Forge.MAX_UPGRADE. The rolled numbers above stay as
## rolled; the rank is applied when stats are read (Forge.upgraded).
var upgrade: int = 0


## One rolled value as it counts at this item's upgrade rank.
func stat_value(rolled: int) -> int:
	return Forge.upgraded(rolled, upgrade)


## Base stats and affixes added up, upgrades included: stat key → value.
func total_stats() -> Dictionary[String, int]:
	var total: Dictionary[String, int] = {}
	for stat in base_stats:
		total[stat] = stat_value(base_stats[stat])
	for affix in affixes:
		total[affix.stat] = total.get(affix.stat, 0) + stat_value(int(affix.value))
	return total


func to_dict() -> Dictionary:
	return {
		"v": SAVE_VERSION,
		"uid": uid,
		"base": base_id,
		"rarity": rarity,
		"ilvl": item_level,
		"up": upgrade,
		"stats": base_stats.duplicate(),
		"affixes": affixes.map(func(a: Dictionary) -> Dictionary: return {"stat": a.stat, "value": int(a.value)}),
	}


## The item stored in `data`, or null when it is not a valid item (an unknown
## stat, a missing field). JSON turns every number into a float; they come
## back as whole numbers here.
static func from_dict(data: Variant) -> ItemInstance:
	if not data is Dictionary:
		return null
	var dict: Dictionary = data
	for key in ["uid", "base", "rarity", "ilvl", "stats", "affixes"]:
		if not dict.has(key):
			return null
	var item := ItemInstance.new()
	item.uid = str(dict.uid)
	item.base_id = str(dict.base)
	item.rarity = clampi(int(dict.rarity), Rarity.Tier.COMMON, Rarity.Tier.MYTHIC)
	item.item_level = maxi(int(dict.ilvl), 1)
	item.upgrade = clampi(int(dict.get("up", 0)), 0, Forge.MAX_UPGRADE)
	if not dict.stats is Dictionary or not dict.affixes is Array:
		return null
	for stat in dict.stats:
		if not ItemStats.is_known(str(stat)):
			return null
		item.base_stats[str(stat)] = int(dict.stats[stat])
	for affix: Variant in dict.affixes:
		if not affix is Dictionary or not ItemStats.is_known(str(affix.get("stat", ""))):
			return null
		item.affixes.append({"stat": str(affix.stat), "value": int(affix.get("value", 0))})
	return item
