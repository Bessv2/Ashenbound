class_name Item
extends RefCounted
## One item in the world or in an inventory: a kind of item at a rarity.

var data: ItemData
var rarity: Rarity.Tier


func _init(item_data: ItemData, tier: Rarity.Tier) -> void:
	data = item_data
	rarity = tier


## The name with its tier, e.g. "Bone Axe (Rare)". The tier is spelled out so
## it does not rest on color alone.
func describe() -> String:
	return "%s (%s)" % [data.display_name, Rarity.name_of(rarity)]
