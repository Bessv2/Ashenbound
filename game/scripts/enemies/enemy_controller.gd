class_name EnemyController
extends CharacterBody3D
## A melee enemy that chases the player and attacks when in range.
##
## States:
## - IDLE: waits until a living player comes within aggro range.
## - CHASE: walks straight at the player; gives up beyond the leash range.
## - ATTACK: stands still while its MeleeAttack plays out, facing the target.
## - DEAD: cancels any pending hit, stops colliding, sinks into the floor and
##   frees itself.
##
## Movement is direct steering with move_and_slide, which suits the open test
## arena: obstacles are slid around, not planned around. The player is found
## through the PlayerController.GROUP group, so enemies never hold a reference
## that a scene reload could leave dangling.

## Emitted just before the body is removed, after the death animation.
signal despawned

enum State { IDLE, CHASE, ATTACK, DEAD }

@export var movement: MovementStats
@export var behavior: EnemyBehavior
@export var attack: MeleeAttack
@export var health: Health
## Turned to face movement or the attack. Sinks when the enemy dies.
@export var visual: Node3D

var state: State = State.IDLE

@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if movement == null:
		movement = MovementStats.new()
	if behavior == null:
		behavior = EnemyBehavior.new()
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	var target := _living_target()
	_update_state(target)

	var desired := Vector3.ZERO
	if state == State.CHASE and target:
		desired = _direction_to(target) * movement.move_speed * attack.movement_multiplier()
	var horizontal := movement.step_velocity(Vector3(velocity.x, 0.0, velocity.z), desired, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	if visual:
		if state == State.ATTACK:
			visual.rotation.y = MovementStats.yaw_of(attack.direction)
		else:
			movement.turn_toward(visual, desired, delta)


func _update_state(target: Node3D) -> void:
	match state:
		State.IDLE:
			if target and _distance_to(target) <= behavior.aggro_radius:
				state = State.CHASE
		State.CHASE:
			if target == null or _distance_to(target) > behavior.leash_radius:
				state = State.IDLE
			elif _distance_to(target) <= behavior.attack_range and attack.try_start(_direction_to(target)):
				state = State.ATTACK
		State.ATTACK:
			if not attack.is_busy():
				state = State.CHASE if target else State.IDLE


## The player, or null when there is none or it is dead.
func _living_target() -> Node3D:
	var player := get_tree().get_first_node_in_group(PlayerController.GROUP) as Node3D
	if player == null:
		return null
	var target_health := Health.of(player)
	if target_health and target_health.is_dead():
		return null
	return player


func _distance_to(target: Node3D) -> float:
	var offset := target.global_position - global_position
	return Vector2(offset.x, offset.z).length()


func _direction_to(target: Node3D) -> Vector3:
	var offset := target.global_position - global_position
	return Vector3(offset.x, 0.0, offset.z).normalized()


func _on_died() -> void:
	state = State.DEAD
	attack.cancel()
	velocity = Vector3.ZERO
	# Collision changes are not allowed while physics queries run.
	_collision.set_deferred("disabled", true)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(behavior.corpse_time * 0.4)
	if visual:
		tween.tween_property(visual, "position:y", -2.0, behavior.corpse_time * 0.6) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tween.tween_interval(behavior.corpse_time * 0.6)
	tween.tween_callback(_despawn)


func _despawn() -> void:
	despawned.emit()
	queue_free()
