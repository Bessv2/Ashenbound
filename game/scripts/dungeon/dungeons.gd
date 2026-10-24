class_name Dungeons
extends RefCounted
## The dungeons a run can be played in (docs/dungeons/), in the order they
## open. The Ashen Crypt is open from the start; each of the others opens once
## the one before it has been cleared at any tier. Crypt tiers are shared: the
## tier chosen on the title screen applies to whichever dungeon is entered.
## The five regions after the catacombs are written by
## tools/levels/make_regions.py (docs/dungeons/regions.md).

const CRYPT := "crypt"
const CATACOMBS := "catacombs"
const KEEP := "keep"
const FOREST := "forest"
const VOLCANO := "volcano"
const TEMPLE := "temple"
const ICE := "ice"
const ORDER: Array[String] = [CRYPT, CATACOMBS, KEEP, FOREST, VOLCANO, TEMPLE, ICE]
const INFO := {
	CRYPT: {
		"title": "The Ashen Crypt",
		"line": "Skeletons, cultists, a Fallen Knight and the Ashen Lord.",
		"enter": "Enter the crypt",
		"short": "the crypt",
		"scene": "res://scenes/dungeon/crypt.tscn",
		"color": Color(1.0, 0.55, 0.25),
		"music": &"music_crypt",
		"icon": "region_crypt",
		# The hero levels it is meant for, shown on its card.
		"levels": Vector2i(1, 10),
		# Material → chance per kill to drop one (docs/CRAFTING.md).
		"materials": {"iron_ore": 0.35, "wood": 0.25, "crystal": 0.06},
	},
	CATACOMBS: {
		"title": "The Forgotten Catacombs",
		"line": "Ghoul packs, a drowned vault and the Hollow King.",
		"enter": "Enter the catacombs",
		"short": "the catacombs",
		"scene": "res://scenes/dungeon/catacombs.tscn",
		"color": Color(0.4, 0.85, 1.0),
		"music": &"music_catacombs",
		"icon": "region_catacombs",
		"levels": Vector2i(5, 15),
		"materials": {"leather": 0.3, "herbs": 0.3, "crystal": 0.08},
	},
	KEEP: {
		"title": "The Ruined Keep",
		"line": "Barracks, an armoury and the Iron Castellan.",
		"enter": "Storm the keep",
		"short": "the keep",
		"scene": "res://scenes/dungeon/keep.tscn",
		"color": Color(0.75, 0.8, 0.95),
		"music": &"music_crypt",
		"icon": "region_keep",
		"levels": Vector2i(10, 15),
		"materials": {"iron_ore": 0.4, "wood": 0.25, "leather": 0.1},
	},
	FOREST: {
		"title": "The Cursed Forest",
		"line": "Ghouls among the graves, and the Rotwood Witch.",
		"enter": "Enter the forest",
		"short": "the forest",
		"scene": "res://scenes/dungeon/forest.tscn",
		"color": Color(0.5, 0.95, 0.55),
		"music": &"music_catacombs",
		"icon": "region_forest",
		"levels": Vector2i(12, 18),
		"materials": {"herbs": 0.4, "wood": 0.35, "leather": 0.15},
	},
	VOLCANO: {
		"title": "The Volcanic Depths",
		"line": "Demons, imps and the Cinder Tyrant.",
		"enter": "Descend into the fire",
		"short": "the depths",
		"scene": "res://scenes/dungeon/volcano.tscn",
		"color": Color(1.0, 0.45, 0.2),
		"music": &"music_crypt",
		"icon": "region_volcano",
		"levels": Vector2i(15, 22),
		"materials": {"iron_ore": 0.3, "crystal": 0.12},
	},
	TEMPLE: {
		"title": "The Ancient Temple",
		"line": "Broken vows, endless candles and the Sunless Oracle.",
		"enter": "Enter the temple",
		"short": "the temple",
		"scene": "res://scenes/dungeon/temple.tscn",
		"color": Color(1.0, 0.85, 0.45),
		"music": &"music_crypt",
		"icon": "region_temple",
		"levels": Vector2i(20, 26),
		"materials": {"crystal": 0.15, "herbs": 0.25, "iron_ore": 0.2},
	},
	ICE: {
		"title": "The Ice Wastes",
		"line": "The frozen fallen, and the Rime King.",
		"enter": "Cross the wastes",
		"short": "the wastes",
		"scene": "res://scenes/dungeon/ice.tscn",
		"color": Color(0.7, 0.88, 1.0),
		"music": &"music_catacombs",
		"icon": "region_ice",
		"levels": Vector2i(25, 30),
		"materials": {"crystal": 0.2, "leather": 0.3},
	},
}


## Whether `profile` may enter dungeon `id`: the crypt always, any other once
## the dungeon before it has been cleared.
static func is_open(id: String, profile: Node) -> bool:
	if not INFO.has(id):
		return false
	var index := ORDER.find(id)
	return index == 0 or profile.has_cleared(ORDER[index - 1])


## The dungeon whose clear opens `id` ("" for the crypt).
static func previous(id: String) -> String:
	var index := ORDER.find(id)
	return ORDER[index - 1] if index > 0 else ""


## Why dungeon `id` is shut to `profile`, or "" when it is open.
static func lock_reason(id: String, profile: Node) -> String:
	if is_open(id, profile):
		return ""
	return "Clear %s to open" % INFO[previous(id)].short


## Material → chance per ordinary kill in dungeon `id`.
static func materials_of(id: String) -> Dictionary:
	return INFO.get(id, INFO[CRYPT]).materials


## "Lv 1-10".
static func level_range(id: String) -> String:
	var levels: Vector2i = INFO.get(id, INFO[CRYPT]).levels
	return "Lv %d-%d" % [levels.x, levels.y]


## The level scene of dungeon `id` (the crypt's for an unknown id).
static func scene_path(id: String) -> String:
	return INFO.get(id, INFO[CRYPT]).scene


## The music played while exploring dungeon `id` (a SoundBank track).
static func music_of(id: String) -> StringName:
	return INFO.get(id, INFO[CRYPT]).music


## Whether `scene_path` is the level of one of the dungeons.
static func has_scene(scene_path: String) -> bool:
	return ORDER.any(func(id: String) -> bool: return INFO[id].scene == scene_path)


## The dungeon whose level is `scene_path` (the crypt's for any other level).
static func id_of_scene(scene_path: String) -> String:
	for id in ORDER:
		if INFO[id].scene == scene_path:
			return id
	return CRYPT
