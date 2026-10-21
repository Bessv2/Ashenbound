class_name EnemyController
extends CharacterBody3D
## A melee enemy that approaches the player and attacks when in range.
##
## States, matching the charter's enemy states:
## - IDLE: waits until a living player comes within aggro range.
## - APPROACH: walks to the player along a navigation path; gives up beyond
##   the leash range.
## - TELEGRAPH: the attack's windup. The enemy stands still, facing the
##   target, while its AttackTelegraph shows where the hit will land.
## - ATTACK: the physics tick on which the hit resolves.
## - RECOVERY: the attack's recovery; the enemy stays put, then approaches
##   again or goes idle.
## - DEAD: cancels any pending hit, stops colliding, sinks into the floor and
##   frees itself.
##
## Every change emits `state_changed`, for tests now and animation later.
##
## The chase follows the `navigation` agent's path around walls and pillars.
## Where there is no path to follow (no navigation mesh in the level, the
## navigation map not synchronized yet, or the path already walked) the enemy
## steers straight at the player instead, which is also the last stretch of
## every chase. The player is found through the PlayerController.GROUP group,
## so enemies never hold a reference that a scene reload could leave dangling.

## Emitted just before the body is removed, after the death animation.
signal despawned
signal state_changed(previous: State, current: State)

enum State { IDLE, APPROACH, TELEGRAPH, ATTACK, RECOVERY, DEAD }

## How far the player may move from the end of the current path before a new
## path is planned. Planning every physics frame would work too, but wastes
## queries on a target that has barely moved.
const REPATH_DISTANCE := 0.5

@export var movement: MovementStats
@export var behavior: EnemyBehavior
@export var attack: MeleeAttack
@export var health: Health
## Turned to face movement or the attack. Sinks when the enemy dies.
@export var visual: Node3D
## Plans the chase around obstacles. Without one the enemy steers straight at
## its target.
@export var navigation: NavigationAgent3D

var state: State = State.IDLE

## Where the current path leads; INF when no path has been requested.
var _path_target: Vector3 = Vector3.INF

@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if movement == null:
		movement = MovementStats.new()
	if behavior == null:
		behavior = EnemyBehavior.new()
	health.died.connect(_on_died)
	attack.struck.connect(_on_attack_struck.unbind(1))


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	var target := _living_target()
	_update_state(target)

	var desired := Vector3.ZERO
	if state == State.APPROACH and target:
		desired = _chase_direction(target) * movement.move_speed * attack.movement_multiplier()
	else:
		# The next chase plans a fresh path.
		_path_target = Vector3.INF
	var horizontal := movement.step_velocity(Vector3(velocity.x, 0.0, velocity.z), desired, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	if visual:
		if is_attacking():
			visual.rotation.y = MovementStats.yaw_of(attack.direction)
		else:
			movement.turn_toward(visual, desired, delta)


## Whether an attack is playing out: telegraph, hit or recovery.
func is_attacking() -> bool:
	return state == State.TELEGRAPH or state == State.ATTACK or state == State.RECOVERY


func _update_state(target: Node3D) -> void:
	match state:
		State.IDLE:
			if target and _distance_to(target) <= behavior.aggro_radius:
				_set_state(State.APPROACH)
		State.APPROACH:
			if target == null or _distance_to(target) > behavior.leash_radius:
				_set_state(State.IDLE)
			elif _distance_to(target) <= behavior.attack_range and attack.try_start(_direction_to(target)):
				_set_state(State.TELEGRAPH)
		State.ATTACK:
			# The hit resolved on the previous tick.
			_set_state(State.RECOVERY if attack.is_busy() else _after_attack(target))
		State.RECOVERY:
			if not attack.is_busy():
				_set_state(_after_attack(target))


func _after_attack(target: Node3D) -> State:
	return State.APPROACH if target else State.IDLE


func _set_state(next: State) -> void:
	if next == state:
		return
	var previous := state
	state = next
	state_changed.emit(previous, next)


func _on_attack_struck() -> void:
	if state == State.TELEGRAPH:
		_set_state(State.ATTACK)


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


## The horizontal direction to walk in to reach `target`: toward the next point
## of the navigation path, or straight at the target when there is no path.
func _chase_direction(target: Node3D) -> Vector3:
	if navigation == null:
		return _direction_to(target)
	if _path_target.distance_to(target.global_position) > REPATH_DISTANCE:
		_path_target = target.global_position
		navigation.target_position = _path_target
	# The path ends near the player, or as near as the mesh reaches. Cover the
	# rest, including any move shorter than REPATH_DISTANCE, directly.
	if navigation.is_navigation_finished():
		return _direction_to(target)
	var offset := navigation.get_next_path_position() - global_position
	offset.y = 0.0
	# Without a path the agent returns this body's own position.
	if offset.length_squared() < 0.0001:
		return _direction_to(target)
	return offset.normalized()


func _on_died() -> void:
	_set_state(State.DEAD)
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
