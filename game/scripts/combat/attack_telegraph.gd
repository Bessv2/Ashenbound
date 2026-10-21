class_name AttackTelegraph
extends MeshInstance3D
## A flat warning sector on the ground that shows where a MeleeAttack will
## land. Visible only during the attack's windup and growing more opaque as the
## hit approaches, so the player can see it coming and step out of it.
## Place it under the attacker's facing node, at floor height.

@export var attack: MeleeAttack
@export_range(4, 64, 1) var segments: int = 20

var _tween: Tween


func _ready() -> void:
	hide()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if attack == null:
		return
	mesh = build_sector(attack.data.reach, attack.data.arc_degrees, segments)
	attack.started.connect(_on_started.unbind(1))
	attack.struck.connect(_on_finished.unbind(1))
	attack.canceled.connect(_on_finished)


## A flat fan in the XZ plane covering `arc_degrees`, centered on -Z (the
## direction a Node3D faces).
static func build_sector(radius: float, arc_degrees: float, segment_count: int) -> ArrayMesh:
	var half := deg_to_rad(minf(arc_degrees, 360.0)) * 0.5
	var vertices := PackedVector3Array()
	for i in segment_count:
		vertices.append(Vector3.ZERO)
		vertices.append(_point_at(lerpf(-half, half, float(i) / segment_count), radius))
		vertices.append(_point_at(lerpf(-half, half, float(i + 1) / segment_count), radius))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var sector := ArrayMesh.new()
	sector.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return sector


## The point at `radius` along -Z rotated by `angle` around +Y.
static func _point_at(angle: float, radius: float) -> Vector3:
	return Vector3(-sin(angle), 0.0, -cos(angle)) * radius


func _on_started() -> void:
	show()
	if _tween:
		_tween.kill()
	transparency = 0.7
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(self, "transparency", 0.1, maxf(attack.data.windup, 0.01))


func _on_finished() -> void:
	if _tween:
		_tween.kill()
	hide()
