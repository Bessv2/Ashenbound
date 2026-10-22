class_name DropTable
extends Resource
## What an enemy can drop when it dies: `rolls` tries, each dropping an item
## with `chance`, of rarity at least `min_rarity`, with tiers above Uncommon
## `rarity_boost` times as likely.

@export_range(0.0, 1.0, 0.01) var chance: float = 0.1
@export_range(1, 10, 1) var rolls: int = 1
@export var min_rarity: Rarity.Tier = Rarity.Tier.COMMON
@export_range(1.0, 50.0, 0.1) var rarity_boost: float = 1.0


## The items one death drops at `item_level`. A higher crypt tier passes
## `chance_scale` (capped at a certain drop) and `rarity_scale`.
func roll(catalog: ItemCatalog, item_level: int, rng: RandomNumberGenerator,
		chance_scale: float = 1.0, rarity_scale: float = 1.0) -> Array[ItemInstance]:
	var items: Array[ItemInstance] = []
	for i in rolls:
		if rng.randf() >= minf(chance * chance_scale, 1.0):
			continue
		var bases := catalog.bases.filter(func(b: ItemBase) -> bool: return b.min_item_level <= item_level)
		if bases.is_empty():
			continue
		var base: ItemBase = bases[rng.randi_range(0, bases.size() - 1)]
		items.append(catalog.roll(base, item_level, Rarity.roll(rng, min_rarity, rarity_boost * rarity_scale), rng))
	return items
