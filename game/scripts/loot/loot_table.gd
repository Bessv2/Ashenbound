class_name LootTable
extends Resource
## What one death drops: an amount of gold, and with `item_chance` one item of
## a rolled rarity. Rolls take the random number generator as a parameter, so
## tests can seed it.

@export_range(0, 100000, 1) var gold_min: int = 3
@export_range(0, 100000, 1) var gold_max: int = 8
@export_range(0.0, 1.0, 0.01) var item_chance: float = 0.35
## Relative weights for Common, Uncommon, Rare, Epic and Legendary.
@export var rarity_weights: PackedFloat32Array = PackedFloat32Array([60.0, 25.0, 10.0, 4.0, 1.0])
## The kinds of item that can drop, equally likely.
@export var items: Array[ItemData] = []


func roll_gold(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(gold_min, maxi(gold_min, gold_max))


## The items this death drops: none, or one.
func roll_items(rng: RandomNumberGenerator) -> Array[Item]:
	var dropped: Array[Item] = []
	if items.is_empty() or rng.randf() >= item_chance:
		return dropped
	var data: ItemData = items[rng.randi_range(0, items.size() - 1)]
	dropped.append(Item.new(data, roll_rarity(rng)))
	return dropped


func roll_rarity(rng: RandomNumberGenerator) -> Rarity.Tier:
	return rng.rand_weighted(rarity_weights) as Rarity.Tier
