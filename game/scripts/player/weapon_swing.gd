class_name WeaponSwing
extends Node3D
## Placeholder weapon animation: sweeps this pivot across the attack arc
## during the windup and returns it to rest during recovery. Visual only.

@export var attack: MeleeAttack
## Yaw at rest, relative to the facing. Positive is to the character's left.
@export_range(-180.0, 180.0, 1.0, "degrees") var rest_degrees: float = 70.0

var _tween: Tween


func _ready() -> void:
	rotation.y = deg_to_rad(rest_degrees)
	if attack:
		attack.started.connect(_on_attack_started)


func _on_attack_started(_direction: Vector3) -> void:
	if _tween:
		_tween.kill()
	# Sweep left to right across the hit arc, landing as the hit resolves.
	var data := attack.data
	var swing_end := deg_to_rad(-data.arc_degrees * 0.5)
	rotation.y = deg_to_rad(data.arc_degrees * 0.5)
	# Physics clock: the pivot is part of the interpolated player.
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(self, "rotation:y", swing_end, maxf(data.windup, 0.01)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "rotation:y", deg_to_rad(rest_degrees), maxf(data.recovery, 0.01)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
