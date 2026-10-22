class_name BleedAbility
extends BrandAbility
## Hemorrhage (the Reaver): opens a bleed on the nearest enemy within a short
## reach. The same damage-over-time as Ember Brand, as a separate effect
## ("Bleeding", crimson), so a target can burn and bleed at once.

var _bleed_base: int = 0


func _ready() -> void:
	super()
	_bleed_base = damage_per_tick


## Skills: Hemorrhage and Deep Cuts (BLEED_DAMAGE_PCT).
func apply_stats(stats: CharacterStats, _damage_scale: float) -> void:
	damage_per_tick = maxi(roundi(_bleed_base * (1.0 + stats.value("bleed_damage_pct") / 100.0)), 1)
