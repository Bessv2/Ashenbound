class_name HitFeedback
extends Node
## Visual reaction to damage: a brief flash on every mesh under `visual`, and
## a floating damage number above the parent body. Add it as a child of the
## body that owns `health`.

@export var health: Health
@export var visual: Node3D
@export var flash_material: Material
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_duration: float = 0.08
@export_range(0.0, 5.0, 0.05, "suffix:m") var number_height: float = 2.6
@export var number_color: Color = DamageNumber.DEFAULT_COLOR

var _flash_tween: Tween


func _ready() -> void:
	if health:
		health.damaged.connect(_on_damaged)


func _on_damaged(amount: int, _remaining: int) -> void:
	var body := get_parent() as Node3D
	if body:
		DamageNumber.spawn(body, amount, number_height, number_color)
	if visual == null or flash_material == null:
		return
	_set_overlay(flash_material)
	if _flash_tween:
		_flash_tween.kill()
	# Physics clock: the flash pauses with the game.
	_flash_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_flash_tween.tween_interval(flash_duration)
	_flash_tween.tween_callback(_set_overlay.bind(null))


func _set_overlay(material: Material) -> void:
	for mesh in visual.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).material_overlay = material
