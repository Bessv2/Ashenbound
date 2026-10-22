class_name AffixDef
extends Resource
## One affix an item can roll: a stat, its range at item level 1, and the
## slots it may appear on.

@export var stat: String = ""
@export var range_at_level_one: Vector2i = Vector2i(1, 1)
@export var slots: Array[ItemBase.Slot] = []
@export var weight: float = 1.0
