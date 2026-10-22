class_name SkillStats
extends RefCounted
## Stats only skill trees grant: each changes one ability. Item stats
## (ItemStats) are granted by trees too. Abilities of classes that are not
## playable yet use the keys under "Future classes"; they change nothing
## until those abilities exist.

const CLEAVE_DAMAGE_PCT := "cleave_damage_pct"
const GUARD_DURATION_MS := "guard_duration_ms"
const COUNTER_DAMAGE_PCT := "counter_damage_pct"
const BRAND_TICK_DAMAGE := "brand_tick_damage"
const BRAND_TICKS := "brand_ticks"

const KNOWN := [
	CLEAVE_DAMAGE_PCT, GUARD_DURATION_MS, COUNTER_DAMAGE_PCT, BRAND_TICK_DAMAGE, BRAND_TICKS,
	# Future classes.
	"bleed_damage_pct", "veil_rend_damage_pct", "dash_cooldown_pct", "mark_damage_pct",
	"curse_duration_pct", "curse_damage_pct", "soul_siphon_pct", "detonation_damage_pct", "black_testament_pct",
	"charged_shot_damage_pct", "trap_duration_pct", "trap_damage_pct", "deadfall_bolts", "companion_damage_pct",
	"healing_pct", "radiance_damage_pct", "martyr_damage_pct", "benediction_heal_pct",
	"summon_count", "summon_health_pct", "summon_damage_pct", "summon_duration_pct", "soul_harvest_pct",
]


static func is_known(stat: String) -> bool:
	return KNOWN.has(stat)
