class_name LootDropper
extends Node
## Drops loot from `loot_table` where its parent body dies: gold and any items
## scatter in a ring around the body, as siblings of the body (it is freed
## after its death animation; the drops outlive it).

## How far from the body drops land.
const SCATTER_RADIUS := 1.0

@export var loot_table: LootTable
@export var health: Health

## Randomized when ready. Tests set a seed for repeatable drops.
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	if health:
		health.died.connect(_on_died)


func _on_died() -> void:
	if loot_table == null:
		return
	var body := get_parent() as Node3D
	var gold := loot_table.roll_gold(rng)
	var items := loot_table.roll_items(rng)
	# Deferred: death can arrive mid physics step, and new areas are best added
	# outside it.
	_spawn.call_deferred(body.get_parent(), body.global_position, gold, items)


func _spawn(world: Node, origin: Vector3, gold: int, items: Array[Item]) -> void:
	if not is_instance_valid(world):
		return
	var count := items.size() + (1 if gold > 0 else 0)
	var start_angle := rng.randf() * TAU
	var spots: Array[Vector3] = []
	for i in count:
		var angle := start_angle + TAU * float(i) / float(count)
		spots.append(origin + Vector3(cos(angle), 0.0, sin(angle)) * SCATTER_RADIUS)
	var from := origin + Vector3(0.0, 0.8, 0.0)
	if gold > 0:
		LootDrop.spawn_gold(world, from, spots.pop_back(), gold)
	for item in items:
		LootDrop.spawn_item(world, from, spots.pop_back(), item)
