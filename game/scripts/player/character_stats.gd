class_name CharacterStats
extends Node
## The hero's final numbers: base values plus everything equipped (and, later,
## the skill tree), pushed into the combat nodes that use them. Combat code
## reads only those nodes; equipping never changes a shared resource.
##
## How each stat acts (docs/LOOT.md):
## - weapon damage: all attacks scale by weapon damage / UNARMED_WEAPON_DAMAGE;
## - damage %: all attacks and ability damage;
## - attack speed %: the basic attack's windup and recovery;
## - critical chance / damage: every attack's hits;
## - max health, armour: the Health;
## - move speed % (capped), cooldown reduction % (capped): movement, abilities;
## - health on kill: healed by Main when the run counts a kill.

signal recalculated

## The bare-handed weapon damage: a weapon with this much changes nothing.
const UNARMED_WEAPON_DAMAGE := 10
const BASE_CRIT_CHANCE := 0
const BASE_CRIT_DAMAGE := 50
const MOVE_SPEED_CAP := 30
const COOLDOWN_REDUCTION_CAP := 40

@export var player: PlayerController
## Extra points added on top of the gear (the skill tree, later). Stat key →
## value, in the same units as item stats.
var bonus: Dictionary[String, int] = {}

## Final stats after the last recalculation: stat key → value.
var final: Dictionary[String, int] = {}

var _equipment: Equipment
var _base_max_health: int = 0


func _ready() -> void:
	_base_max_health = player.health.max_health
	track(_default_equipment())


## Uses `equipment` (Profile's by default) and recalculates whenever it
## changes.
func track(equipment: Equipment) -> void:
	if _equipment and _equipment.changed.is_connected(recalculate):
		_equipment.changed.disconnect(recalculate)
	_equipment = equipment
	if _equipment:
		_equipment.changed.connect(recalculate)
	recalculate()


func value(stat: String) -> int:
	return final.get(stat, 0)


func recalculate() -> void:
	var total: Dictionary[String, int] = _equipment.totals() if _equipment else {}
	for stat in bonus:
		total[stat] = total.get(stat, 0) + bonus[stat]
	total[ItemStats.CRIT_CHANCE] = total.get(ItemStats.CRIT_CHANCE, 0) + BASE_CRIT_CHANCE
	total[ItemStats.CRIT_DAMAGE] = total.get(ItemStats.CRIT_DAMAGE, 0) + BASE_CRIT_DAMAGE
	total[ItemStats.MOVE_SPEED_PCT] = mini(total.get(ItemStats.MOVE_SPEED_PCT, 0), MOVE_SPEED_CAP)
	total[ItemStats.COOLDOWN_REDUCTION] = mini(total.get(ItemStats.COOLDOWN_REDUCTION, 0), COOLDOWN_REDUCTION_CAP)
	final = total
	_apply()
	recalculated.emit()


func _apply() -> void:
	var weapon := value(ItemStats.WEAPON_DAMAGE)
	var weapon_scale := float(weapon) / UNARMED_WEAPON_DAMAGE if weapon > 0 else 1.0
	var damage_scale := weapon_scale * (1.0 + value(ItemStats.DAMAGE_PCT) / 100.0)
	var crit_chance := clampf(value(ItemStats.CRIT_CHANCE) / 100.0, 0.0, 1.0)
	var crit_multiplier := 1.0 + value(ItemStats.CRIT_DAMAGE) / 100.0
	for attack in _attacks():
		attack.damage_scale = damage_scale
		attack.crit_chance = crit_chance
		attack.crit_multiplier = crit_multiplier
	if player.attack:
		var speed := 1.0 / (1.0 + value(ItemStats.ATTACK_SPEED_PCT) / 100.0)
		player.attack.windup_scale = speed
		player.attack.recovery_scale = speed
	for ability in player.abilities:
		ability.cooldown_scale = 1.0 - value(ItemStats.COOLDOWN_REDUCTION) / 100.0
		ability.power = 1.0 + value(ItemStats.DAMAGE_PCT) / 100.0
	player.speed_multiplier = 1.0 + value(ItemStats.MOVE_SPEED_PCT) / 100.0
	player.health.armor = value(ItemStats.ARMOR)
	# Keep the same missing health when the maximum changes, never dying of it.
	var health := player.health
	var missing := health.max_health - health.current
	health.max_health = _base_max_health + value(ItemStats.MAX_HEALTH)
	if not health.is_dead():
		health.current = clampi(health.max_health - missing, 1, health.max_health)


## Every MeleeAttack the hero owns (basic attack, Cleave, Guard's counter).
func _attacks() -> Array[MeleeAttack]:
	var found: Array[MeleeAttack] = []
	for child in player.get_children():
		if child is MeleeAttack:
			found.append(child)
	return found


func _default_equipment() -> Equipment:
	var profile := get_node_or_null(^"/root/Profile")
	return profile.equipment if profile else Equipment.new()
