class_name RingAttack
extends MeleeAttack
## An attack that releases an EmberRing around the attacker when its windup
## ends, instead of striking in front of it. `data.reach` is the ring's final
## radius (AttackTelegraph shows it as a full circle: give the data a 360°
## arc). Same windup → release → recovery cycle as MeleeAttack.

@export var ring_scene: PackedScene
@export_range(0.1, 10.0, 0.1, "suffix:s") var expand_seconds: float = 2.0


func _strike() -> Array[Health]:
	var attacker := get_parent() as Node3D
	if ring_scene == null or attacker.get_parent() == null:
		push_error("%s: a RingAttack needs a ring scene." % attacker.name)
		return []
	var ring := ring_scene.instantiate() as EmberRing
	ring.damage = data.damage
	ring.max_radius = data.reach
	ring.duration = expand_seconds
	ring.target_mask = target_mask
	ring.position = Vector3(attacker.position.x, attacker.position.y + 0.05, attacker.position.z)
	attacker.add_sibling(ring)
	return []
