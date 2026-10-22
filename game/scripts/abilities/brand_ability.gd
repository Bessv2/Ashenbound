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
## The damage over time it applies, and the colour of its mark.
@export var effect: String = "Burning"
@export var mark_color: Color = Burning.MARK_COLOR

## The body branded last.
var last_target: Node3D

var _base_damage: int = 0
var _base_ticks: int = 0


func _ready() -> void:
	_base_damage = damage_per_tick
	_base_ticks = tick_count


## Skills: Searing Brand (BRAND_TICK_DAMAGE) and Wildfire (BRAND_TICKS).
func apply_stats(stats: CharacterStats, _damage_scale: float) -> void:
	damage_per_tick = _base_damage + stats.value(SkillStats.BRAND_TICK_DAMAGE)
	tick_count = _base_ticks + stats.value(SkillStats.BRAND_TICKS)


func _activate(_toward: Vector3) -> bool:
	var target := Targeting.nearest_living(get_parent() as Node3D, reach, target_mask)
	if target == null:
		return false
	Burning.apply(target, maxi(roundi(damage_per_tick * power), 1), tick_interval, tick_count, effect, mark_color)
	last_target = target.get_parent() as Node3D
	return true
