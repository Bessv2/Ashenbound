class_name Inventory
extends Node
## What a character carries: gold, and up to `capacity` items. Add it as a
## direct child of the body that picks loot up; Inventory.of() finds it.

signal gold_changed(total: int)
signal item_added(item: Item)

@export_range(1, 200, 1) var capacity: int = 18

var gold: int = 0
var items: Array[Item] = []


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


func is_full() -> bool:
	return items.size() >= capacity


## Adds `item` unless the inventory is full. Returns whether it was added.
func add_item(item: Item) -> bool:
	if is_full():
		return false
	items.append(item)
	item_added.emit(item)
	return true


## The Inventory on `node` itself or among its direct children, or null.
static func of(node: Node) -> Inventory:
	if node is Inventory:
		return node
	for child in node.get_children():
		if child is Inventory:
			return child
	return null
