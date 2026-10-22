class_name PlayerController
extends CharacterBody3D
## Moves a character across the ground from MovementInput, relative to a camera,
## starts its attack while the attack action is held, starts its abilities on
## their actions, and dodges when the dodge action is pressed. When its Health
## runs out it stops taking input (its CharacterAnimator plays the death clip).
##
## Priority: a dodge cancels any ability or attack in progress; an ability
## cancels the basic attack; nothing else starts while an ability plays out.
##
## Runs in _physics_process with delta-based integration, so speed does not
## depend on frame rate. Collision with the world is handled by move_and_slide.

## Enemies find the player through this group.
const GROUP := &"player"

@export var stats: MovementStats
## Movement is relative to this camera's horizontal orientation.
@export var camera: Camera3D
## Turned to face the movement direction. The collision shape never rotates.
@export var visual: Node3D
## Optional. Started while the attack action is held; slows movement and
## takes over facing while it runs.
@export var attack: MeleeAttack
## Optional. Without it the character cannot die.
@export var health: Health
## Optional. Dashes toward the movement input (or the facing without input)
## when the dodge action is pressed, canceling the attack in progress.
@export var dodge: Dodge
## Started on their own InputMap actions.
@export var abilities: Array[Ability] = []
## When false, input is ignored and the character decelerates to a stop.
@export var input_enabled: bool = true

## Time left in which a dodge press waits for the dodge to become ready.
var _dodge_buffer_left: float = 0.0
## A shove in progress (see push()): its velocity and the time it has left.
var _push_velocity: Vector3 = Vector3.ZERO
var _push_left: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	if stats == null:
		stats = MovementStats.new()
	if health:
		health.died.connect(_on_died)


func is_alive() -> bool:
	return health == null or not health.is_dead()


## Shoves the character by `offset` (flat) over `seconds`, overriding its own
## movement but not a dodge. Walls stop it as usual. A new push replaces one
## in progress.
func push(offset: Vector3, seconds: float = 0.2) -> void:
	seconds = maxf(seconds, 0.01)
	_push_velocity = Vector3(offset.x, 0.0, offset.z) / seconds
	_push_left = seconds


func is_being_pushed() -> bool:
	return _push_left > 0.0


func _physics_process(delta: float) -> void:
	var intent := MovementInput.get_vector() if input_enabled else Vector2.ZERO
	var view_basis := camera.global_basis if camera else Basis.IDENTITY
	var direction := MovementInput.to_world_direction(intent, view_basis)
	_update_dodge_request(direction, delta)
	var dash := dodge.step(delta) if dodge else Vector3.ZERO
	var dodging := dodge != null and (dodge.is_active() or not dash.is_zero_approx())
	if input_enabled and not dodging:
		_start_abilities()
	var busy_ability := _busy_ability()
	if attack and input_enabled and not dodging and busy_ability == null \
			and Input.is_action_pressed(GameplayActions.ATTACK):
		attack.try_start(_facing())

	var horizontal := dash
	if _push_left > 0.0 and not dodging:
		# The last tick covers only what is left, so the distance is exact.
		horizontal = _push_velocity * minf(delta, _push_left) / delta
		_push_left -= delta
	elif not dodging:
		var speed := stats.move_speed * (attack.movement_multiplier() if attack else 1.0)
		if busy_ability:
			speed = stats.move_speed * busy_ability.movement_multiplier()
		# Leaving a dash at dash speed would slide far past its end.
		var current := Vector3(velocity.x, 0.0, velocity.z).limit_length(stats.move_speed)
		horizontal = stats.step_velocity(current, direction * speed, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()
	if visual == null:
		return
	var ability_facing := busy_ability.facing() if busy_ability else Vector3.ZERO
	if dodging:
		visual.rotation.y = MovementStats.yaw_of(dodge.direction)
	elif not ability_facing.is_zero_approx():
		visual.rotation.y = MovementStats.yaw_of(ability_facing)
	elif busy_ability:
		pass  # Holds its facing, like a raised guard.
	elif attack and attack.is_busy():
		visual.rotation.y = MovementStats.yaw_of(attack.direction)
	else:
		stats.turn_toward(visual, direction, delta)


func _update_dodge_request(direction: Vector3, delta: float) -> void:
	if dodge == null or not input_enabled:
		_dodge_buffer_left = 0.0
		return
	if Input.is_action_just_pressed(GameplayActions.DODGE):
		_dodge_buffer_left = dodge.data.input_buffer + delta
	if _dodge_buffer_left <= 0.0:
		return
	if dodge.try_start(direction if not direction.is_zero_approx() else _facing()):
		_dodge_buffer_left = 0.0
		if attack:
			attack.cancel()
		for ability in abilities:
			ability.cancel()
	else:
		_dodge_buffer_left -= delta


func _on_died() -> void:
	input_enabled = false
	_dodge_buffer_left = 0.0
	if dodge:
		dodge.cancel()
	for ability in abilities:
		ability.cancel()


func _start_abilities() -> void:
	for ability in abilities:
		if not Input.is_action_just_pressed(ability.action) or _busy_ability():
			continue
		if ability.try_activate(_facing()) and attack:
			attack.cancel()


## The ability still playing out, or null.
func _busy_ability() -> Ability:
	for ability in abilities:
		if ability.is_busy():
			return ability
	return null


## Flat world direction the character currently faces.
func _facing() -> Vector3:
	var frame := visual.global_basis if visual else global_basis
	return Vector3(-frame.z.x, 0.0, -frame.z.z).normalized()

