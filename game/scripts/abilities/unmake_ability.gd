class_name UnmakeAbility
extends Ability
## Unmake (the Hexbinder): every Cursed enemy within `reach` bursts. Each
## takes, at once, `multiplier` times the curse damage it still had to take,
## and the curse ends. Soul Siphon heals the caster for a share of the damage
## dealt. The payoff for setting curses up: with no cursed enemy in reach,
## nothing happens and no cooldown is spent.

const COLOR := Color(0.8, 0.45, 1.0)

@export_range(1.0, 40.0, 0.5, "suffix:m") var reach: float = 12.0
@export_range(0.1, 10.0, 0.05) var multiplier: float = 1.5
@export_flags_3d_physics var target_mask: int = 4

## Damage dealt and health restored by the last cast.
var last_damage: int = 0
var last_healed: int = 0

var _base_multiplier: float = 1.5
var _siphon: float = 0.0


func _ready() -> void:
	_base_multiplier = multiplier


## Skills: Volatile Hex and Cataclysm Mastery (detonation_damage_pct),
## Hungering Souls and Reaper's Tithe (soul_siphon_pct).
func apply_stats(stats: CharacterStats, _damage_scale: float) -> void:
	multiplier = _base_multiplier * (1.0 + stats.value("detonation_damage_pct") / 100.0)
	_siphon = stats.value("soul_siphon_pct") / 100.0


## The curses within reach, by body.
func cursed_in_reach() -> Array[Burning]:
	var caster := get_parent() as Node3D
	var curses: Array[Burning] = []
	for health in Targeting.living_within(caster, reach, target_mask):
		for child in health.get_parent().get_children():
			if child is Burning and child.name == BlackTestamentAbility.CURSE and not child.is_queued_for_deletion():
				curses.append(child)
	return curses


func _activate(_toward: Vector3) -> bool:
	var curses := cursed_in_reach()
	if curses.is_empty():
		return false
	var caster := get_parent() as Node3D
	last_damage = 0
	for curse in curses:
		var body := curse.get_parent() as Node3D
		var health := Health.of(body)
		var amount := maxi(roundi(curse.damage * curse.ticks_left * multiplier * power), 1)
		curse.ticks_left = 0
		curse.queue_free()
		last_damage += health.apply_damage(amount, caster.global_position)
		if caster.get_parent():
			Vfx.burst(caster.get_parent(), body.global_position + Vector3.UP, COLOR, 26, 5.0, 0.5, 0.14)
			Vfx.smoke(caster.get_parent(), body.global_position + Vector3.UP, COLOR.darkened(0.5), 5, 1.6, 0.9)
			Vfx.ring(caster.get_parent(), body.global_position, 1.8, COLOR, 0.35)
	var own := Health.of(caster)
	last_healed = own.heal(roundi(last_damage * _siphon)) if own and _siphon > 0.0 else 0
	return true
