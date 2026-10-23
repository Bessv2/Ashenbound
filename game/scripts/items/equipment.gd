class_name Equipment
extends RefCounted
## What the hero wears: one item per slot, two ring slots. Equipping an item
## returns whatever it replaced, so nothing is ever lost: the caller puts that
## back in the bag. Plain data, saved with to_dict / from_dict.

signal changed

enum Slot { WEAPON, HELMET, CHEST, GLOVES, BOOTS, RING_1, RING_2, AMULET, RELIC }

const SLOT_NAMES := ["Weapon", "Helmet", "Chest", "Gloves", "Boots", "Ring", "Ring", "Amulet", "Relic"]

## Slot → ItemInstance.
var _items: Dictionary[int, ItemInstance] = {}


## The equipment slots an item of `item_slot` fits (two for rings).
static func slots_for(item_slot: ItemBase.Slot) -> Array[int]:
	match item_slot:
		ItemBase.Slot.WEAPON: return [Slot.WEAPON]
		ItemBase.Slot.HELMET: return [Slot.HELMET]
		ItemBase.Slot.CHEST: return [Slot.CHEST]
		ItemBase.Slot.GLOVES: return [Slot.GLOVES]
		ItemBase.Slot.BOOTS: return [Slot.BOOTS]
		ItemBase.Slot.RING: return [Slot.RING_1, Slot.RING_2]
		ItemBase.Slot.AMULET: return [Slot.AMULET]
		_: return [Slot.RELIC]


## The kind of item (ItemBase.Slot) that equipment slot `slot` holds.
static func item_slot_of(slot: int) -> ItemBase.Slot:
	for kind in ItemBase.Slot.values():
		if slot in slots_for(kind):
			return kind
	return ItemBase.Slot.RELIC


func item_in(slot: int) -> ItemInstance:
	return _items.get(slot)


func all() -> Array[ItemInstance]:
	var list: Array[ItemInstance] = []
	for slot in Slot.values():
		if _items.has(slot):
			list.append(_items[slot])
	return list


## The slot `item` would go into: the first free one it fits, else the first.
func slot_for(item: ItemInstance, catalog: ItemCatalog) -> int:
	var base := catalog.base(item.base_id)
	if base == null:
		return -1
	var fits := slots_for(base.slot)
	for slot in fits:
		if not _items.has(slot):
			return slot
	return fits[0]


## Puts `item` on and returns the item it replaced, or null. Returns `item`
## itself, unchanged, when it fits no slot (an unknown base).
func equip(item: ItemInstance, catalog: ItemCatalog, slot: int = -1) -> ItemInstance:
	var base := catalog.base(item.base_id)
	if base == null:
		return item
	if slot < 0 or not slots_for(base.slot).has(slot):
		slot = slot_for(item, catalog)
	var previous: ItemInstance = _items.get(slot)
	_items[slot] = item
	changed.emit()
	return previous


## Takes off the item in `slot` and returns it, or null.
func unequip(slot: int) -> ItemInstance:
	if not _items.has(slot):
		return null
	var item: ItemInstance = _items[slot]
	_items.erase(slot)
	changed.emit()
	return item


## Every equipped stat added up: stat key → value.
func totals() -> Dictionary[String, int]:
	var total: Dictionary[String, int] = {}
	for item in _items.values():
		var stats := (item as ItemInstance).total_stats()
		for stat in stats:
			total[stat] = total.get(stat, 0) + stats[stat]
	return total


func to_dict() -> Dictionary:
	var out := {}
	for slot in _items:
		out[str(slot)] = _items[slot].to_dict()
	return out


## Restores from `data`, skipping entries that are not valid items. Returns
## how many were skipped.
func load_dict(data: Variant) -> int:
	_items.clear()
	var skipped := 0
	if data is Dictionary:
		for key: Variant in data:
			var slot := int(key)
			var item := ItemInstance.from_dict(data[key])
			if item == null or slot < 0 or slot >= Slot.size():
				skipped += 1
				continue
			_items[slot] = item
	changed.emit()
	return skipped
