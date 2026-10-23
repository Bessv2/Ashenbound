class_name Camps
extends RefCounted
## The gathering camps (docs/CRAFTING.md): the idle half of the loop, after
## Idle Pocket Crafter 2's automated mining, wood cutting and hunting. Each
## camp gathers its materials by the hour, on the device clock, whether the
## game is open or not, up to CAP_HOURS of work; the player collects what is
## stored. Upgrading a camp, with gold and another camp's material, makes it
## gather faster.
##
## They open once the Ashen Crypt has been cleared, like offline rewards.
## Provisional like them: device time until the Milestone 5 server.

const MINE := "mine"
const LUMBER := "lumber"
const HUNT := "hunt"
const FORAGE := "forage"
const ORDER: Array[String] = [MINE, LUMBER, HUNT, FORAGE]
const MAX_LEVEL := 10
## A camp stops when its store holds this many hours of work.
const CAP_HOURS := 8.0
## Each level above 1 adds this share to the hourly yield.
const YIELD_PER_LEVEL := 0.4

## Name, icon, what it gathers per hour at level 1, and the material its
## upgrades take besides gold.
const INFO := {
	MINE: {"name": "Mine", "icon": "mine", "yield": {"iron_ore": 8.0, "crystal": 0.5}, "upgrade": "wood"},
	LUMBER: {"name": "Lumber Camp", "icon": "lumber", "yield": {"wood": 8.0}, "upgrade": "iron_ore"},
	HUNT: {"name": "Hunting Lodge", "icon": "hunt", "yield": {"leather": 5.0}, "upgrade": "wood"},
	FORAGE: {"name": "Herb Garden", "icon": "forage", "yield": {"herbs": 6.0}, "upgrade": "leather"},
}


## Material → amount per hour of camp `id` at `level`.
static func hourly(id: String, level: int) -> Dictionary:
	var result := {}
	var factor := 1.0 + YIELD_PER_LEVEL * (clampi(level, 1, MAX_LEVEL) - 1)
	for material: String in INFO[id].yield:
		result[material] = INFO[id].yield[material] * factor
	return result


## What camp `id` at `level` holds after `seconds` of work (capped), in whole
## units.
static func stock(id: String, level: int, seconds: int) -> Dictionary:
	var hours := clampf(seconds / 3600.0, 0.0, CAP_HOURS)
	var result := {}
	for material: String in hourly(id, level):
		result[material] = floori(hourly(id, level)[material] * hours)
	return result


## The cost of raising camp `id` from `level` to the next.
static func upgrade_cost(id: String, level: int) -> Dictionary:
	return {"gold": roundi(120.0 * pow(level, 1.5)), INFO[id].upgrade: 12 * level}
