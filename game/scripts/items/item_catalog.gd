class_name ItemCatalog
extends Resource
## Every item base and affix in the game. One file
## (res://resources/items/catalog.tres) so saves and drops can find a base by
## its id.

const DEFAULT_PATH := "res://resources/items/catalog.tres"
## Each item level above 1 adds this share to the stat ranges.
const GROWTH_PER_LEVEL := 0.15

@export var bases: Array[ItemBase] = []
@export var affixes: Array[AffixDef] = []


static func load_default() -> ItemCatalog:
	return load(DEFAULT_PATH) as ItemCatalog


func base(id: String) -> ItemBase:
	for each in bases:
		if each.id == id:
			return each
	return null


## Problems with the data (duplicate ids, unknown stats, bad ranges).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var seen := {}
	for each in bases:
		problems.append_array(each.validate())
		if seen.has(each.id):
			problems.append("duplicate base id %s" % each.id)
		seen[each.id] = true
	for affix in affixes:
		if not ItemStats.is_known(affix.stat):
			problems.append("affix with unknown stat %s" % affix.stat)
		if affix.range_at_level_one.x > affix.range_at_level_one.y:
			problems.append("affix %s range is backwards" % affix.stat)
		if affix.slots.is_empty():
			problems.append("affix %s fits no slot" % affix.stat)
	return problems


## `range` scaled to `item_level`.
static func scaled(range_at_one: Vector2i, item_level: int) -> Vector2i:
	var factor := 1.0 + GROWTH_PER_LEVEL * maxi(item_level - 1, 0)
	return Vector2i(roundi(range_at_one.x * factor), roundi(range_at_one.y * factor))


## Rolls one item of `item_base` at `item_level` and `rarity`.
func roll(item_base: ItemBase, item_level: int, rarity: int, rng: RandomNumberGenerator) -> ItemInstance:
	var item := ItemInstance.new()
	item.uid = "%d-%d" % [Time.get_unix_time_from_system() * 1000.0, rng.randi()]
	item.base_id = item_base.id
	item.rarity = rarity
	item.item_level = item_level
	var bonus: float = Rarity.BASE_BONUS[rarity]
	for stat in item_base.base_stats:
		var span := scaled(item_base.base_stats[stat], item_level)
		item.base_stats[stat] = roundi(rng.randi_range(span.x, span.y) * bonus)
	var counts: Array = Rarity.AFFIX_COUNTS[rarity]
	var wanted := rng.randi_range(counts[0], counts[1])
	var pool: Array[AffixDef] = affixes.filter(func(a: AffixDef) -> bool: return a.slots.has(item_base.slot))
	var top_rolls := rarity == Rarity.Tier.MYTHIC
	while item.affixes.size() < wanted and not pool.is_empty():
		var weights := PackedFloat32Array()
		for affix in pool:
			weights.append(affix.weight)
		var picked: AffixDef = pool[rng.rand_weighted(weights)]
		# Each stat at most once per item.
		pool = pool.filter(func(a: AffixDef) -> bool: return a.stat != picked.stat)
		var span := scaled(picked.range_at_level_one, item_level)
		item.affixes.append({"stat": picked.stat, "value": span.y if top_rolls else rng.randi_range(span.x, span.y)})
	return item
