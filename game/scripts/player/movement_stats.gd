class_name MovementStats
extends Resource
## Ground movement tuning, kept as data so other characters can reuse it,
## plus the frame-rate independent helpers that apply it.

## Top speed in meters per second.
@export_range(0.5, 20.0, 0.1, "suffix:m/s") var move_speed: float = 6.0
## How quickly speed builds up while there is input.
@export_range(1.0, 200.0, 1.0, "suffix:m/s²") var acceleration: float = 60.0
## How quickly the character stops once input is released.
@export_range(1.0, 200.0, 1.0, "suffix:m/s²") var deceleration: float = 80.0
## How quickly the visual turns toward the movement direction. Higher is snappier.
@export_range(1.0, 40.0, 0.5) var turn_sharpness: float = 18.0


## Moves `current` toward `target` at a constant rate: acceleration while
## there is a target, deceleration otherwise. The rate is linear in time, so
## the result does not depend on how a time span is split into frames, and
## stopping always reaches exactly zero.
func step_velocity(current: Vector3, target: Vector3, delta: float) -> Vector3:
	var rate := acceleration if not target.is_zero_approx() else deceleration
	return current.move_toward(target, rate * delta)


## Turns `node` toward a flat `direction` with exponential smoothing, which
## behaves the same at any frame rate. A zero direction leaves it unchanged.
func turn_toward(node: Node3D, direction: Vector3, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var weight := 1.0 - exp(-turn_sharpness * delta)
	node.rotation.y = lerp_angle(node.rotation.y, yaw_of(direction), weight)


## Node3D faces -Z, so this yaw points -Z along `direction`.
static func yaw_of(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)
