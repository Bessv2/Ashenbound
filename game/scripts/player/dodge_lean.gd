class_name DodgeLean
extends Node
## Placeholder dodge animation: leans and squashes `visual` forward while the
## dash runs, then straightens it. Visual only.

@export var dodge: Dodge
## Turned and scaled. Its origin should be at the feet.
@export var visual: Node3D
## Forward tilt at the height of the dash.
@export_range(0.0, 90.0, 1.0, "degrees") var lean_degrees: float = 30.0
## Height scale at the height of the dash; width grows to keep the volume.
@export_range(0.3, 1.0, 0.01) var squash: float = 0.8

var _tween: Tween


func _ready() -> void:
	if dodge:
		dodge.started.connect(_on_started.unbind(1))
		dodge.finished.connect(_on_finished)
		dodge.canceled.connect(_on_canceled)


func _on_started() -> void:
	# Negative X tips the visual toward its facing (-Z).
	_animate(-deg_to_rad(lean_degrees), squash, 0.06)


func _on_finished() -> void:
	_animate(0.0, 1.0, 0.12)


## Straightens at once, so whatever canceled the dodge (death, for one) can
## animate the visual from rest.
func _on_canceled() -> void:
	if _tween:
		_tween.kill()
	if visual:
		visual.rotation.x = 0.0
		visual.scale = Vector3.ONE


func _animate(lean: float, height: float, duration: float) -> void:
	if _tween:
		_tween.kill()
	if visual == null:
		return
	var width := 1.0 / sqrt(height)
	# Physics clock: the visual is part of the interpolated player.
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	_tween.tween_property(visual, "rotation:x", lean, duration)
	_tween.tween_property(visual, "scale", Vector3(width, height, width), duration)
