class_name RaiseForsakenAbility
extends Ability
## Raise the Forsaken (the Gravecaller's signature, Bone Legion): raises
## `count` skeletons around the hero for `lifetime`, each with `minion_health`
## and its claw (forsaken_claw.tres) scaled by the summon damage skills.
## Casting again dismisses the old ones first, so there are never more than
## `count` (plus Mass Grave's). Always activates.

const MinionScene := preload("res://scenes/player/forsaken_skeleton.tscn")

@export_range(1, 10, 1) var count: int = 2
@export_range(1.0, 120.0, 0.5, "suffix:s") var lifetime: float = 15.0
@export_range(1, 1000, 1) var minion_health: int = 40

## The skeletons raised by the last cast (freed ones drop out).
var raised: Array[Minion] = []

var _base := {}
var _health_scale: float = 1.0
var _damage_scale: float = 1.0
var _duration_scale: float = 1.0
var _extra: int = 0


func _ready() -> void:
	_base = {"count": count}


## Skills: Grave Discipline and Shieldbearers (summon_health_pct), Mass Grave
## (summon_count), Restless Dead and Phalanx (summon_damage_pct), Forsaken
## Host (summon_duration_pct).
func apply_stats(stats: CharacterStats, _damage_scale_in: float) -> void:
	_health_scale = 1.0 + stats.value("summon_health_pct") / 100.0
	_damage_scale = 1.0 + stats.value("summon_damage_pct") / 100.0
	_duration_scale = 1.0 + stats.value("summon_duration_pct") / 100.0
	_extra = stats.value("summon_count")


func summon_count() -> int:
	return _base.get("count", count) + _extra


func summon_lifetime() -> float:
	return lifetime * _duration_scale


func summon_health() -> int:
	return maxi(roundi(minion_health * _health_scale), 1)


func summon_damage_scale() -> float:
	return _damage_scale * power


## The skeletons still standing.
func living() -> Array[Minion]:
	# Untyped: a crumbled skeleton may already be freed.
	return raised.filter(func(m: Variant) -> bool: return is_instance_valid(m) and not (m as Minion).is_gone())


func _activate(_toward: Vector3) -> bool:
	var hero := get_parent() as PlayerController
	for old in living():
		old.crumble()
	raised = []
	var total := summon_count()
	for i in total:
		var minion := MinionScene.instantiate() as Minion
		minion.hero = hero
		minion.lifetime = summon_lifetime()
		minion.health.max_health = summon_health()
		minion.attack.damage_scale = summon_damage_scale()
		var angle := TAU * i / total + PI * 0.25
		hero.add_child(minion)
		minion.global_position = hero.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 1.6
		minion.reset_physics_interpolation()
		if hero.get_parent():
			Vfx.burst(hero.get_parent(), minion.global_position + Vector3.UP * 0.4, Minion.COLOR, 12, 2.5, 0.5)
		raised.append(minion)
	return true
