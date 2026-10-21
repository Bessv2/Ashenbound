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


func cancel() -> void:
	attack.cancel()


func _activate(toward: Vector3) -> bool:
	return attack.try_start(toward)
