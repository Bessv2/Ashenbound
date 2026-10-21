class_name PlayerController
extends CharacterBody3D
## Moves a character across the ground from MovementInput, relative to a camera,
## and starts its attack while the attack action is held.
##
## Runs in _physics_process with delta-based integration, so speed does not
## depend on frame rate. Collision with the world is handled by move_and_slide.

@export var stats: MovementStats
## Movement is relative to this camera's horizontal orientation.
@export var camera: Camera3D
## Turned to face the movement direction. The collision shape never rotates.
@export var visual: Node3D
## Optional. Started while the attack action is held; slows movement and
## takes over facing while it runs.
@export var attack: MeleeAttack
## When false, input is ignored and the character decelerates to a stop.
@export var input_enabled: bool = true


func _ready() -> void:
	if stats == null:
		stats = MovementStats.new()


func _physics_process(delta: float) -> void:
	var intent := MovementInput.get_vector() if input_enabled else Vector2.ZERO
	var view_basis := camera.global_basis if camera else Basis.IDENTITY
	var direction := MovementInput.to_world_direction(intent, view_basis)
	if attack and input_enabled and Input.is_action_pressed(GameplayActions.ATTACK):
		attack.try_start(_facing())

	var speed := stats.move_speed * (attack.movement_multiplier() if attack else 1.0)
	var horizontal := step_horizontal_velocity(
			Vector3(velocity.x, 0.0, velocity.z), direction * speed, stats, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()
	if attack and attack.is_busy():
		_face(attack.direction)
	else:
		_turn_toward(direction, delta)


## Moves current velocity toward target at a constant rate (acceleration while
## there is input, deceleration otherwise). The rate is linear in time, so the
## result does not depend on how a time span is split into frames, and releasing
## input always reaches exactly zero.
static func step_horizontal_velocity(
		current: Vector3, target: Vector3, movement: MovementStats, delta: float) -> Vector3:
	var rate := movement.acceleration if not target.is_zero_approx() else movement.deceleration
	return current.move_toward(target, rate * delta)


## Flat world direction the character currently faces.
func _facing() -> Vector3:
	var frame := visual.global_basis if visual else global_basis
	return Vector3(-frame.z.x, 0.0, -frame.z.z).normalized()


func _turn_toward(direction: Vector3, delta: float) -> void:
	if visual == null or direction.is_zero_approx():
		return
	var weight := 1.0 - exp(-stats.turn_sharpness * delta)
	visual.rotation.y = lerp_angle(visual.rotation.y, _yaw_of(direction), weight)


func _face(direction: Vector3) -> void:
	if visual and not direction.is_zero_approx():
		visual.rotation.y = _yaw_of(direction)


## Node3D faces -Z, so this yaw points -Z along `direction`.
static func _yaw_of(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)
