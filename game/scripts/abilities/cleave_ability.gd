class_name CleaveAbility
extends Ability
## Cleave: a heavy, wide melee strike. The strike itself is a MeleeAttack
## with its own AttackData (damage, reach, arc, windup and recovery).

@export var attack: MeleeAttack


func is_busy() -> bool:
	return attack.is_busy()


func movement_multiplier() -> float:
	return attack.movement_multiplier()


func facing() -> Vector3:
	return attack.direction if attack.is_busy() else Vector3.ZERO


## Skill: Heavy Swings (CLEAVE_DAMAGE_PCT) on top of the general damage.
func apply_stats(stats: CharacterStats, damage_scale: float) -> void:
	attack.damage_scale = damage_scale * (1.0 + stats.value(SkillStats.CLEAVE_DAMAGE_PCT) / 100.0)


func cancel() -> void:
	attack.cancel()


func _activate(toward: Vector3) -> bool:
	return attack.try_start(toward)
