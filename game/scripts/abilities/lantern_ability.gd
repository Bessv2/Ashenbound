class_name LanternAbility
extends Ability
## Hallowed Lantern (the Reliquary, Radiance): sets a lantern at the hero's
## feet for `lifetime`. Every `pulse_interval` it burns every enemy within
## `radius` for `damage`, and heals the hero `heal` while the hero stands in
## its light. One lantern at a time; a new one replaces the old. Always
## activates. The lantern belongs to the level.

const COLOR := Color(0.55, 0.8, 1.0)

@export_range(0.5, 30.0, 0.5, "suffix:s") var lifetime: float = 6.0
@export_range(0.1, 5.0, 0.05, "suffix:s") var pulse_interval: float = 1.0
@export_range(0.5, 10.0, 0.1, "suffix:m") var radius: float = 4.0
@export_range(0, 1000, 1) var damage: int = 5
@export_range(0, 1000, 1) var heal: int = 2
@export var health: Health
@export_flags_3d_physics var target_mask: int = 4

## The lantern set by the last cast.
var last_lantern: HallowedLantern

var _heal_scale: float = 1.0
var _damage_scale: float = 1.0


## Skills: Mercy (healing_pct); Lantern Light and Judgment
## (radiance_damage_pct).
func apply_stats(stats: CharacterStats, _damage_scale_in: float) -> void:
	_heal_scale = 1.0 + stats.value("healing_pct") / 100.0
	_damage_scale = 1.0 + stats.value("radiance_damage_pct") / 100.0


func pulse_damage() -> int:
	var zeal := MartyrZeal.of(get_parent())
	return maxi(roundi(damage * power * _damage_scale * (zeal.factor() if zeal else 1.0)), 1)


func pulse_heal() -> int:
	return maxi(roundi(heal * _heal_scale), 0)


func _activate(_toward: Vector3) -> bool:
	var hero := get_parent() as Node3D
	var level := hero.get_parent()
	if level == null:
		return false
	if last_lantern and is_instance_valid(last_lantern):
		last_lantern.queue_free()
	last_lantern = HallowedLantern.new()
	last_lantern.name = "HallowedLantern"
	last_lantern.ability = self
	last_lantern.hero_health = health
	level.add_child(last_lantern)
	last_lantern.global_position = Vector3(hero.global_position.x, 0.0, hero.global_position.z)
	return true
