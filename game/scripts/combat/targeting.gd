class_name Targeting
extends RefCounted
## Finds living targets around a body, by their Health, on given physics
## layers. Shared by attacks (hit and aim assist) and targeted abilities.


## Every living Health whose collider overlaps a sphere of `radius` around
## `from`, on `mask`'s layers. `from` itself is excluded when it is a
## collision object. Each Health appears once.
static func living_within(from: Node3D, radius: float, mask: int) -> Array[Health]:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, from.global_position)
	query.collision_mask = mask
	if from is CollisionObject3D:
		query.exclude = [(from as CollisionObject3D).get_rid()]
	var targets: Array[Health] = []
	for result in from.get_world_3d().direct_space_state.intersect_shape(query):
		var collider := result["collider"] as Node3D
		var health: Health = Health.of(collider) if collider else null
		if health and not health.is_dead() and not targets.has(health):
			targets.append(health)
	return targets


## The living Health within `radius` whose body is nearest to `from` on the
## ground plane, or null.
static func nearest_living(from: Node3D, radius: float, mask: int) -> Health:
	var best: Health = null
	var best_distance := INF
	for target in living_within(from, radius, mask):
		var offset := (target.get_parent() as Node3D).global_position - from.global_position
		var distance := Vector2(offset.x, offset.z).length()
		if distance < best_distance:
			best_distance = distance
			best = target
	return best
