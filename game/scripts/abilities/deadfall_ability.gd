class_name DeadfallAbility
extends Ability
## Deadfall (the Dreadhunter's signature, Trapper; docs/characters/
## dreadhunter.md): sets a rune-snare under the nearest enemy within `reach`,
## or `fallback_distance` ahead with none. Always activates. The snare is a
## DeadfallTrap: it holds what stands in it, then erupts in bolts.

const COLOR := Color(1.0, 0.7, 0.25)

@export_range(1.0, 30.0, 0.5, "suffix:m") var reach: float = 12.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var fallback_distance: float = 4.0
@export_range(0.5, 8.0, 0.1, "suffix:m") var radius: float = 3.0
@export_range(0.1, 10.0, 0.1, "suffix:s") var hold_time: float = 2.0
@export_range(1, 30, 1) var bolts: int = 6
@export_range(0, 1000, 1) var bolt_damage: int = 4
@export_flags_3d_physics var target_mask: int = 4

## The snare set by the last cast (freed once it has erupted).
var last_trap: DeadfallTrap

var _base := {}


func _ready() -> void:
	_base = {"hold": hold_time, "bolts": bolts, "damage": bolt_damage}


## Skills: Snare Craft (trap_duration_pct), Bramble Spikes (trap_damage_pct),
## Deadfall Mastery (deadfall_bolts).
func apply_stats(stats: CharacterStats, _damage_scale: float) -> void:
	hold_time = _base.hold * (1.0 + stats.value("trap_duration_pct") / 100.0)
	bolt_damage = maxi(roundi(_base.damage * (1.0 + stats.value("trap_damage_pct") / 100.0)), 1)
	bolts = _base.bolts + stats.value("deadfall_bolts")


func _activate(toward: Vector3) -> bool:
	var hunter := get_parent() as Node3D
	var level := hunter.get_parent()
	if level == null:
		return false
	var target := Targeting.nearest_living(hunter, reach, target_mask)
	var at := hunter.global_position + Vector3(toward.x, 0.0, toward.z).normalized() * fallback_distance
	if target:
		at = (target.get_parent() as Node3D).global_position
	var damage := maxi(roundi(bolt_damage * power), 1)
	last_trap = DeadfallTrap.set_at(level, at, radius, hold_time, bolts, damage, target_mask)
	return true
