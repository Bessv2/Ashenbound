class_name Slowed
extends Node
## A slow on an enemy (the Hexbinder's Grasp of the Grave): its
## EnemyController moves at `factor` of its speed for `seconds`. Slowing a
## slowed enemy restarts the time and keeps the stronger slow; slows never
## stack. When it ends, or the body goes, the speed is restored exactly.

var factor: float = 1.0
var seconds_left: float = 0.0

var _enemy: EnemyController
var _applied: float = 1.0


## Slows `enemy`, or refreshes the slow on it. Returns the slow, or null when
## the body cannot be slowed (not an EnemyController).
static func apply(body: Node, speed_factor: float, seconds: float) -> Slowed:
	if not body is EnemyController:
		return null
	var slow: Slowed = null
	for child in body.get_children():
		if child is Slowed and not child.is_queued_for_deletion():
			slow = child
	if slow == null:
		slow = Slowed.new()
		slow.name = "Slowed"
		slow._enemy = body
		body.add_child(slow)
	slow.seconds_left = maxf(seconds, slow.seconds_left)
	slow._set_factor(minf(speed_factor, slow._applied))
	return slow


static func of(body: Node) -> Slowed:
	for child in body.get_children():
		if child is Slowed and not child.is_queued_for_deletion():
			return child
	return null


func _physics_process(delta: float) -> void:
	seconds_left -= delta
	if seconds_left <= 0.0 or _enemy.health.is_dead():
		_set_factor(1.0)
		queue_free()


func _exit_tree() -> void:
	_set_factor(1.0)


func _set_factor(value: float) -> void:
	if _enemy == null:
		return
	# Undo the factor applied before, then apply the new one, so other speed
	# changes (the Ashen Lord's last phase) are kept.
	_enemy.speed_multiplier /= _applied
	factor = clampf(value, 0.05, 1.0)
	_applied = factor
	_enemy.speed_multiplier *= _applied
