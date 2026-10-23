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
	},
	CATACOMBS: {
		"title": "The Forgotten Catacombs",
		"line": "Ghoul packs, a drowned vault and the Hollow King.",
		"enter": "Enter the catacombs",
		"scene": "res://scenes/dungeon/catacombs.tscn",
		"color": Color(0.4, 0.85, 1.0),
		"music": &"music_catacombs",
	},
}


## Whether `profile` may enter dungeon `id`.
static func is_open(id: String, profile: Node) -> bool:
	if not INFO.has(id):
		return false
	return id == CRYPT or int(profile.tier_cleared) >= 1


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
