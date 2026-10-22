class_name HitFeedback
extends Node
## Visual reaction to damage: a brief flash on every mesh under `visual`, a
## floating damage number above the parent body, a burst of sparks and a
## quick squash-and-stretch of the visual; on death, a burst of ash and
## embers. Add it as a child of the body that owns
## `health`. Visual only.

@export var health: Health
@export var visual: Node3D
@export var flash_material: Material
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_duration: float = 0.08
@export_range(0.0, 5.0, 0.05, "suffix:m") var number_height: float = 2.6
@export var number_color: Color = DamageNumber.DEFAULT_COLOR
@export var spark_color: Color = Color(1.0, 0.62, 0.25)
## Ash and embers when the body dies (enemies).
@export var death_burst: bool = true

var _flash_tween: Tween
var _punch_tween: Tween
var _visual_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	if visual:
		_visual_scale = visual.scale
	if health:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)


func _on_damaged(amount: int, _remaining: int) -> void:
	var body := get_parent() as Node3D
	if body:
		DamageNumber.spawn(body, amount, number_height, number_color)
		Vfx.burst(body, body.global_position + Vector3.UP * number_height * 0.45, spark_color, 14, 4.5, 0.35)
	if visual == null:
		return
	_punch()
	if flash_material == null:
		return
	_set_overlay(flash_material)
	if _flash_tween:
		_flash_tween.kill()
	# Physics clock: the flash pauses with the game.
	_flash_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_flash_tween.tween_interval(flash_duration)
	_flash_tween.tween_callback(_set_overlay.bind(null))


## Squashes the visual and lets it spring back: the body takes the blow.
func _punch() -> void:
	if _punch_tween:
		_punch_tween.kill()
	visual.scale = _visual_scale * Vector3(1.14, 0.86, 1.14)
	_punch_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_punch_tween.tween_property(visual, "scale", _visual_scale, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_died() -> void:
	var body := get_parent() as Node3D
	if body == null or not death_burst:
		return
	var at := body.global_position + Vector3.UP * 0.8
	Vfx.burst(body.get_parent(), at, Color(0.45, 0.42, 0.4), 30, 3.5, 0.9, 0.16)
	Vfx.burst(body.get_parent(), at, Color(1.0, 0.45, 0.12), 20, 5.5, 0.6, 0.12)


func _set_overlay(material: Material) -> void:
	for mesh in visual.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).material_overlay = material
