class_name Dungeons
extends RefCounted
## The dungeons a run can be played in (docs/dungeons/), in the order they
## open. The Ashen Crypt is open from the start; the Forgotten Catacombs open
## once the crypt has been cleared at any tier. Crypt tiers are shared: the
## tier chosen on the title screen applies to whichever dungeon is entered.

const CRYPT := "crypt"
const CATACOMBS := "catacombs"
const ORDER: Array[String] = [CRYPT, CATACOMBS]
const INFO := {
	CRYPT: {
		"title": "The Ashen Crypt",
		"line": "Skeletons, cultists, a Fallen Knight and the Ashen Lord.",
		"enter": "Enter the crypt",
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
		"scene": "res://scenes/dungeon/catacombs.tscn",
		"color": Color(0.4, 0.85, 1.0),
		"music": &"music_catacombs",
		"icon": "region_catacombs",
		"levels": Vector2i(5, 15),
		"materials": {"leather": 0.3, "herbs": 0.3, "crystal": 0.08},
	},
}


## Whether `profile` may enter dungeon `id`.
static func is_open(id: String, profile: Node) -> bool:
	if not INFO.has(id):
		return false
	return id == CRYPT or int(profile.tier_cleared) >= 1


## Why dungeon `id` is shut to `profile`, or "" when it is open.
static func lock_reason(id: String, profile: Node) -> String:
	if is_open(id, profile):
		return ""
	return "Clear the crypt to open"


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


## The dungeon whose level is `scene_path` (the crypt's for any other level).
static func id_of_scene(scene_path: String) -> String:
	for id in ORDER:
		if INFO[id].scene == scene_path:
			return id
	return CRYPT
