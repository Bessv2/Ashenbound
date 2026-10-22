extends Node
## The player's lasting progress across runs (autoload "Profile"): Ash, the
## bag, the equipment, the hero's level and XP and learned skills, saved to
## `save_path`. Every reward goes through
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
signal leveled_up(level: int)

## 2 added level, XP and skills; version 1 saves load with level 1.
## 3 added crypt tiers; older saves load with tier 1 open.
const SAVE_VERSION := 3
const MAX_LEVEL := 30
## The class the player plays (only the Warden so far).
const HERO_CLASS := "warden"
const DEFAULT_SAVE_PATH := "user://profile.json"
## Run ids remembered against double payment (the most recent ones).
const CLAIMED_KEPT := 50

## Where the profile is saved; empty turns saving off (tests).
var save_path: String = DEFAULT_SAVE_PATH

var ash: int = 0
var inventory := Inventory.new()
var equipment := Equipment.new()
var catalog: ItemCatalog = ItemCatalog.load_default()
var level: int = 1
## XP gathered toward the next level.
var xp: int = 0
## Class id → {node id → rank}.
var skill_ranks: Dictionary[String, Dictionary] = {}
## The highest crypt tier the player may enter (clearing a tier opens the next).
var tier_unlocked: int = 1
## The tier the next run is played at.
var tier: int = 1

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
		"level": level,
		"xp": xp,
		"skills": skill_ranks.duplicate(true),
		"tier_unlocked": tier_unlocked,
		"tier": tier,
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
	level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(int(data.get("xp", 0)), 0)
	tier_unlocked = clampi(int(data.get("tier_unlocked", 1)), 1, Difficulty.MAX_TIER)
	tier = clampi(int(data.get("tier", 1)), 1, tier_unlocked)
	skill_ranks.clear()
	if data.get("skills") is Dictionary:
		for class_id: Variant in data.skills:
			var learned := {}
			if data.skills[class_id] is Dictionary:
				for node_id: Variant in data.skills[class_id]:
					learned[str(node_id)] = maxi(int(data.skills[class_id][node_id]), 0)
			skill_ranks[str(class_id)] = learned
	var skipped := inventory.load_list(data.inventory) + equipment.load_dict(data.equipment)
	if skipped > 0:
		push_warning("%d saved items could not be read and were left out." % skipped)
	_save_pending = false
	return true


func _apply_empty() -> void:
	level = 1
	xp = 0
	skill_ranks.clear()
	tier_unlocked = 1
	tier = 1
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


## Records a clear of crypt tier `cleared`: the next tier opens. Clearing a
## tier again changes nothing. Returns true when a new tier opened.
func complete_tier(cleared: int) -> bool:
	var opened := clampi(cleared + 1, 1, Difficulty.MAX_TIER)
	if opened <= tier_unlocked:
		return false
	tier_unlocked = opened
	changed.emit()
	return true


## Chooses the tier of the next run, within the open tiers. Returns the tier.
func select_tier(wanted: int) -> int:
	var chosen := clampi(wanted, 1, tier_unlocked)
	if chosen != tier:
		tier = chosen
		changed.emit()
	return tier


## XP needed to go from `from_level` to the next.
static func xp_to_next(from_level: int) -> int:
	return roundi(100.0 * pow(from_level, 1.5))


## Adds XP, levelling up as many times as it covers. Returns levels gained.
func add_xp(amount: int) -> int:
	if amount <= 0 or level >= MAX_LEVEL:
		return 0
	xp += amount
	var gained := 0
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
		leveled_up.emit(level)
	if level >= MAX_LEVEL:
		xp = 0
	changed.emit()
	return gained


func ranks(class_id: String) -> Dictionary:
	return skill_ranks.get(class_id, {})


func points_spent(class_id: String) -> int:
	var spent := 0
	for rank: int in ranks(class_id).values():
		spent += rank
	return spent


## One point per level after the first, per class.
func points_available(class_id: String) -> int:
	return level - 1 - points_spent(class_id)


## Spends a point on `node_id` of `tree`. Returns "" or why it could not.
func learn(tree: SkillTree, node_id: String) -> String:
	var held := ranks(tree.class_id)
	var problem := tree.learn_problem(held, node_id, points_available(tree.class_id))
	if problem != "":
		return problem
	held = held.duplicate()
	held[node_id] = int(held.get(node_id, 0)) + 1
	skill_ranks[tree.class_id] = held
	changed.emit()
	return ""


## Refunds every point of `class_id`.
func reset_skills(class_id: String) -> void:
	skill_ranks.erase(class_id)
	changed.emit()


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
	level = 1
	xp = 0
	skill_ranks.clear()
	tier_unlocked = 1
	tier = 1
	ash = 0
	_claimed.clear()
	inventory.load_list([])
	equipment.load_dict({})
	changed.emit()
