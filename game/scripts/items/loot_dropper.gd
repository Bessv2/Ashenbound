class_name LootDropper
extends Node
## Rolls an enemy's DropTable when the run counts its kill and lays the items
## on the floor as LootPickups, into `inventory` (Profile's by default).
## collect_all() takes whatever is still lying around (at victory, when the
## hero can no longer walk to it).

signal dropped(pickup: LootPickup)
signal collected(item: ItemInstance)

@export_range(1, 100, 1) var item_level: int = 1
## Set from the crypt tier: more drops, and rarer ones.
var chance_scale: float = 1.0
var rarity_scale: float = 1.0

var inventory: Inventory
var catalog: ItemCatalog

var _rng := RandomNumberGenerator.new()
var _pickups: Array[LootPickup] = []


func _ready() -> void:
	catalog = ItemCatalog.load_default()
	if inventory == null:
		var profile := get_node_or_null(^"/root/Profile")
		inventory = profile.inventory if profile else Inventory.new()


## Rolls the enemy's drop table, and a Champion's bonus drop too.
func on_enemy_killed(enemy: Node3D) -> void:
	if not enemy is EnemyController:
		return
	var items: Array[ItemInstance] = []
	var table: DropTable = (enemy as EnemyController).drop_table
	if table:
		items.append_array(table.roll(catalog, item_level, _rng, chance_scale, rarity_scale))
	var champion := Champion.of(enemy)
	if champion and champion.bonus_drops:
		items.append_array(champion.bonus_drops.roll(catalog, item_level, _rng, 1.0, rarity_scale))
	for i in items.size():
		var angle := TAU * i / maxf(items.size(), 1.0)
		drop(items[i], enemy.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (0.0 if items.size() == 1 else 1.0))


## Lays `item` on the floor at `at`.
func drop(item: ItemInstance, at: Vector3) -> LootPickup:
	var pickup := LootPickup.new()
	pickup.name = "Loot"
	pickup.item = item
	pickup.inventory = inventory
	pickup.position = Vector3(at.x, 0.0, at.z)
	pickup.picked_up.connect(collected.emit)
	pickup.tree_exited.connect(_pickups.erase.bind(pickup))
	_pickups.append(pickup)
	# Next to the dropper, so the loot goes when its scene goes.
	get_parent().add_child(pickup)
	pickup.global_position = Vector3(at.x, 0.0, at.z)
	dropped.emit(pickup)
	return pickup


## Takes every item still on the floor into the bag (as long as it has room).
## Returns how many were taken.
func collect_all() -> int:
	var taken := 0
	for pickup in _pickups.duplicate():
		if is_instance_valid(pickup) and pickup.collect():
			taken += 1
	return taken


func lying() -> Array[LootPickup]:
	return _pickups.filter(func(p: LootPickup) -> bool: return is_instance_valid(p))
