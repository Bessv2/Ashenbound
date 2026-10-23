class_name BlackTestamentAbility
extends Ability
## Black Testament (the Hexbinder's signature, docs/characters/hexbinder.md):
## speaks a curse over the nearest enemy within `reach` and everything within
## `radius` of it. Each takes `hit` at once and is Cursed: `damage_per_tick`
## every `tick_interval`, `tick_count` times (a "Cursed" damage over time,
## separate from burns and bleeds). Unmake detonates what is left of it. No
## enemy in reach: nothing happens and no cooldown is spent.

const CURSE := "Cursed"
const CURSE_COLOR := Color(0.62, 0.3, 1.0)

@export_range(1.0, 30.0, 0.5, "suffix:m") var reach: float = 11.0
@export_range(0.5, 10.0, 0.1, "suffix:m") var radius: float = 3.5
@export_range(0, 1000, 1) var hit: int = 6
@export_range(1, 1000, 1) var damage_per_tick: int = 3
@export_range(0.05, 5.0, 0.05, "suffix:s") var tick_interval: float = 0.5
@export_range(1, 100, 1) var tick_count: int = 12
## Physics layers that can be cursed (default: layer 3, "enemy").
@export_flags_3d_physics var target_mask: int = 4

## The bodies cursed by the last cast.
var last_cursed: Array[Health] = []

var _base := {}


func _ready() -> void:
	_base = {"radius": radius, "hit": hit, "damage": damage_per_tick, "ticks": tick_count}


## Skills: Withering Word (curse_duration_pct), Spreading Blight and Frailty
## (curse_damage_pct), Black Testament Mastery (black_testament_pct: a wider
## area and a harder first hit).
func apply_stats(stats: CharacterStats, _damage_scale: float) -> void:
	var mastery: float = stats.value("black_testament_pct") / 100.0
	radius = _base.radius * (1.0 + mastery * 0.5)
	hit = roundi(_base.hit * (1.0 + mastery))
	damage_per_tick = maxi(roundi(_base.damage * (1.0 + stats.value("curse_damage_pct") / 100.0)), 1)
	tick_count = maxi(roundi(_base.ticks * (1.0 + stats.value("curse_duration_pct") / 100.0)), 1)


func _activate(_toward: Vector3) -> bool:
	var caster := get_parent() as Node3D
	var target := Targeting.nearest_living(caster, reach, target_mask)
	if target == null:
		return false
	var center := (target.get_parent() as Node3D).global_position
	last_cursed = Targeting.living_around(caster, center, radius, target_mask)
	for health in last_cursed:
		if hit > 0:
			health.apply_damage(maxi(roundi(hit * power), 1), center)
		if not health.is_dead():
			Burning.apply(health, maxi(roundi(damage_per_tick * power), 1), tick_interval, tick_count, CURSE, CURSE_COLOR)
	if caster.get_parent():
		Vfx.ring(caster.get_parent(), center, radius, CURSE_COLOR)
		Vfx.burst(caster.get_parent(), center + Vector3.UP, CURSE_COLOR, 24, 3.0, 0.6, 0.12)
		Vfx.smoke(caster.get_parent(), center + Vector3.UP * 0.4, CURSE_COLOR.darkened(0.5), 6, 1.8, 1.1)
	return true
