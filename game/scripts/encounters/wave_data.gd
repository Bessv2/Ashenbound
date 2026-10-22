class_name WaveData
extends Resource
## One wave of an encounter: which enemies appear, and at which spawn markers.

@export var enemies: Array[PackedScene] = []
## The spawn marker for each enemy, by node name under the encounter, matched
## by index. Give each enemy of a wave its own marker: bodies spawned on top of
## each other are pushed apart violently by the physics engine.
@export var markers: PackedStringArray = []
