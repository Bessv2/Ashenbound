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
	var look := ArtStyle.current()
	if body:
		DamageNumber.spawn(body, amount, number_height, number_color)
		var at := body.global_position + Vector3.UP * number_height * 0.45
		match look:
			ArtStyle.Look.HEROIC:
				RealFx.impact(body, at, _is_flesh())
			ArtStyle.Look.GRIM:
				ToonFx.impact(body, at, _is_flesh())
			_:
				Vfx.burst(body, at, spark_color, 14, 4.5, 0.35)
	if visual == null:
		return
	_punch(look)
	if flash_material == null:
		return
	_set_overlay(flash_material)
	if _flash_tween:
		_flash_tween.kill()
	# Physics clock: the flash pauses with the game.
	_flash_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_flash_tween.tween_interval(flash_duration)
	_flash_tween.tween_callback(_set_overlay.bind(null))


## The body takes the blow: a squash that springs back. Look A flinches
## instead (a jolt backward that recovers); look B squashes much harder.
func _punch(look: ArtStyle.Look = ArtStyle.Look.CLASSIC) -> void:
	if _punch_tween:
		_punch_tween.kill()
	_punch_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	match look:
		ArtStyle.Look.HEROIC:
			visual.scale = _visual_scale * Vector3(1.04, 0.96, 1.04)
			visual.rotation.x = -0.28
			_punch_tween.set_parallel()
			_punch_tween.tween_property(visual, "rotation:x", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_punch_tween.tween_property(visual, "scale", _visual_scale, 0.2)
		ArtStyle.Look.GRIM:
			visual.scale = _visual_scale * Vector3(1.38, 0.62, 1.38)
			_punch_tween.tween_property(visual, "scale", _visual_scale, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_:
			visual.scale = _visual_scale * Vector3(1.14, 0.86, 1.14)
			_punch_tween.tween_property(visual, "scale", _visual_scale, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Heroes bleed; the undead shed bone.
func _is_flesh() -> bool:
	return get_parent() is PlayerController

func _on_died() -> void:
	var body := get_parent() as Node3D
	if body == null or not death_burst:
		return
	var at := body.global_position + Vector3.UP * 0.8
	match ArtStyle.current():
		ArtStyle.Look.HEROIC:
			RealFx.death(body.get_parent(), at, _is_flesh())
		ArtStyle.Look.GRIM:
			ToonFx.death(body.get_parent(), at, _is_flesh())
		_:
			Vfx.burst(body.get_parent(), at, Color(0.45, 0.42, 0.4), 30, 3.5, 0.9, 0.16)
			Vfx.burst(body.get_parent(), at, Color(1.0, 0.45, 0.12), 20, 5.5, 0.6, 0.12)


func _set_overlay(material: Material) -> void:
	for mesh in visual.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).material_overlay = material
