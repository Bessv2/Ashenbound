class_name MovementInput
extends RefCounted
## Single source of movement intent for gameplay code.
##
## Keyboard keys and the on-screen joystick drive the same InputMap actions,
## so gameplay reads one vector without knowing which device produced it.

const LEFT := &"move_left"
const RIGHT := &"move_right"
const FORWARD := &"move_forward"
const BACK := &"move_back"
const ACTIONS: Array[StringName] = [LEFT, RIGHT, FORWARD, BACK]


## Movement intent in screen space: +x is right, +y is toward the bottom of
## the screen. Length is in [0, 1], so diagonal key presses are normalized.
static func get_vector() -> Vector2:
	# No extra dead zone: keys are digital and the joystick applies its own.
	return Input.get_vector(LEFT, RIGHT, FORWARD, BACK, 0.0)


## Converts screen-space intent into a direction on the ground (XZ) plane,
## relative to the camera's horizontal orientation. Camera pitch is ignored,
## so "up" always means "away from the camera" regardless of tilt.
static func to_world_direction(intent: Vector2, camera_basis: Basis) -> Vector3:
	var right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z).normalized()
	var forward := Vector3(-camera_basis.z.x, 0.0, -camera_basis.z.z).normalized()
	return (right * intent.x - forward * intent.y).limit_length(1.0)


## Releases every movement action, whichever device pressed it.
static func release_all() -> void:
	for action in ACTIONS:
		Input.action_release(action)
