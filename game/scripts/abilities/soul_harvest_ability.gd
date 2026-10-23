class_name SoulHarvestAbility
extends Ability
## Soul Harvest (the Gravecaller, Soul Harvest): gathers a soul from each
## enemy that dies within `gather_radius` of the hero, up to `max_souls`.
## Casting spends every soul: each enemy within `radius` takes
## `damage_per_soul` × souls, and the hero heals `heal_per_soul` × souls.
## No soul: no cast, no cooldown. The HUD button shows the souls held.
##
## Deaths are noticed by watching the Healths of the enemies near the hero
## each tick: one shape query, no global signal.

const COLOR := Color(0.4, 1.0, 0.75)

@export_range(1.0, 30.0, 0.5, "suffix:m") var gather_radius: float = 10.0
@export_range(1, 50, 1) var max_souls: int = 10
@export_range(0.5, 12.0, 0.1, "suffix:m") var radius: float = 6.0
@export_range(0, 1000, 1) var damage_per_soul: int = 6
@export_range(0, 100, 1) var heal_per_soul: int = 3
@export var health: Health
@export_flags_3d_physics var target_mask: int = 4

var souls: int = 0
var last_damage: int = 0
var last_healed: int = 0

var _watched: Array[Health] = []
var _soul_scale: float = 1.0


## Skills: Soul Well and Hungry Grave (soul_harvest_pct) make each soul
## worth more.
func apply_stats(stats: CharacterStats, _damage_scale_in: float) -> void:
	_soul_scale = 1.0 + stats.value("soul_harvest_pct") / 100.0


func badge_text() -> String:
	return str(souls)


func _physics_process(delta: float) -> void:
	super(delta)
	for watched in _watched:
		if is_instance_valid(watched) and watched.is_dead():
			souls = mini(souls + 1, max_souls)
	var hero := get_parent() as Node3D
	if hero and hero.is_inside_tree():
		_watched = Targeting.living_within(hero, gather_radius, target_mask)


func harvest_damage() -> int:
	return maxi(roundi(damage_per_soul * souls * _soul_scale * power), 1)


func harvest_heal() -> int:
	return roundi(heal_per_soul * souls * _soul_scale)


func _activate(_toward: Vector3) -> bool:
	if souls <= 0:
		return false
	var hero := get_parent() as Node3D
	var hit := harvest_damage()
	last_damage = 0
	for target in Targeting.living_within(hero, radius, target_mask):
		last_damage += target.apply_damage(hit, hero.global_position)
	last_healed = health.heal(harvest_heal()) if health else 0
	souls = 0
	if hero.get_parent():
		Vfx.ring(hero.get_parent(), hero.global_position, radius, COLOR, 0.5)
		Vfx.burst(hero.get_parent(), hero.global_position + Vector3.UP, COLOR, 30, 4.0, 0.6, 0.12)
		Vfx.smoke(hero.get_parent(), hero.global_position + Vector3.UP * 0.5, COLOR.darkened(0.5), 6, 1.8, 1.0)
	return true
