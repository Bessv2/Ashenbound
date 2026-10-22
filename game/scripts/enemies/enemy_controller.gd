class_name EnemyController
extends CharacterBody3D
## A melee enemy that approaches the player and attacks when in range.
##
## States, matching the charter's enemy states:
## - IDLE: waits until a living player comes within aggro range.
## - APPROACH: walks to the player along a navigation path; gives up beyond
##   the leash range. A ranged enemy (EnemyBehavior.retreat_distance) backs
##   away instead when the player is too close, and one that needs a line of
##   sight keeps walking until no wall is in the way.
## - TELEGRAPH: the attack's windup. The enemy stands still, facing the
##   target, while its AttackTelegraph shows where the hit will land.
## - ATTACK: the physics tick on which the hit resolves.
## - RECOVERY: the attack's recovery; the enemy stays put, then approaches
##   again or goes idle.
## - DEAD: cancels any pending hit, stops colliding, sinks into the floor and
##   frees itself.
## - RISING: only after rise(); climbing out of the ground. It does nothing and
##   cannot be damaged, then goes IDLE.
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

enum State { IDLE, APPROACH, TELEGRAPH, ATTACK, RECOVERY, DEAD, RISING }

## How far the player may move from the end of the current path before a new
## path is planned. Planning every physics frame would work too, but wastes
## queries on a target that has barely moved.
const REPATH_DISTANCE := 0.5

@export var movement: MovementStats
@export var behavior: EnemyBehavior
@export var attack: MeleeAttack
## Optional: used instead of `attack` for every EnemyBehavior.special_every-th
## attack (the Fallen Knight's shield bash).
@export var special_attack: MeleeAttack
@export var health: Health
## Turned to face movement or the attack. Sinks when the enemy dies.
@export var visual: Node3D
## Plans the chase around obstacles. Without one the enemy steers straight at
## its target.
@export var navigation: NavigationAgent3D
## Hunts the player anywhere in the level and never gives up, instead of
## waiting for it within aggro range (encounter enemies).
@export var hunting: bool = false
## Ash the run earns when this enemy is killed.
@export_range(0, 1000, 1) var ash_value: int = 1
## XP the hero gains for the kill.
@export_range(0, 100000, 1) var xp_value: int = 10
## Gold the run earns for this kill (paid with the Ash at the run's end).
@export_range(0, 100000, 1) var gold_value: int = 3
## What it may drop when killed; none when null.
@export var drop_table: DropTable
## Whether an encounter may raise it as a Champion. Elites and bosses are
## special already.
@export var champion_eligible: bool = true

var state: State = State.IDLE
## Scales movement speed (a boss's last phase moves faster). The movement
## resource is shared, so it is never changed.
var speed_multiplier: float = 1.0
## The attack playing out, or the last one.
var current_attack: MeleeAttack
## Attacks started so far.
var attacks_started: int = 0

## Where the current path leads; INF when no path has been requested.
var _path_target: Vector3 = Vector3.INF
var _rise_left: float = 0.0

@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if movement == null:
		movement = MovementStats.new()
	if behavior == null:
		behavior = EnemyBehavior.new()
	health.died.connect(_on_died)
	current_attack = attack
	attack.struck.connect(_on_attack_struck.unbind(1))
	if special_attack:
		special_attack.struck.connect(_on_attack_struck.unbind(1))


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	var target := _living_target()
	_update_state(target, delta)

	var desired := Vector3.ZERO
	if state == State.APPROACH and target and _is_too_close(target):
		desired = -_direction_to(target) * movement.move_speed * speed_multiplier
		_path_target = Vector3.INF
	elif state == State.APPROACH and target:
		desired = _chase_direction(target) * movement.move_speed * speed_multiplier * current_attack.movement_multiplier()
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
			visual.rotation.y = MovementStats.yaw_of(current_attack.direction)
		else:
			movement.turn_toward(visual, desired, delta)


## Whether an attack is playing out: telegraph, hit or recovery.
func is_attacking() -> bool:
	return state == State.TELEGRAPH or state == State.ATTACK or state == State.RECOVERY


## Climbs out of the ground for `seconds`: no movement, no attacks and no
## damage taken, then IDLE.
func rise(seconds: float) -> void:
	if state == State.DEAD or seconds <= 0.0:
		return
	_rise_left = seconds
	health.invulnerable = true
	_set_state(State.RISING)


## Seconds of rising left, or 0.
func rise_time_left() -> float:
	return _rise_left if state == State.RISING else 0.0


func _update_state(target: Node3D, delta: float) -> void:
	match state:
		State.RISING:
			_rise_left -= delta
			if _rise_left <= 0.0:
				health.invulnerable = false
				_set_state(State.IDLE)
		State.IDLE:
			if target and (hunting or _distance_to(target) <= behavior.aggro_radius):
				_set_state(State.APPROACH)
		State.APPROACH:
			if target == null or (not hunting and _distance_to(target) > behavior.leash_radius):
				_set_state(State.IDLE)
			elif _is_too_close(target):
				pass  # Backing away; see _physics_process.
			elif _distance_to(target) <= behavior.attack_range and _has_line_to(target):
				# Chosen once: subclasses may remember their choice.
				var next := _next_attack()
				if next.try_start(_direction_to(target)):
					current_attack = next
					attacks_started += 1
					_set_state(State.TELEGRAPH)
		State.ATTACK:
			# The hit resolved on the previous tick.
			_set_state(State.RECOVERY if current_attack.is_busy() else _after_attack(target))
		State.RECOVERY:
			if not current_attack.is_busy():
				_set_state(_after_attack(target))


## The attack to use next: the special one every `special_every`-th time.
## Called once per attack that is about to start.
func _next_attack() -> MeleeAttack:
	var every := behavior.special_every
	if special_attack and every > 0 and (attacks_started + 1) % every == 0:
		return special_attack
	return attack


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


## Whether a ranged enemy should back away from `target` rather than attack.
## Not when it is already against a wall: cornered, it fights.
func _is_too_close(target: Node3D) -> bool:
	return behavior.retreat_distance > 0.0 and _distance_to(target) < behavior.retreat_distance \
			and not is_on_wall()


## Whether nothing on the world layer stands between this enemy and `target`,
## at chest height. Always true for enemies that do not need a line of sight.
func _has_line_to(target: Node3D) -> bool:
	if not behavior.needs_line_of_sight:
		return true
	var chest := Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(global_position + chest, target.global_position + chest, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


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
	if special_attack:
		special_attack.cancel()
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
