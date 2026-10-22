class_name BrandAbility
extends Ability
## Ember Brand: sets the nearest living enemy within `reach` burning. With no
## enemy in range it does not activate, so no cooldown is spent.

@export_range(0.5, 50.0, 0.1, "suffix:m") var reach: float = 7.0
## Physics layers that can be branded (default: layer 3, "enemy").
@export_flags_3d_physics var target_mask: int = 4
@export_range(1, 1000, 1) var damage_per_tick: int = 4
@export_range(0.05, 10.0, 0.05, "suffix:s") var tick_interval: float = 0.5
@export_range(1, 100, 1) var tick_count: int = 8

## The body branded last.
var last_target: Node3D


func _activate(_toward: Vector3) -> bool:
	var target := Targeting.nearest_living(get_parent() as Node3D, reach, target_mask)
	if target == null:
		return false
	Burning.apply(target, maxi(roundi(damage_per_tick * power), 1), tick_interval, tick_count)
	last_target = target.get_parent() as Node3D
	return true
