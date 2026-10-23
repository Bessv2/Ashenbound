class_name CharacterStats
extends Node
## The hero's final numbers: base values plus everything equipped and the
## learned skills, pushed into the combat nodes that use them. Combat code
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
## The hero's class tree; its learned ranks (from Profile) add to the gear.
@export var skill_tree: SkillTree
## Extra points added on top of the gear (set from the skill tree). Stat key →
## value, in the same units as item and skill stats.
var bonus: Dictionary[String, int] = {}

## Final stats after the last recalculation: stat key → value.
var final: Dictionary[String, int] = {}

var _equipment: Equipment
var _profile: Node
var _base_max_health: int = 0


func _ready() -> void:
	_base_max_health = player.health.max_health
	_profile = get_node_or_null(^"/root/Profile")
	if _profile and skill_tree:
		_profile.changed.connect(_take_skills)
		_take_skills()
	track(_default_equipment())


## Takes the learned ranks of `skill_tree` from Profile as the bonus.
func _take_skills() -> void:
	var learned: Dictionary[String, int] = skill_tree.bonus(_profile.ranks(skill_tree.class_id))
	if learned == bonus:
		return
	bonus = learned
	recalculate()


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
	var gear: Dictionary[String, int] = {}
	if _equipment:
		gear = _equipment.totals()
	final = combine(gear, bonus)
	_apply()
	recalculated.emit()


## The final stats from the gear's `totals` and the skills' `skill_bonus`:
## summed, the bases added, the caps applied.
static func combine(totals: Dictionary[String, int], skill_bonus: Dictionary[String, int]) -> Dictionary[String, int]:
	var total: Dictionary[String, int] = totals.duplicate()
	for stat in skill_bonus:
		total[stat] = total.get(stat, 0) + skill_bonus[stat]
	total[ItemStats.CRIT_CHANCE] = total.get(ItemStats.CRIT_CHANCE, 0) + BASE_CRIT_CHANCE
	total[ItemStats.CRIT_DAMAGE] = total.get(ItemStats.CRIT_DAMAGE, 0) + BASE_CRIT_DAMAGE
	total[ItemStats.MOVE_SPEED_PCT] = mini(total.get(ItemStats.MOVE_SPEED_PCT, 0), MOVE_SPEED_CAP)
	total[ItemStats.COOLDOWN_REDUCTION] = mini(total.get(ItemStats.COOLDOWN_REDUCTION, 0), COOLDOWN_REDUCTION_CAP)
	return total


## How much the basic attack's damage is multiplied by, from `stats`.
static func damage_scale_of(stats: Dictionary[String, int]) -> float:
	var weapon: int = stats.get(ItemStats.WEAPON_DAMAGE, 0)
	var weapon_scale := float(weapon) / UNARMED_WEAPON_DAMAGE if weapon > 0 else 1.0
	return weapon_scale * (1.0 + stats.get(ItemStats.DAMAGE_PCT, 0) / 100.0)


## The character sheet (the concept sheet's Character panel): one row per
## number a player reads, {"key", "label", "value", "icon"}. `stats` are final
## stats; `base_health` and `base_attack` are the class's own, before gear.
static func sheet(stats: Dictionary[String, int], base_health: int, base_attack: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var add := func(key: String, label: String, value: String, icon: String) -> void:
		rows.append({"key": key, "label": label, "value": value, "icon": icon})
	add.call("health", "Health", str(base_health + stats.get(ItemStats.MAX_HEALTH, 0)), "stat_health")
	add.call("attack", "Attack", str(roundi(base_attack * damage_scale_of(stats))), "stat_damage")
	add.call("armor", "Armour", str(stats.get(ItemStats.ARMOR, 0)), "stat_armor")
	add.call("crit_chance", "Crit chance", "%d%%" % stats.get(ItemStats.CRIT_CHANCE, 0), "stat_crit")
	add.call("crit_damage", "Crit damage", "%d%%" % (100 + stats.get(ItemStats.CRIT_DAMAGE, 0)), "stat_crit")
	add.call("attack_speed", "Attack speed", "+%d%%" % stats.get(ItemStats.ATTACK_SPEED_PCT, 0), "stat_speed")
	add.call("move_speed", "Move speed", "+%d%%" % stats.get(ItemStats.MOVE_SPEED_PCT, 0), "stat_speed")
	add.call("cooldown", "Cooldown reduction", "%d%%" % stats.get(ItemStats.COOLDOWN_REDUCTION, 0), "time")
	add.call("on_kill", "Health on kill", str(stats.get(ItemStats.HEALTH_ON_KILL, 0)), "stat_health")
	return rows


## This hero's sheet now.
func rows() -> Array[Dictionary]:
	return sheet(final, _base_max_health, player.attack.data.damage if player.attack and player.attack.data else 0)


## The sheet of class `class_id` wearing `profile`'s gear with its learned
## skills, without a hero in the world (the title screen). `scene_path` is
## the class's hero scene.
static func preview(scene_path: String, class_id: String, profile: Node) -> Array[Dictionary]:
	var hero := (load(scene_path) as PackedScene).instantiate() as PlayerController
	var stats := hero.get_node_or_null(^"Stats") as CharacterStats
	var skill_bonus: Dictionary[String, int] = {}
	if stats and stats.skill_tree:
		skill_bonus = stats.skill_tree.bonus(profile.ranks(class_id))
	var final_stats := combine(profile.equipment.totals(), skill_bonus)
	var base_attack: int = hero.attack.data.damage if hero.attack and hero.attack.data else 0
	var result := sheet(final_stats, hero.health.max_health, base_attack)
	hero.free()
	return result


func _apply() -> void:
	var damage_scale := damage_scale_of(final)
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
	_apply_skills(damage_scale)
	player.health.armor = value(ItemStats.ARMOR)
	# Keep the same missing health when the maximum changes, never dying of it.
	var health := player.health
	var missing := health.max_health - health.current
	health.max_health = _base_max_health + value(ItemStats.MAX_HEALTH)
	if not health.is_dead():
		health.current = clampi(health.max_health - missing, 1, health.max_health)


## Skill-only stats: each ability applies the ones that change it.
func _apply_skills(damage_scale: float) -> void:
	for ability in player.abilities:
		ability.apply_stats(self, damage_scale)


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
