class_name JudgmentAbility
extends Ability
## Martyr's Judgment (the Reliquary, Martyrdom): pays `health_cost` of the
## hero's maximum health to smite the nearest enemy within `reach` and
## everything within `radius` of it for `damage`.
##
## Safeguards against paying itself to death (charter): it is refused, with
## no cooldown spent, while the hero is at or below `min_health_share` of
## its health, and the cost never takes the last point. No enemy in reach:
## no cast, no cost, no cooldown.

const COLOR := Color(0.85, 0.92, 1.0)

@export_range(1.0, 30.0, 0.5, "suffix:m") var reach: float = 9.0
@export_range(0.5, 10.0, 0.1, "suffix:m") var radius: float = 3.0
@export_range(0, 1000, 1) var damage: int = 28
@export_range(0.0, 0.5, 0.01) var health_cost: float = 0.1
@export_range(0.0, 1.0, 0.01) var min_health_share: float = 0.2
@export var health: Health
@export_flags_3d_physics var target_mask: int = 4

var last_smitten: Array[Health] = []
var last_paid: int = 0

var _damage_scale: float = 1.0


## Skills: Lantern Light and Judgment (radiance_damage_pct).
func apply_stats(stats: CharacterStats, _damage_scale_in: float) -> void:
	_damage_scale = 1.0 + stats.value("radiance_damage_pct") / 100.0


func smite_damage() -> int:
	var zeal := MartyrZeal.of(get_parent())
	return maxi(roundi(damage * power * _damage_scale * (zeal.factor() if zeal else 1.0)), 1)


## Whether the hero is healthy enough to pay.
func can_pay() -> bool:
	return health != null and health.current > health.max_health * min_health_share


func _activate(_toward: Vector3) -> bool:
	if not can_pay():
		return false
	var hero := get_parent() as Node3D
	var target := Targeting.nearest_living(hero, reach, target_mask)
	if target == null:
		return false
	# Paid by lowering health directly: it is not a hit, so neither armour,
	# a guard nor a dodge changes it, and it never takes the last point.
	last_paid = mini(roundi(health.max_health * health_cost), health.current - 1)
	health.current -= last_paid
	health.damaged.emit(last_paid, health.current)
	var zeal_damage := smite_damage()
	var center := (target.get_parent() as Node3D).global_position
	last_smitten = Targeting.living_around(hero, center, radius, target_mask)
	for each in last_smitten:
		each.apply_damage(zeal_damage, center)
	if hero.get_parent():
		Vfx.ring(hero.get_parent(), center, radius, COLOR, 0.4)
		Vfx.burst(hero.get_parent(), center + Vector3.UP * 2.0, COLOR, 30, 6.0, 0.5, 0.14)
	return true
