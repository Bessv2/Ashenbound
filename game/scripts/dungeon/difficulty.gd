class_name Difficulty
extends RefCounted
## A crypt tier (docs/dungeons/tiers.md): how much tougher the enemies are and
## how much better the rewards. Tier 1 is the crypt as built. Each tier above
## it scales enemy health, enemy damage, Ash and XP, the item level of drops,
## and the drop chance and rarity. One place for the numbers, so the
## encounter, the loot and the summary agree.

const MAX_TIER := 10

const HEALTH_PER_TIER := 0.4
const DAMAGE_PER_TIER := 0.15
const REWARD_PER_TIER := 0.5
const ITEM_LEVELS_PER_TIER := 4
const DROP_CHANCE_PER_TIER := 0.1
const RARITY_PER_TIER := 0.25

var tier: int = 1


func _init(chosen: int = 1) -> void:
	tier = clampi(chosen, 1, MAX_TIER)


func health_scale() -> float:
	return 1.0 + HEALTH_PER_TIER * (tier - 1)


func damage_scale() -> float:
	return 1.0 + DAMAGE_PER_TIER * (tier - 1)


## Applies to Ash, XP and gold from kills.
func reward_scale() -> float:
	return 1.0 + REWARD_PER_TIER * (tier - 1)


func item_level(base_level: int) -> int:
	return base_level + ITEM_LEVELS_PER_TIER * (tier - 1)


func drop_chance_scale() -> float:
	return 1.0 + DROP_CHANCE_PER_TIER * (tier - 1)


func rarity_scale() -> float:
	return 1.0 + RARITY_PER_TIER * (tier - 1)


## Makes `enemy` match this tier: more health (at full), harder hits, more Ash,
## XP and gold. Call once per enemy, before it enters the tree or right after.
func apply(enemy: Node3D) -> void:
	if tier == 1:
		return
	var health := Health.of(enemy)
	if health:
		health.max_health = roundi(health.max_health * health_scale())
		health.current = health.max_health
	for node in enemy.find_children("*", "", true, false):
		if node is MeleeAttack:
			(node as MeleeAttack).damage_scale *= damage_scale()
	if enemy is EnemyController:
		var controller := enemy as EnemyController
		controller.ash_value = roundi(controller.ash_value * reward_scale())
		controller.xp_value = roundi(controller.xp_value * reward_scale())
		controller.gold_value = roundi(controller.gold_value * reward_scale())
