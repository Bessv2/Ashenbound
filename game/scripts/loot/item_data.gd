class_name ItemData
extends Resource
## A kind of item that can drop. The rarity is rolled separately, so one
## ItemData covers every tier of it.

enum Slot { WEAPON, ARMOR, TRINKET }

@export var id: StringName
@export var display_name: String = ""
@export var slot: Slot = Slot.WEAPON
