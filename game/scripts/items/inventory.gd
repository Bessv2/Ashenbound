class_name Inventory
extends RefCounted
## The bag: up to `capacity` items, in the order they were found.

signal changed

const DEFAULT_CAPACITY := 30

var capacity: int = DEFAULT_CAPACITY
var items: Array[ItemInstance] = []


func is_full() -> bool:
	return items.size() >= capacity


## Adds `item` unless the bag is full or already holds it. Returns whether it
## was added.
func add(item: ItemInstance) -> bool:
	if item == null or is_full() or has(item.uid):
		return false
	items.append(item)
	changed.emit()
	return true


func has(uid: String) -> bool:
	return items.any(func(i: ItemInstance) -> bool: return i.uid == uid)


## Takes the item with `uid` out and returns it, or null.
func take(uid: String) -> ItemInstance:
	for i in items.size():
		if items[i].uid == uid:
			var item := items[i]
			items.remove_at(i)
			changed.emit()
			return item
	return null


func to_list() -> Array:
	return items.map(func(i: ItemInstance) -> Dictionary: return i.to_dict())


## Restores from `data`; returns how many entries were skipped as invalid.
func load_list(data: Variant) -> int:
	items.clear()
	var skipped := 0
	if data is Array:
		for entry: Variant in data:
			var item := ItemInstance.from_dict(entry)
			if item == null or items.size() >= capacity:
				skipped += 1
			else:
				items.append(item)
	changed.emit()
	return skipped
