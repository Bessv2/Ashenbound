class_name BenedictionAbility
extends Ability
## Last Benediction (the Reliquary's signature, Atonement; docs/characters/
## reliquary.md): a wave of spectral light from the hero. Every enemy within
## `radius` takes `damage`, and the hero heals `heal_share` of its maximum
## health. Healing never passes MAX_HEAL_SHARE of it, however it is raised,
## so sustain stays bounded. Always activates.

const COLOR := Color(0.65, 0.85, 1.0)
## The most one Benediction can heal, as a share of max health.
const MAX_HEAL_SHARE := 0.3

@export_range(0.5, 12.0, 0.1, "suffix:m") var radius: float = 5.0
@export_range(0, 1000, 1) var damage: int = 12
@export_range(0.0, 1.0, 0.01) var heal_share: float = 0.15
@export var health: Health
@export_flags_3d_physics var target_mask: int = 4

var last_struck: Array[Health] = []
var last_healed: int = 0

var _heal_scale: float = 1.0
var _damage_scale: float = 1.0


## Skills: Mercy (healing_pct) and Benediction Mastery
## (benediction_heal_pct) raise the heal; Lantern Light and Judgment
## (radiance_damage_pct) raise the light's damage.
func apply_stats(stats: CharacterStats, _damage_scale_in: float) -> void:
	_heal_scale = 1.0 + (stats.value("healing_pct") + stats.value("benediction_heal_pct")) / 100.0
	_damage_scale = 1.0 + stats.value("radiance_damage_pct") / 100.0


## Health one cast restores (before the hero's missing health limits it).
func heal_amount() -> int:
	var max_health := health.max_health if health else 100
	return mini(roundi(max_health * heal_share * _heal_scale), roundi(max_health * MAX_HEAL_SHARE))


func strike_damage() -> int:
	var zeal := MartyrZeal.of(get_parent())
	return maxi(roundi(damage * power * _damage_scale * (zeal.factor() if zeal else 1.0)), 1)


func _activate(_toward: Vector3) -> bool:
	var hero := get_parent() as Node3D
	last_struck = Targeting.living_within(hero, radius, target_mask)
	for target in last_struck:
		target.apply_damage(strike_damage(), hero.global_position)
	last_healed = health.heal(heal_amount()) if health else 0
	if hero.get_parent():
		Vfx.ring(hero.get_parent(), hero.global_position, radius, COLOR, 0.6)
		Vfx.burst(hero.get_parent(), hero.global_position + Vector3.UP * 1.2, COLOR, 26, 3.5, 0.7, 0.12)
	return true
