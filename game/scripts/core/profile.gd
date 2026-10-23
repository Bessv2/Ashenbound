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
## 4 added materials and camps; older saves load with none, and their camps
## start working on load when the crypt was cleared.
## 5 added the dungeons cleared; older saves count the crypt as cleared when
## a tier was.
## 6 added quests, achievements, daily challenges and the counters behind
## them; older saves start them from nothing.
const SAVE_VERSION := 6
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
## The dungeons cleared at least once (Dungeons ids): each opens the next.
var cleared_dungeons: Array[String] = []
## Lifetime counters behind achievements and dailies (Quests keys).
var stats: Dictionary[String, int] = {}
## Dungeon id → the titles of its story objectives done.
var quest_progress: Dictionary[String, Array] = {}
## Story quests, achievements and today's dailies already paid.
var quests_claimed: Array[String] = []
var achievements_claimed: Array[String] = []
var daily_claimed: Array[String] = []
## The day the dailies belong to, and the counters at its start.
var daily_day: int = -1
var daily_base: Dictionary[String, int] = {}
## Crafting materials held: Materials id → amount.
var materials: Dictionary[String, int] = {}
## The gathering camps once open: Camps id → {"level", "since"} (since = when
## its store was last emptied, device clock).
var camps: Dictionary[String, Dictionary] = {}
## Crafting's dice, replaceable in tests.
var rng := RandomNumberGenerator.new()

## Runs already paid, by run id, oldest first.
var _claimed: Dictionary[String, int] = {}
var _save_pending: bool = false


func _ready() -> void:
	rng.randomize()
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
		"cleared_dungeons": cleared_dungeons.duplicate(),
		"stats": stats.duplicate(),
		"quest_progress": quest_progress.duplicate(true),
		"quests_claimed": quests_claimed.duplicate(),
		"achievements_claimed": achievements_claimed.duplicate(),
		"daily": {"day": daily_day, "base": daily_base.duplicate(), "claimed": daily_claimed.duplicate()},
		"materials": materials.duplicate(),
		"camps": camps.duplicate(true),
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
	cleared_dungeons.clear()
	if data.get("cleared_dungeons") is Array:
		for id: Variant in data.cleared_dungeons:
			if Dungeons.INFO.has(str(id)) and not cleared_dungeons.has(str(id)):
				cleared_dungeons.append(str(id))
	_load_quests(data)
	# Saves from before version 5: a cleared tier means the crypt was cleared.
	if tier_cleared >= 1 and not cleared_dungeons.has(Dungeons.CRYPT):
		cleared_dungeons.append(Dungeons.CRYPT)
	# Saves from before the second dungeon play the crypt.
	dungeon = str(data.get("dungeon", Dungeons.CRYPT))
	if not Dungeons.is_open(dungeon, self):
		dungeon = Dungeons.CRYPT
	offline_seconds = clampi(int(data.get("offline_seconds", 0)), 0, OfflineRewards.CAP_SECONDS)
	materials.clear()
	if data.get("materials") is Dictionary:
		for id: Variant in data.materials:
			if Materials.is_material(str(id)) and int(data.materials[id]) > 0:
				materials[str(id)] = int(data.materials[id])
	camps.clear()
	if data.get("camps") is Dictionary:
		for id: Variant in data.camps:
			var camp: Variant = data.camps[id]
			if Camps.INFO.has(str(id)) and camp is Dictionary:
				camps[str(id)] = {"level": clampi(int(camp.get("level", 1)), 1, Camps.MAX_LEVEL),
						"since": maxi(int(camp.get("since", 0)), 0)}
	_open_camps()
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
	materials.clear()
	camps.clear()
	cleared_dungeons.clear()
	_clear_quests()
	_claimed.clear()
	inventory.load_list([])
	equipment.load_dict({})
	_save_pending = false


## Adds `amount` Ash, `gold_amount` gold and the materials `found` for run
## `run_id` and returns true, unless that run was already paid (then nothing
## changes and it returns false).
func grant_run_reward(run_id: String, amount: int, gold_amount: int = 0, found: Dictionary = {}) -> bool:
	if run_id == "" or _claimed.has(run_id):
		return false
	_claimed[run_id] = maxi(amount, 0)
	ash += maxi(amount, 0)
	gold += maxi(gold_amount, 0)
	_add_materials(found)
	changed.emit()
	return true


## Breaks bag item `uid` down into gold and some materials
## (Crafting.salvage_materials). Returns the gold gained, or 0 when the item
## is not in the bag (worn items must be taken off first).
func salvage(uid: String) -> int:
	var item := inventory.take(uid)
	if item == null:
		return 0
	var value := Forge.salvage_gold(item)
	gold += value
	_add_materials(Crafting.salvage_materials(item, catalog.base(item.base_id)))
	count(Quests.SALVAGED)
	return value


func material(id: String) -> int:
	return materials.get(id, 0)


func _add_materials(found: Dictionary) -> void:
	for id: Variant in found:
		if Materials.is_material(str(id)) and int(found[id]) > 0:
			materials[str(id)] = material(str(id)) + int(found[id])


## What `cost` (materials, "gold", "ash") lacks, as "3 Iron Ore", or "" when
## the profile can pay it.
func missing_for(cost: Dictionary) -> String:
	var short := {}
	for id: String in cost:
		var have := gold if id == Materials.GOLD else ash if id == Materials.ASH else material(id)
		if have < int(cost[id]):
			short[id] = int(cost[id]) - have
	return Materials.describe(short)


## Pays `cost` when it can all be paid; returns whether it was.
func _pay(cost: Dictionary) -> bool:
	if missing_for(cost) != "":
		return false
	for id: String in cost:
		if id == Materials.GOLD:
			gold -= int(cost[id])
		elif id == Materials.ASH:
			ash -= int(cost[id])
		else:
			materials[id] = material(id) - int(cost[id])
			if materials[id] <= 0:
				materials.erase(id)
	return true


## Why base `base_id` cannot be crafted now, or "".
func craft_problem(base_id: String) -> String:
	var base := catalog.base(base_id)
	if base == null:
		return "No such item."
	if inventory.is_full():
		return "The bag is full."
	var short := missing_for(Crafting.craft_cost(base, Crafting.craft_level(level)))
	return "Missing %s." % short if short != "" else ""


## Crafts an item of base `base_id` into the bag, paying for it. Returns the
## item, or null (nothing paid) when it cannot be crafted.
func craft_item(base_id: String) -> ItemInstance:
	if craft_problem(base_id) != "":
		return null
	var base := catalog.base(base_id)
	var item_level := Crafting.craft_level(level)
	_pay(Crafting.craft_cost(base, item_level))
	var item := Crafting.craft(catalog, base, item_level, rng)
	inventory.add(item)
	count(Quests.CRAFTED)
	return item


## Rerolls affix `index` of `item` (in the bag or worn). Returns "" or why not.
func enchant_item(item: ItemInstance, index: int) -> String:
	if item == null or not _owns(item):
		return "Not yours."
	if index < 0 or index >= item.affixes.size():
		return "Choose an affix to enchant."
	var short := missing_for(Crafting.enchant_cost(item))
	if short != "":
		return "Missing %s." % short
	if not Crafting.enchant(catalog, item, index, rng):
		return "No other stat fits this item."
	_pay(Crafting.enchant_cost(item))
	_item_changed(item)
	count(Quests.ENCHANTED)
	return ""


## Raises `item` one rarity (the concept sheet's Legendary step). Returns ""
## or why not.
func ascend_item(item: ItemInstance) -> String:
	if item == null or not _owns(item):
		return "Not yours."
	if not Crafting.can_ascend(item):
		return "Already Legendary."
	var cost := Crafting.ascend_cost(item)
	var short := missing_for(cost)
	if short != "":
		return "Missing %s." % short
	_pay(cost)
	Crafting.ascend(catalog, item, rng)
	_item_changed(item)
	count(Quests.ASCENDED)
	return ""


func _owns(item: ItemInstance) -> bool:
	return inventory.has(item.uid) or equipment.all().has(item)


## A worn item changed: the hero's stats follow.
func _item_changed(item: ItemInstance) -> void:
	if equipment.all().has(item):
		equipment.changed.emit()
	else:
		inventory.changed.emit()
	changed.emit()


func _clear_quests() -> void:
	stats.clear()
	quest_progress.clear()
	quests_claimed.clear()
	achievements_claimed.clear()
	daily_claimed.clear()
	daily_day = -1
	daily_base.clear()


func _load_quests(data: Dictionary) -> void:
	_clear_quests()
	if data.get("stats") is Dictionary:
		for key: Variant in data.stats:
			stats[str(key)] = maxi(int(data.stats[key]), 0)
	if data.get("quest_progress") is Dictionary:
		for id: Variant in data.quest_progress:
			if Quests.STORY.has(str(id)) and data.quest_progress[id] is Array:
				var done: Array = []
				for title: Variant in data.quest_progress[id]:
					if Quests.STORY[str(id)].objectives.has(str(title)) and not done.has(str(title)):
						done.append(str(title))
				quest_progress[str(id)] = done
	for list_name in ["quests_claimed", "achievements_claimed"]:
		if data.get(list_name) is Array:
			var target: Array[String] = get(list_name)
			for id: Variant in data[list_name]:
				if not target.has(str(id)):
					target.append(str(id))
	if data.get("daily") is Dictionary:
		daily_day = int(data.daily.get("day", -1))
		if data.daily.get("base") is Dictionary:
			for key: Variant in data.daily.base:
				daily_base[str(key)] = int(data.daily.base[key])
		if data.daily.get("claimed") is Array:
			for id: Variant in data.daily.claimed:
				daily_claimed.append(str(id))


## Adds `amount` to counter `stat` (Quests keys).
func count(stat: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	_roll_daily()
	stats[stat] = stat_count(stat) + amount
	changed.emit()


func stat_count(stat: String) -> int:
	return stats.get(stat, 0)


## Marks the story objective of `dungeon_id` named after the fight `title`
## (EncounterController.title) as done. Returns true the first time.
func record_encounter(dungeon_id: String, title: String) -> bool:
	if not Quests.STORY.has(dungeon_id) or not Quests.STORY[dungeon_id].objectives.has(title):
		return false
	var done: Array = quest_progress.get(dungeon_id, [])
	if done.has(title):
		return false
	done = done.duplicate()
	done.append(title)
	quest_progress[dungeon_id] = done
	changed.emit()
	return true


## Whether story objective `index` of `dungeon_id` is done.
func objective_done(dungeon_id: String, index: int) -> bool:
	var objectives: Array = Quests.STORY[dungeon_id].objectives
	return index < objectives.size() and quest_progress.get(dungeon_id, []).has(objectives[index])


func quest_complete(dungeon_id: String) -> bool:
	return quest_progress.get(dungeon_id, []).size() >= Quests.STORY[dungeon_id].objectives.size()


## Pays the story quest of `dungeon_id`: its reward and an item of at least
## its rarity, at the hero's level. Returns "" or why not.
func claim_quest(dungeon_id: String) -> String:
	if not Quests.STORY.has(dungeon_id):
		return "No such quest."
	if quests_claimed.has(dungeon_id):
		return "Already claimed."
	if not quest_complete(dungeon_id):
		return "Not finished yet."
	if inventory.is_full():
		return "Make room in the bag first."
	var quest: Dictionary = Quests.STORY[dungeon_id]
	quests_claimed.append(dungeon_id)
	_grant(quest.reward)
	var bases := catalog.bases
	var base: ItemBase = bases[rng.randi_range(0, bases.size() - 1)]
	inventory.add(catalog.roll(base, Crafting.craft_level(level), Rarity.roll(rng, quest.item_rarity, 1.0), rng))
	changed.emit()
	return ""


## Achievement `id`'s progress: Vector2i(now, goal).
func achievement_progress(id: String) -> Vector2i:
	var entry := Quests.achievement(id)
	return Vector2i(mini(stat_count(entry[2]), entry[3]), entry[3]) if not entry.is_empty() else Vector2i.ZERO


func claim_achievement(id: String) -> String:
	var entry := Quests.achievement(id)
	if entry.is_empty():
		return "No such achievement."
	if achievements_claimed.has(id):
		return "Already claimed."
	if stat_count(entry[2]) < entry[3]:
		return "Not yet."
	achievements_claimed.append(id)
	_grant(entry[4])
	changed.emit()
	return ""


## Starts a new day's dailies when the date has changed: today's three,
## counted from now. Yesterday's unfinished ones simply go.
func _roll_daily() -> void:
	var today := Quests.day_of(clock.call())
	if today == daily_day:
		return
	daily_day = today
	daily_base = stats.duplicate()
	daily_claimed.clear()


## Today's challenges: [{"id", "text", "progress", "goal", "reward", "claimed"}].
func dailies() -> Array[Dictionary]:
	_roll_daily()
	var list: Array[Dictionary] = []
	for entry: Array in Quests.dailies_of(daily_day):
		var progress := mini(stat_count(entry[2]) - daily_base.get(entry[2], 0), entry[3])
		list.append({"id": entry[0], "text": entry[1], "progress": maxi(progress, 0), "goal": entry[3],
				"reward": entry[4], "claimed": daily_claimed.has(entry[0])})
	return list


func claim_daily(id: String) -> String:
	for challenge in dailies():
		if challenge.id != id:
			continue
		if challenge.claimed:
			return "Already claimed."
		if challenge.progress < challenge.goal:
			return "Not yet."
		daily_claimed.append(id)
		_grant(challenge.reward)
		changed.emit()
		return ""
	return "Not one of today's."


## Adds a reward's gold, Ash and materials.
func _grant(reward: Dictionary) -> void:
	gold += int(reward.get(Materials.GOLD, 0))
	ash += int(reward.get(Materials.ASH, 0))
	_add_materials(reward)


## Rewards that can be claimed now (story, achievements, dailies), for a
## badge on the Quests button.
func claimable_count() -> int:
	var total := 0
	for id: String in Quests.STORY:
		if quest_complete(id) and not quests_claimed.has(id):
			total += 1
	for entry: Array in Quests.ACHIEVEMENTS:
		if not achievements_claimed.has(entry[0]) and stat_count(entry[2]) >= entry[3]:
			total += 1
	for challenge in dailies():
		if not challenge.claimed and challenge.progress >= challenge.goal:
			total += 1
	return total


func has_cleared(dungeon_id: String) -> bool:
	return cleared_dungeons.has(dungeon_id)


## Records a clear of dungeon `dungeon_id`, which opens the next one. Returns
## true the first time.
func complete_dungeon(dungeon_id: String) -> bool:
	if not Dungeons.INFO.has(dungeon_id) or has_cleared(dungeon_id):
		return false
	cleared_dungeons.append(dungeon_id)
	changed.emit()
	return true


## Whether the camps work: once the crypt has been cleared.
func camps_open() -> bool:
	return tier_cleared >= 1


## Starts any camp not yet working, once they are open. Time before that
## earns nothing.
func _open_camps() -> void:
	if not camps_open():
		return
	for id in Camps.ORDER:
		if not camps.has(id):
			camps[id] = {"level": 1, "since": clock.call()}


func camp_level(id: String) -> int:
	return int(camps[id].level) if camps.has(id) else 0


## What camp `id` holds now (Materials id → amount).
func camp_stock(id: String) -> Dictionary:
	if not camps.has(id):
		return {}
	# A clock that went backwards counts as no time.
	return Camps.stock(id, camp_level(id), maxi(clock.call() - int(camps[id].since), 0))


## Moves camp `id`'s store into the materials. Returns what was taken.
func collect_camp(id: String) -> Dictionary:
	var taken := camp_stock(id)
	if not camps.has(id):
		return taken
	camps[id].since = clock.call()
	_add_materials(taken)
	if taken.values().any(func(amount: int) -> bool: return amount > 0):
		count(Quests.CAMP_COLLECTS)
	changed.emit()
	return taken


## Collects every camp; returns the sum taken.
func collect_all_camps() -> Dictionary:
	var total := {}
	for id in camps:
		var taken := collect_camp(id)
		for material_id: String in taken:
			total[material_id] = int(total.get(material_id, 0)) + int(taken[material_id])
	return total


## Raises camp `id` one level, collecting its store first so nothing gathered
## at the old rate is lost or recounted. Returns "" or why not.
func upgrade_camp(id: String) -> String:
	if not camps.has(id):
		return "The camps open once the crypt is cleared."
	if camp_level(id) >= Camps.MAX_LEVEL:
		return "Fully built."
	var cost := Camps.upgrade_cost(id, camp_level(id))
	var short := missing_for(cost)
	if short != "":
		return "Missing %s." % short
	collect_camp(id)
	_pay(cost)
	camps[id].level = camp_level(id) + 1
	count(Quests.CAMP_UPGRADES)
	return ""


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
	# Any clear means the crypt was cleared: it is the only way in.
	if cleared >= 1 and not has_cleared(Dungeons.CRYPT):
		cleared_dungeons.append(Dungeons.CRYPT)
	_open_camps()
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
	materials.clear()
	camps.clear()
	cleared_dungeons.clear()
	_clear_quests()
	_claimed.clear()
	inventory.load_list([])
	equipment.load_dict({})
	changed.emit()
