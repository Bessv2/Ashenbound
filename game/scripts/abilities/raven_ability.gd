class_name RavenAbility
extends Ability
## Carrion Raven (the Dreadhunter, Beastcraft): calls a raven that circles the
## hero for `lifetime` and, every `strike_interval`, dives at the nearest enemy
## within `reach` of the hero for `damage`. Casting again while it flies
## renews it rather than calling a second. Always activates.
##
## A small companion: one at a time, no navigation, no collision. It goes
## when its time is up, when the hero dies, or with the hero.

const COLOR := Color(1.0, 0.72, 0.3)

@export_range(0.5, 60.0, 0.5, "suffix:s") var lifetime: float = 8.0
@export_range(0.1, 5.0, 0.05, "suffix:s") var strike_interval: float = 0.8
@export_range(1.0, 30.0, 0.5, "suffix:m") var reach: float = 9.0
@export_range(0, 1000, 1) var damage: int = 6
@export_flags_3d_physics var target_mask: int = 4

var _companion_scale: float = 1.0


## Skills: Hunter's Bond and Savage Bite (companion_damage_pct).
func apply_stats(stats: CharacterStats, _damage_scale: float) -> void:
	_companion_scale = 1.0 + stats.value("companion_damage_pct") / 100.0


## Damage of each dive.
func strike_damage() -> int:
	return maxi(roundi(damage * power * _companion_scale), 1)


## The raven flying now, or null.
func raven() -> Raven:
	var hunter := get_parent()
	var bird := hunter.get_node_or_null(^"CarrionRaven") as Raven if hunter else null
	return bird if bird and not bird.is_queued_for_deletion() else null


func _activate(_toward: Vector3) -> bool:
	var hunter := get_parent() as Node3D
	var bird := raven()
	if bird == null:
		bird = Raven.new()
		bird.name = "CarrionRaven"
		bird.ability = self
		hunter.add_child(bird)
	bird.renew()
	return true
