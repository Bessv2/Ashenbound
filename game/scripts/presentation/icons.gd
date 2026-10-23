class_name Icons
extends RefCounted
## The game's icons: white SVGs from game-icons.net (CC BY 3.0, see
## assets/third_party/game_icons/CREDITS.md, written by
## tools/art/fetch_icons.py), tinted where they are drawn.

const FOLDER := "res://assets/third_party/game_icons/"
const SLOT_KEYS := ["slot_weapon", "slot_helmet", "slot_chest", "slot_gloves", "slot_boots",
		"slot_ring", "slot_amulet", "slot_relic"]

## The icon called `key` (a file name without .svg), or null when there is none.
## Godot's resource cache keeps each loaded once.
static func of(key: String) -> Texture2D:
	var path := FOLDER + key + ".svg"
	return load(path) if ResourceLoader.exists(path) else null


## The icon of an ability, by the label it shows on the HUD ("CLEAVE").
static func for_ability(label: String) -> Texture2D:
	return of("ability_" + label.to_lower())


## The icon of a class's basic attack.
static func for_attack(class_id: String) -> Texture2D:
	return of("attack_" + class_id)


## The icon of an equipment slot (ItemBase.Slot).
static func for_slot(slot: int) -> Texture2D:
	return of(SLOT_KEYS[clampi(slot, 0, SLOT_KEYS.size() - 1)])
