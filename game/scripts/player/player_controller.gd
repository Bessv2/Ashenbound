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
	var horizontal := stats.step_velocity(Vector3(velocity.x, 0.0, velocity.z), direction * speed, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()
	if visual == null:
		return
	if attack and attack.is_busy():
		visual.rotation.y = MovementStats.yaw_of(attack.direction)
	else:
		stats.turn_toward(visual, direction, delta)


## Flat world direction the character currently faces.
func _facing() -> Vector3:
	var frame := visual.global_basis if visual else global_basis
	return Vector3(-frame.z.x, 0.0, -frame.z.z).normalized()

