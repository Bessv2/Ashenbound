class_name MartyrZeal
extends Node
## The Reliquary's Martyrdom passive (Blood Oath, Stigmata): below half
## health, the hero deals `martyr_damage_pct` more damage, with its basic
## attack and its abilities. A child of the hero named "Zeal"; it reads the
## stat from the hero's CharacterStats.

@export var stats: CharacterStats
@export var health: Health
## The basic attack it strengthens (through MeleeAttack.bonus_scale).
@export var attack: MeleeAttack


## The hero's damage factor right now: 1, or more below half health.
func factor() -> float:
	if stats == null or health == null or health.current * 2 >= health.max_health:
		return 1.0
	return 1.0 + stats.value("martyr_damage_pct") / 100.0


## The Zeal of `hero`, or null.
static func of(hero: Node) -> MartyrZeal:
	return hero.get_node_or_null(^"Zeal") as MartyrZeal if hero else null


func _physics_process(_delta: float) -> void:
	if attack:
		attack.bonus_scale = factor()
