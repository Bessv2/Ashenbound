extends Node
## The player's lasting progress across runs (autoload "Profile"): Ash, the
## bag and the equipment, saved to `save_path`. Every reward goes through
## grant_run_reward(), which accepts each run once, so a replayed signal, a
## double tap or a retried request can never pay twice. That is the seam the
## backend (Milestone 5) hooks into.
##
## Saving (docs/LOOT.md, Persistence): any change schedules one save at the
## end of the frame. The file is written to a temporary file and then moved
## over the old one, which is kept as the backup, so a crash mid-write never
## leaves only a broken save. Loading falls back to the backup; when both are
## unreadable the game starts fresh and moves the broken file aside. It never
## deletes the player's data on its own.

signal changed

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://profile.json"
## Run ids remembered against double payment (the most recent ones).
const CLAIMED_KEPT := 50

## Where the profile is saved; empty turns saving off (tests).
var save_path: String = DEFAULT_SAVE_PATH

var ash: int = 0
var inventory := Inventory.new()
var equipment := Equipment.new()
var catalog: ItemCatalog = ItemCatalog.load_default()

## Runs already paid, by run id, oldest first.
var _claimed: Dictionary[String, int] = {}
var _save_pending: bool = false


func _ready() -> void:
	inventory.changed.connect(request_save)
	equipment.changed.connect(request_save)
	changed.connect(request_save)
	load_profile()


## Saves at the end of this frame; several changes in a frame cost one save.
func request_save() -> void:
	if save_path == "" or _save_pending:
		return
	_save_pending = true
	save_profile.call_deferred()


func to_dict() -> Dictionary:
	var claimed := _claimed.keys()
	return {
		"version": SAVE_VERSION,
		"ash": ash,
		"claimed": claimed.slice(maxi(claimed.size() - CLAIMED_KEPT, 0)),
		"inventory": inventory.to_list(),
		"equipment": equipment.to_dict(),
	}


## Writes the profile to `save_path` safely. Returns OK or the error.
func save_profile() -> Error:
	_save_pending = false
	if save_path == "":
		return ERR_UNAVAILABLE
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s: %s" % [temporary, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(_backup_path())
		DirAccess.rename_absolute(save_path, _backup_path())
	return DirAccess.rename_absolute(temporary, save_path)


## Loads `save_path`, or its backup when it is unreadable. Returns OK, or
## ERR_FILE_NOT_FOUND on a first launch, or ERR_FILE_CORRUPT when neither file
## could be read (the game then starts fresh; the broken file is kept aside).
func load_profile() -> Error:
	if save_path == "":
		return ERR_UNAVAILABLE
	if not FileAccess.file_exists(save_path) and not FileAccess.file_exists(_backup_path()):
		return ERR_FILE_NOT_FOUND
	for path in [save_path, _backup_path()]:
		var data: Variant = _read_json(path)
		if data is Dictionary and _apply(data):
			return OK
	push_warning("The saved profile could not be read; starting fresh. The file was kept aside.")
	if FileAccess.file_exists(save_path):
		DirAccess.rename_absolute(save_path, "%s.broken-%d" % [save_path, Time.get_unix_time_from_system()])
	_apply_empty()
	return ERR_FILE_CORRUPT


func _backup_path() -> String:
	return save_path.get_basename() + ".backup.json"


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	# JSON.parse() reports a broken file quietly; we handle it ourselves.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data


## Takes the profile from `data`. Returns false, changing nothing, when it is
## not a profile this version understands.
func _apply(data: Dictionary) -> bool:
	if int(data.get("version", 0)) < 1 or int(data.get("version", 0)) > SAVE_VERSION:
		return false
	if not data.get("inventory") is Array or not data.get("equipment") is Dictionary:
		return false
	ash = maxi(int(data.get("ash", 0)), 0)
	_claimed.clear()
	if data.get("claimed") is Array:
		for run_id: Variant in data.claimed:
			_claimed[str(run_id)] = 0
	var skipped := inventory.load_list(data.inventory) + equipment.load_dict(data.equipment)
	if skipped > 0:
		push_warning("%d saved items could not be read and were left out." % skipped)
	_save_pending = false
	return true


func _apply_empty() -> void:
	ash = 0
	_claimed.clear()
	inventory.load_list([])
	equipment.load_dict({})
	_save_pending = false


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
