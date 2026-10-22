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
## Time away was banked and offline rewards wait to be collected.
signal offline_ready

## 2 added level, XP and skills; version 1 saves load with level 1.
## 3 added crypt tiers; older saves load with tier 1 open.
const SAVE_VERSION := 3
const MAX_LEVEL := 30
## The class a new profile plays.
const HERO_CLASS := "warden"
const DEFAULT_SAVE_PATH := "user://profile.json"
## Run ids remembered against double payment (the most recent ones).
const CLAIMED_KEPT := 50

## Where the profile is saved; empty turns saving off (tests).
var save_path: String = DEFAULT_SAVE_PATH

var ash: int = 0
var gold: int = 0
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
## The class the player plays (its id, as in the skill trees).
var hero_class: String = HERO_CLASS
## The highest crypt tier cleared (0 when none): what time away farms.
var tier_cleared: int = 0
## The dungeon the next run is played in (Dungeons.ORDER).
var dungeon: String = Dungeons.CRYPT
## When the profile was last saved (device clock, unix seconds); 0 = never.
var last_seen: int = 0
## Time away banked for offline rewards, waiting to be collected (seconds,
## at most OfflineRewards.CAP_SECONDS).
var offline_seconds: int = 0
## The clock, replaceable in tests. Device time: provisional until the
## Milestone 5 server gives trusted time.
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())

## Runs already paid, by run id, oldest first.
var _claimed: Dictionary[String, int] = {}
var _save_pending: bool = false


func _ready() -> void:
	inventory.changed.connect(request_save)
	equipment.changed.connect(request_save)
	changed.connect(request_save)
	load_profile()
	bank_time_away()


func _notification(what: int) -> void:
	# On a phone the app is usually sent to the background, not closed.
	if what == NOTIFICATION_APPLICATION_PAUSED and save_path != "":
		save_profile()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		bank_time_away()


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
		"gold": gold,
		"claimed": claimed.slice(maxi(claimed.size() - CLAIMED_KEPT, 0)),
		"inventory": inventory.to_list(),
		"equipment": equipment.to_dict(),
		"level": level,
		"xp": xp,
		"skills": skill_ranks.duplicate(true),
		"tier_unlocked": tier_unlocked,
		"tier": tier,
		"tier_cleared": tier_cleared,
		"hero_class": hero_class,
		"dungeon": dungeon,
		"last_seen": last_seen,
		"offline_seconds": offline_seconds,
	}


## Writes the profile to `save_path` safely. Returns OK or the error.
func save_profile() -> Error:
	_save_pending = false
	if save_path == "":
		return ERR_UNAVAILABLE
	last_seen = clock.call()
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
	gold = maxi(int(data.get("gold", 0)), 0)
	_claimed.clear()
	if data.get("claimed") is Array:
		for run_id: Variant in data.claimed:
			_claimed[str(run_id)] = 0
	level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(int(data.get("xp", 0)), 0)
	tier_unlocked = clampi(int(data.get("tier_unlocked", 1)), 1, Difficulty.MAX_TIER)
	tier = clampi(int(data.get("tier", 1)), 1, tier_unlocked)
	# Saves from before tier_cleared: the tier below the highest one open.
	tier_cleared = clampi(int(data.get("tier_cleared", tier_unlocked - 1)), tier_unlocked - 1, Difficulty.MAX_TIER)
	last_seen = maxi(int(data.get("last_seen", 0)), 0)
	hero_class = str(data.get("hero_class", HERO_CLASS))
	# Saves from before the second dungeon play the crypt.
	dungeon = str(data.get("dungeon", Dungeons.CRYPT))
	if not Dungeons.is_open(dungeon, self):
		dungeon = Dungeons.CRYPT
	offline_seconds = clampi(int(data.get("offline_seconds", 0)), 0, OfflineRewards.CAP_SECONDS)
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
	tier_cleared = 0
	hero_class = HERO_CLASS
	dungeon = Dungeons.CRYPT
	last_seen = 0
	offline_seconds = 0
	ash = 0
	gold = 0
	_claimed.clear()
	inventory.load_list([])
	equipment.load_dict({})
	_save_pending = false


## Adds `amount` Ash and `gold_amount` gold for run `run_id` and returns
## true, unless that run was already paid (then nothing changes and it
## returns false).
func grant_run_reward(run_id: String, amount: int, gold_amount: int = 0) -> bool:
	if run_id == "" or _claimed.has(run_id):
		return false
	_claimed[run_id] = maxi(amount, 0)
	ash += maxi(amount, 0)
	gold += maxi(gold_amount, 0)
	changed.emit()
	return true


## Breaks bag item `uid` down into gold. Returns the gold gained, or 0 when
## the item is not in the bag (worn items must be taken off first).
func salvage(uid: String) -> int:
	var item := inventory.take(uid)
	if item == null:
		return 0
	var value := Forge.salvage_gold(item)
	gold += value
	changed.emit()
	return value


## Why `item` cannot be upgraded now, or "" when it can.
func upgrade_problem(item: ItemInstance) -> String:
	if item == null:
		return "No item."
	if item.upgrade >= Forge.MAX_UPGRADE:
		return "Fully upgraded."
	if gold < Forge.upgrade_gold(item):
		return "Not enough gold."
	if ash < Forge.upgrade_ash(item):
		return "Not enough Ash."
	return ""


## Upgrades `item` (in the bag or worn) one rank, paying gold and Ash.
## Returns "" or why it could not.
func upgrade_item(item: ItemInstance) -> String:
	var problem := upgrade_problem(item)
	if problem != "":
		return problem
	if not inventory.has(item.uid) and not equipment.all().has(item):
		return "Not yours."
	gold -= Forge.upgrade_gold(item)
	ash -= Forge.upgrade_ash(item)
	item.upgrade += 1
	if equipment.all().has(item):
		# Worn: the hero's stats follow.
		equipment.changed.emit()
	else:
		inventory.changed.emit()
	changed.emit()
	return ""


func has_claimed(run_id: String) -> bool:
	return _claimed.has(run_id)


## Records a clear of crypt tier `cleared`: the next tier opens. Clearing a
## tier again changes nothing. Returns true when a new tier opened.
func complete_tier(cleared: int) -> bool:
	var was_cleared := tier_cleared
	tier_cleared = clampi(maxi(tier_cleared, cleared), 0, Difficulty.MAX_TIER)
	var opened := clampi(cleared + 1, 1, Difficulty.MAX_TIER)
	var newly_open := opened > tier_unlocked
	if newly_open:
		tier_unlocked = opened
	if newly_open or tier_cleared != was_cleared:
		changed.emit()
	return newly_open


## Adds the time since `last_seen` to the offline bank, when a tier has been
## cleared and the absence is long enough, and starts counting from now. A
## clock that went backwards banks nothing. Returns the seconds banked.
func bank_time_away() -> int:
	var now: int = clock.call()
	var away := now - last_seen
	var banked := 0
	if last_seen > 0 and tier_cleared >= 1 and away >= OfflineRewards.MIN_SECONDS:
		banked = mini(away, OfflineRewards.CAP_SECONDS - offline_seconds)
		offline_seconds += banked
	last_seen = now
	if banked > 0:
		changed.emit()
		offline_ready.emit()
	return banked


## What the banked time would give now: {"xp", "gold", "ash"}.
func offline_preview() -> Dictionary:
	return OfflineRewards.earned(offline_seconds, tier_cleared)


## Pays the banked time's rewards once and empties the bank. Returns them.
func claim_offline() -> Dictionary:
	var reward := offline_preview()
	offline_seconds = 0
	ash += reward.ash
	gold += reward.gold
	add_xp(reward.xp)
	changed.emit()
	return reward


## Plays `class_id` from the next run on (Main checks that it is playable).
func select_class(class_id: String) -> void:
	if class_id != hero_class:
		hero_class = class_id
		changed.emit()


## Plays dungeon `id` from the next run on, when it is open. Returns whether
## it is now the chosen one.
func select_dungeon(id: String) -> bool:
	if not Dungeons.is_open(id, self):
		return false
	if id != dungeon:
		dungeon = id
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
	tier_cleared = 0
	hero_class = HERO_CLASS
	dungeon = Dungeons.CRYPT
	last_seen = 0
	offline_seconds = 0
	ash = 0
	gold = 0
	_claimed.clear()
	inventory.load_list([])
	equipment.load_dict({})
	changed.emit()
