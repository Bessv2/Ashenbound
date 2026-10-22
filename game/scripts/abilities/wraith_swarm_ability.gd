class_name WraithSwarmAbility
extends Ability
## Wraith Swarm (the Gravecaller, Wraiths): looses `wraiths` spectral wraiths
## at the enemies within `reach`, nearest first, one wraith each (wrapping
## round when there are more wraiths than enemies). Each deals `damage` and
## marks its target to take `mark_bonus` more damage for `mark_seconds`. No
## enemy in reach: no cast, no cooldown.
##
## The wraiths' flight is presentation; the hits are dealt at once, through
## Health.

const COLOR := Color(0.55, 1.0, 0.85)

@export_range(1, 12, 1) var wraiths: int = 3
@export_range(1.0, 30.0, 0.5, "suffix:m") var reach: float = 10.0
@export_range(0, 1000, 1) var damage: int = 9
@export_range(0.0, 2.0, 0.05) var mark_bonus: float = 0.2
@export_range(0.1, 20.0, 0.1, "suffix:s") var mark_seconds: float = 4.0
@export_flags_3d_physics var target_mask: int = 4

## Every hit of the last cast, in order (a target appears once per wraith).
var last_hits: Array[Health] = []

var _extra: int = 0
var _damage_scale: float = 1.0


## Skills: Phantom Swarm (wraith_count); Restless Dead and Phalanx
## (summon_damage_pct): wraiths are summons too.
func apply_stats(stats: CharacterStats, _damage_scale_in: float) -> void:
	_extra = stats.value("wraith_count")
	_damage_scale = 1.0 + stats.value("summon_damage_pct") / 100.0


func wraith_count() -> int:
	return wraiths + _extra


func wraith_damage() -> int:
	return maxi(roundi(damage * power * _damage_scale), 1)


func _activate(_toward: Vector3) -> bool:
	var caster := get_parent() as Node3D
	var targets := Targeting.living_within(caster, reach, target_mask)
	if targets.is_empty():
		return false
	var from := caster.global_position
	targets.sort_custom(func(a: Health, b: Health) -> bool:
		return (a.get_parent() as Node3D).global_position.distance_squared_to(from) \
				< (b.get_parent() as Node3D).global_position.distance_squared_to(from))
	last_hits = []
	for i in wraith_count():
		var target := targets[i % targets.size()]
		if target.is_dead():
			continue
		target.apply_damage(wraith_damage(), from)
		if not target.is_dead():
			Marked.apply(target, mark_bonus, mark_seconds)
		last_hits.append(target)
		if caster.get_parent():
			_streak(caster.get_parent(), from + Vector3.UP * 1.5, (target.get_parent() as Node3D).global_position + Vector3.UP)
	return true


## A pale streak from the caster to a target that fades in 0.3 s.
func _streak(parent: Node, from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var streak := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.18, length)
	streak.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = COLOR
	streak.material_override = material
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(streak)
	streak.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	var tween := streak.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.3).from(0.9)
	tween.tween_callback(streak.queue_free)
	Vfx.burst(parent, to, COLOR, 8, 3.0, 0.3)
