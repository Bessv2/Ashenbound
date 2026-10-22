class_name IsometricCameraRig
extends Node3D
## Follows a target with smoothing from a fixed isometric angle.
##
## The rig only translates. Its rotation is set once in _ready and never
## changes during gameplay, so a given stick direction always maps to the same
## on-screen direction. The child Camera3D sits `distance` meters back along
## the rig's local +Z axis, looking at the rig's origin.

## True isometric pitch: atan(1 / sqrt(2)) ≈ 35.264° below the horizon.
const ISOMETRIC_PITCH_DEGREES := -35.264

@export var target: Node3D
@export_range(-89.0, -10.0, 0.001, "degrees") var pitch_degrees: float = ISOMETRIC_PITCH_DEGREES
@export_range(-180.0, 180.0, 0.1, "degrees") var yaw_degrees: float = 45.0
## Orthographic, so distance does not change the framing. It only needs to keep
## the scene between the camera's near and far planes.
@export_range(5.0, 100.0, 0.5, "suffix:m") var distance: float = 30.0
## Higher values follow more tightly. Frame-rate independent.
@export_range(0.5, 30.0, 0.1) var follow_sharpness: float = 8.0
## Point on the target to keep centered, relative to its origin.
@export var target_offset: Vector3 = Vector3(0.0, 1.0, 0.0)

## Largest shake offset, in metres, at full trauma.
@export_range(0.0, 2.0, 0.01, "suffix:m") var shake_offset: float = 0.35
## Trauma lost per second.
@export_range(0.1, 10.0, 0.1) var shake_decay: float = 2.2
## Turned off by the player's settings (accessibility).
var shake_enabled: bool = true

## 0 to 1; the shake grows with its square, so small hits stay subtle.
var trauma: float = 0.0
var _shake_time: float = 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	# The rig is moved in _process from the target's interpolated transform.
	# Interpolating the rig as well would smooth it twice and add latency.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	rotation = Vector3(deg_to_rad(pitch_degrees), deg_to_rad(yaw_degrees), 0.0)
	camera.position = Vector3(0.0, 0.0, distance)
	snap_to_target()


## Shakes the camera; `amount` (0 to 1) adds up and decays over time.
func add_trauma(amount: float) -> void:
	if shake_enabled:
		trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	_update_shake(delta)
	if target == null:
		return
	var weight := 1.0 - exp(-follow_sharpness * delta)
	global_position = global_position.lerp(_focus_point(), weight)


func _update_shake(delta: float) -> void:
	if get_tree().paused:
		return
	trauma = maxf(trauma - shake_decay * delta, 0.0)
	_shake_time += delta
	var strength := trauma * trauma * shake_offset
	# Smooth pseudo-noise from two sines per axis; the camera only moves
	# sideways and up in its own plane, never rotates.
	camera.position.x = strength * sin(_shake_time * 47.0) * cos(_shake_time * 23.0)
	camera.position.y = strength * sin(_shake_time * 39.0 + 1.3) * cos(_shake_time * 17.0)


## Jumps to the target without smoothing, e.g. after spawning or teleporting.
func snap_to_target() -> void:
	if target:
		global_position = _focus_point()


func _focus_point() -> Vector3:
	return target.get_global_transform_interpolated().origin + target_offset
