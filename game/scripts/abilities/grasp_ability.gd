class_name GraspAbility
extends Ability
## Grasp of the Grave (the Hexbinder): hands of the dead clutch at everything
## within `radius` of the caster: `damage` and a slow to `slow_factor` of
## their speed for `slow_seconds`. Room to breathe for a caster who needs
## setup time. Always activates.

const COLOR := Color(0.35, 0.95, 0.7)

@export_range(0.5, 10.0, 0.1, "suffix:m") var radius: float = 4.0
@export_range(0, 1000, 1) var damage: int = 6
@export_range(0.05, 1.0, 0.05) var slow_factor: float = 0.4
@export_range(0.1, 10.0, 0.1, "suffix:s") var slow_seconds: float = 2.5
@export_flags_3d_physics var target_mask: int = 4

var last_grasped: Array[Health] = []
var _scale: float = 1.0


func apply_stats(_stats: CharacterStats, damage_scale: float) -> void:
	_scale = damage_scale


func _activate(_toward: Vector3) -> bool:
	var caster := get_parent() as Node3D
	last_grasped = Targeting.living_within(caster, radius, target_mask)
	for health in last_grasped:
		health.apply_damage(maxi(roundi(damage * _scale), 1), caster.global_position)
		Slowed.apply(health.get_parent(), slow_factor, slow_seconds)
	if caster.get_parent():
		Vfx.ring(caster.get_parent(), caster.global_position, radius, COLOR, 0.55)
		Vfx.burst(caster.get_parent(), caster.global_position + Vector3.UP * 0.3, COLOR, 20, 2.5, 0.6, 0.1)
	return true
