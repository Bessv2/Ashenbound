class_name Projectile
extends Node3D
## A shot that flies in a straight line at `speed` until it hits something or
## has flown `max_distance`. It damages the first Health it touches on
## `target_mask`; walls (the world layer) stop it. A target that is
## invulnerable (dodging) takes nothing, and the shot is spent either way.
##
## Movement is swept with a ray each physics tick, so a fast shot cannot pass
## through a thin wall or a target between two ticks.

signal impacted(collider: Object)

const WORLD_LAYER := 1

var direction: Vector3 = Vector3.FORWARD
var speed: float = 10.0
var damage: int = 10
var max_distance: float = 12.0
var target_mask: int = 2
## Bodies the shot passes through (the shooter).
var exclude: Array[RID] = []

var _flown: float = 0.0


func _ready() -> void:
	direction = Vector3(direction.x, 0.0, direction.z).normalized()
	if not direction.is_zero_approx():
		look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	var step := minf(speed * delta, max_distance - _flown)
	var from := global_position
	var to := from + direction * step
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER | target_mask, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		_impact(hit.collider)
		return
	global_position = to
	_flown += step
	if _flown >= max_distance - 0.0001:
		queue_free()


func _impact(collider: Object) -> void:
	if collider is CollisionObject3D and (collider as CollisionObject3D).collision_layer & target_mask:
		var health := Health.of(collider as Node)
		if health:
			health.apply_damage(damage, global_position - direction)
	impacted.emit(collider)
	queue_free()
