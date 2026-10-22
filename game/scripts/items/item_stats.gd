class_name ItemStats
extends RefCounted
## The stats items can carry, by key (the keys are what save files store),
## with how each is shown. Every stat here changes combat (docs/LOOT.md).

const WEAPON_DAMAGE := "weapon_damage"
const DAMAGE_PCT := "damage_pct"
const ATTACK_SPEED_PCT := "attack_speed_pct"
const CRIT_CHANCE := "crit_chance"
const CRIT_DAMAGE := "crit_damage"
const MAX_HEALTH := "max_health"
const ARMOR := "armor"
const MOVE_SPEED_PCT := "move_speed_pct"
const COOLDOWN_REDUCTION := "cooldown_reduction"
const HEALTH_ON_KILL := "health_on_kill"

## Key → [label, is a percentage].
const INFO := {
	WEAPON_DAMAGE: ["Weapon damage", false],
	DAMAGE_PCT: ["Damage", true],
	ATTACK_SPEED_PCT: ["Attack speed", true],
	CRIT_CHANCE: ["Critical chance", true],
	CRIT_DAMAGE: ["Critical damage", true],
	MAX_HEALTH: ["Max health", false],
	ARMOR: ["Armour", false],
	MOVE_SPEED_PCT: ["Move speed", true],
	COOLDOWN_REDUCTION: ["Cooldown reduction", true],
	HEALTH_ON_KILL: ["Health on kill", false],
}


static func is_known(stat: String) -> bool:
	return INFO.has(stat)


## "+12% Damage", "+30 Max health".
static func describe(stat: String, value: int) -> String:
	if not INFO.has(stat):
		return "%+d %s" % [value, stat]
	var info: Array = INFO[stat]
	return ("%+d%% %s" if info[1] else "%+d %s") % [value, info[0]]
