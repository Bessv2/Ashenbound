class_name ItemBase
extends Resource
## A kind of item (a template): what it is called, which slot it fits, and
## the base stats it rolls. Hand-made data in res://resources/items/.

enum Slot { WEAPON, HELMET, CHEST, GLOVES, BOOTS, RING, AMULET, RELIC }

const SLOT_NAMES := ["Weapon", "Helmet", "Chest", "Gloves", "Boots", "Ring", "Amulet", "Relic"]

## Stable key stored in saves. Never rename one that has shipped.
@export var id: String = ""
@export var display_name: String = ""
@export var slot: Slot = Slot.WEAPON
## Stat key → Vector2i(min, max) at item level 1.
@export var base_stats: Dictionary[String, Vector2i] = {}
@export_range(1, 100, 1) var min_item_level: int = 1


## Problems with this data, for tests and the catalog check.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == "":
		problems.append("%s has no id" % resource_path)
	for stat in base_stats:
		if not ItemStats.is_known(stat):
			problems.append("%s: unknown stat %s" % [id, stat])
		elif base_stats[stat].x > base_stats[stat].y:
			problems.append("%s: %s range is backwards" % [id, stat])
	return problems
