class_name PlayerController
extends CharacterBody3D
## Moves a character across the ground from MovementInput, relative to a camera,
## starts its attack while the attack action is held, and dodges when the dodge
## action is pressed. When its Health runs out it topples over and stops taking
## input.
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
## When false, input is ignored and the character decelerates to a stop.
@export var input_enabled: bool = true

## Time left in which a dodge press waits for the dodge to become ready.
var _dodge_buffer_left: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	if stats == null:
		stats = MovementStats.new()
	if health:
		health.died.connect(_on_died)


func is_alive() -> bool:
	return health == null or not health.is_dead()


func _physics_process(delta: float) -> void:
	var intent := MovementInput.get_vector() if input_enabled else Vector2.ZERO
	var view_basis := camera.global_basis if camera else Basis.IDENTITY
	var direction := MovementInput.to_world_direction(intent, view_basis)
	_update_dodge_request(direction, delta)
	var dash := dodge.step(delta) if dodge else Vector3.ZERO
	var dodging := dodge != null and (dodge.is_active() or not dash.is_zero_approx())
	if attack and input_enabled and not dodging and Input.is_action_pressed(GameplayActions.ATTACK):
		attack.try_start(_facing())

	var horizontal := dash
	if not dodging:
		var speed := stats.move_speed * (attack.movement_multiplier() if attack else 1.0)
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
	if dodging:
		visual.rotation.y = MovementStats.yaw_of(dodge.direction)
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
	else:
		_dodge_buffer_left -= delta


func _on_died() -> void:
	input_enabled = false
	_dodge_buffer_left = 0.0
	if dodge:
		dodge.cancel()
	if visual:
		# The visual's origin is at the feet, so this topples it forward.
		var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(visual, "rotation:x", -PI * 0.5, 0.4) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Flat world direction the character currently faces.
func _facing() -> Vector3:
	var frame := visual.global_basis if visual else global_basis
	return Vector3(-frame.z.x, 0.0, -frame.z.z).normalized()

