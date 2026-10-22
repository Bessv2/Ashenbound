class_name EmberRing
extends Node3D
## A ring of fire that expands from its origin to `max_radius` over
## `duration` and then fades. It damages each target on `target_mask` once,
## at the moment the ring's edge sweeps past it, unless the target is
## invulnerable (dodging) right then. Standing beyond `max_radius` is safe.
## The damage is applied here, by the gameplay node; the mesh is only the
## picture of it.

const RING_HALF_WIDTH := 0.6

var damage: int = 20
var max_radius: float = 10.0
var duration: float = 2.0
var target_mask: int = 2

## The ring's current radius.
var radius: float = 0.0

var _swept: Array[Health] = []
var _elapsed: float = 0.0

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	_mesh.scale = Vector3.ONE * 0.01


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var previous := radius
	radius = minf(max_radius, max_radius * _elapsed / duration)
	_mesh.scale = Vector3(maxf(radius, 0.01), 1.0, maxf(radius, 0.01))
	for target in Targeting.living_within(self, radius + RING_HALF_WIDTH, target_mask):
		if _swept.has(target):
			continue
		var body := target.get_parent() as Node3D
		var offset := body.global_position - global_position
		var distance := Vector2(offset.x, offset.z).length()
		if distance >= previous - RING_HALF_WIDTH:
			# The edge reaches this target now: it is struck or it dodged.
			_swept.append(target)
			target.apply_damage(damage, global_position)
	if _elapsed >= duration:
		queue_free()
