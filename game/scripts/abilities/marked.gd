class_name Marked
extends Node3D
## A mark on a body (the Reaver's Veil Rend): its Health takes `bonus` more
## damage (0.25 = +25%) for `seconds`. Marking a marked body restarts the
## time and keeps the larger bonus; marks never stack. When the mark ends,
## or the body goes, the Health is restored exactly.
##
## The crimson sign above the body is visual only.

const MARK_HEIGHT := 2.7
const MARK_COLOR := Color(0.85, 0.08, 0.12)

var bonus: float = 0.25
var seconds_left: float = 0.0

var _health: Health
var _applied: float = 1.0


## Marks `target`'s body, or refreshes the mark on it. Returns the mark.
static func apply(target: Health, extra_damage: float, seconds: float) -> Marked:
	var body := target.get_parent()
	var mark := of(body)
	if mark == null:
		mark = Marked.new()
		mark.name = "Marked"
		mark._health = target
		mark.add_child(_build_sign())
		body.add_child(mark)
	mark.seconds_left = maxf(seconds, mark.seconds_left)
	mark._set_bonus(maxf(extra_damage, mark.bonus if mark._applied > 1.0 else 0.0))
	return mark


## The mark on `body`, or null.
static func of(body: Node) -> Marked:
	for child in body.get_children():
		if child is Marked and not child.is_queued_for_deletion():
			return child
	return null


func _physics_process(delta: float) -> void:
	seconds_left -= delta
	if seconds_left <= 0.0 or _health.is_dead():
		_set_bonus(0.0)
		queue_free()


func _exit_tree() -> void:
	_set_bonus(0.0)


func _set_bonus(value: float) -> void:
	if _health == null:
		return
	# Undo the factor applied before, then apply the new one, so other
	# multipliers on the Health (none on enemies today) are kept.
	_health.damage_multiplier /= _applied
	bonus = value
	_applied = 1.0 + value
	_health.damage_multiplier *= _applied


static func _build_sign() -> MeshInstance3D:
	var sign := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.16
	mesh.outer_radius = 0.24
	mesh.rings = 12
	mesh.ring_segments = 6
	sign.mesh = mesh
	sign.position.y = MARK_HEIGHT
	sign.rotation.x = PI / 2.0
	sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = MARK_COLOR
	material.emission_enabled = true
	material.emission = MARK_COLOR
	material.emission_energy_multiplier = 2.0
	sign.material_override = material
	return sign
