class_name FrontalGuard
extends Node
## A shield held to the front: hits that come from within `arc_degrees` of the
## way `facing` points deal `multiplier` of their damage, unless `body` is in
## the middle of an attack (the shield is down while it swings). Hits that
## do not say where they come from (burning) are not reduced.

@export var body: EnemyController
@export var health: Health
## Its forward (-Z) is the front.
@export var facing: Node3D
@export_range(0.0, 1.0, 0.05) var multiplier: float = 0.5
@export_range(10.0, 360.0, 1.0, "degrees") var arc_degrees: float = 120.0


func _ready() -> void:
	health.direction_multiplier = factor_from


## The damage factor for a hit coming from world position `from`.
func factor_from(from: Vector3) -> float:
	if body.is_attacking() or body.state == EnemyController.State.DEAD:
		return 1.0
	var front := -facing.global_basis.z
	front.y = 0.0
	if front.is_zero_approx():
		return 1.0
	var offset := from - body.global_position
	return multiplier if MeleeAttack.is_in_arc(offset, front.normalized(), arc_degrees) else 1.0
