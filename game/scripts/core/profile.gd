extends Node
## The player's lasting progress across runs (autoload "Profile"): Ash, the
## bag and the equipment. Kept in memory until saving lands (Milestone 4,
## step 5); server validation comes with Milestone 5. Every reward goes through grant_run_reward(),
## which accepts each run once, so a replayed signal, a double tap or a
## retried request can never pay twice. That is the seam persistence and the
## backend hook into.

signal changed

var ash: int = 0
var inventory := Inventory.new()
var equipment := Equipment.new()
var catalog: ItemCatalog = ItemCatalog.load_default()

## Runs already paid, by run id.
var _claimed: Dictionary[String, int] = {}


## Adds `amount` Ash for run `run_id` and returns true, unless that run was
## already paid (then nothing changes and it returns false).
func grant_run_reward(run_id: String, amount: int) -> bool:
	if run_id == "" or _claimed.has(run_id):
		return false
	_claimed[run_id] = maxi(amount, 0)
	ash += maxi(amount, 0)
	changed.emit()
	return true


func has_claimed(run_id: String) -> bool:
	return _claimed.has(run_id)


## Moves the bag item `uid` onto the hero; whatever it replaces goes back in
## the bag. Returns whether it was equipped.
func equip_from_bag(uid: String) -> bool:
	var item := inventory.take(uid)
	if item == null:
		return false
	var replaced := equipment.equip(item, catalog)
	if replaced == item:
		inventory.add(item)
		return false
	if replaced:
		inventory.add(replaced)
	changed.emit()
	return true


## Moves the item in equipment `slot` into the bag. Refused when the bag is
## full, so the item is never lost.
func unequip_to_bag(slot: int) -> bool:
	if inventory.is_full() or equipment.item_in(slot) == null:
		return false
	inventory.add(equipment.unequip(slot))
	changed.emit()
	return true


## Empties the profile (tests and a future "new game").
func reset() -> void:
	ash = 0
	_claimed.clear()
	inventory.load_list([])
	equipment.load_dict({})
	changed.emit()
