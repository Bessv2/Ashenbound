class_name MeleeAttack
extends Node
## A melee attack performed by its parent body.
##
## An attack runs windup → hit → recovery on the physics clock. The hit
## damages every Health in `target_mask` whose body is within `reach` and
## inside the arc around the attack direction. Timing carries over between
## phases, so the attack rate does not depend on the physics tick rate.
##
## Must be a direct child of the attacking Node3D (usually a CharacterBody3D,
## which is then excluded from its own hits).

## The attack started; `direction` is the flat world direction it faces.
signal started(direction: Vector3)
## The hit resolved. `targets` is empty on a miss.
signal struck(targets: Array[Health])
## The attack was abandoned before or after its hit (see cancel()).
signal canceled

enum Phase { READY, WINDUP, RECOVERY }

@export var data: AttackData
## Physics layers that can be hit (default: layer 3, "enemy").
@export_flags_3d_physics var target_mask: int = 4

## Flat world direction of the current or last attack.
var direction: Vector3 = Vector3.FORWARD

var _phase: Phase = Phase.READY
var _time_left: float = 0.0


func _ready() -> void:
	if data == null:
		data = AttackData.new()


func _physics_process(delta: float) -> void:
	if _phase == Phase.READY:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	if _phase == Phase.WINDUP:
		struck.emit(_strike())
		_phase = Phase.RECOVERY
		_time_left += data.recovery
	if _phase == Phase.RECOVERY and _time_left <= 0.0:
		_phase = Phase.READY


func is_busy() -> bool:
	return _phase != Phase.READY


## Speed factor the attacker should apply to its movement right now.
func movement_multiplier() -> float:
	return data.movement_multiplier if is_busy() else 1.0


## Starts an attack if none is in progress. `facing` is used when aim assist
## finds no target. Returns whether an attack started.
func try_start(facing: Vector3) -> bool:
	if is_busy():
		return false
	direction = _aim(_flat(facing))
	_phase = Phase.WINDUP
	_time_left = data.windup
	started.emit(direction)
	return true


## Abandons the attack in progress. A hit that has not landed yet never will.
func cancel() -> void:
	if not is_busy():
		return
	_phase = Phase.READY
	_time_left = 0.0
	canceled.emit()


## Whether a target at `offset` (from the attacker, flattened) lies inside an
## arc of `arc_degrees` centered on `facing`.
static func is_in_arc(offset: Vector3, facing: Vector3, arc_degrees: float) -> bool:
	var flat := Vector3(offset.x, 0.0, offset.z)
	if arc_degrees >= 360.0 or flat.is_zero_approx():
		return true
	# The epsilon keeps targets exactly on the arc's edge inside despite
	# floating-point error in angle_to().
	return flat.angle_to(facing) <= deg_to_rad(arc_degrees * 0.5) + 0.0001


func _strike() -> Array[Health]:
	var hits: Array[Health] = []
	var origin := _origin()
	for target in _living_targets_within(data.reach):
		var body := target.get_parent() as Node3D
		if is_in_arc(body.global_position - origin, direction, data.arc_degrees):
			target.apply_damage(data.damage)
			hits.append(target)
	return hits


func _aim(facing: Vector3) -> Vector3:
	var fallback := facing if not facing.is_zero_approx() else direction
	if data.aim_assist_radius <= 0.0:
		return fallback
	var origin := _origin()
	var best := fallback
	var best_distance := INF
	for target in _living_targets_within(data.aim_assist_radius):
		var offset := (target.get_parent() as Node3D).global_position - origin
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.001 and distance < best_distance:
			best_distance = distance
			best = offset / distance
	return best


func _living_targets_within(radius: float) -> Array[Health]:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, _origin())
	query.collision_mask = target_mask
	var attacker := get_parent() as CollisionObject3D
	if attacker:
		query.exclude = [attacker.get_rid()]
	var targets: Array[Health] = []
	var space := (get_parent() as Node3D).get_world_3d().direct_space_state
	for result in space.intersect_shape(query):
		var collider := result["collider"] as Node3D
		var health: Health = Health.of(collider) if collider else null
		if health and not health.is_dead() and not targets.has(health):
			targets.append(health)
	return targets


func _origin() -> Vector3:
	return (get_parent() as Node3D).global_position


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()
