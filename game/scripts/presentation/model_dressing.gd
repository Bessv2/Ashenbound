class_name ModelDressing
extends Node
## Dresses an imported model for this game: swaps in a material, gives single
## parts their own material (glowing eyes), and hides the parts it does not
## use (the KayKit Knight carries every weapon and shield). Visual only.

@export var model: Node3D
## Replaces the model's own material on every visible part.
@export var material: Material
## Part name → material, overriding `material` for that part.
@export var part_materials: Dictionary[String, Material] = {}
## Parts to hide, by node name.
@export var hidden_parts: PackedStringArray = []
## A clip to hold for good, for models that never move (a dormant skeleton).
@export var pose_animation: StringName = &""


func _ready() -> void:
	if model == null:
		return
	for part: GeometryInstance3D in model.find_children("*", "GeometryInstance3D", true, false):
		if part.name in hidden_parts:
			part.visible = false
		elif part_materials.has(String(part.name)):
			part.material_override = part_materials[String(part.name)]
		elif material:
			part.material_override = material
	if pose_animation != &"":
		for player: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
			if player.has_animation(pose_animation):
				player.play(pose_animation)
