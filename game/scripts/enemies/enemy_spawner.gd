class_name EnemySpawner
extends Node3D
## Keeps up to `max_alive` enemies alive. Spawns them at its Marker3D children,
## at the free point (no living enemy within CLEARANCE) farthest from the
## player, and replaces each enemy `respawn_delay` seconds after it is removed.
## Give it at least `max_alive` points: enemies spawned on top of each other
## are pushed apart violently by the physics engine.

signal spawned(enemy: Node3D)

const CLEARANCE := 1.5

@export var enemy_scene: PackedScene
@export_range(0, 50, 1) var max_alive: int = 3
@export_range(0.0, 60.0, 0.1, "suffix:s") var respawn_delay: float = 4.0
## When false the spawner does nothing. Tests turn it off for a quiet arena.
@export var enabled: bool = true

var _alive: Array[Node3D] = []
var _cooldown: float = 0.0


func _ready() -> void:
	if not enabled:
		return
	if _spawn_points().size() < max_alive:
		push_warning("%s has fewer spawn points than max_alive (%d); enemies may overlap." % [name, max_alive])
	for i in max_alive:
		spawn()


func _physics_process(delta: float) -> void:
	if not enabled or _alive.size() >= max_alive:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		spawn()


func alive_count() -> int:
	return _alive.size()


## Spawns one enemy now, regardless of the limit and cooldown.
func spawn() -> Node3D:
	var enemy := enemy_scene.instantiate() as Node3D
	# Positioned before entering the tree so physics interpolation starts there.
	enemy.position = _pick_spawn_position()
	add_child(enemy)
	enemy.tree_exiting.connect(_on_enemy_removed.bind(enemy))
	_alive.append(enemy)
	_cooldown = respawn_delay
	spawned.emit(enemy)
	return enemy


## The local position of the free spawn point farthest from the player. Falls
## back to occupied points when none is free, and to the spawner's origin when
## it has no Marker3D children.
func _pick_spawn_position() -> Vector3:
	var points := _spawn_points()
	if points.is_empty():
		return Vector3.ZERO
	var candidates := points.filter(func(point: Marker3D) -> bool: return not _is_occupied(point))
	if candidates.is_empty():
		candidates = points
	var player := get_tree().get_first_node_in_group(PlayerController.GROUP) as Node3D
	if player == null:
		return candidates[0].position
	var best: Marker3D = candidates[0]
	for point: Marker3D in candidates:
		if point.global_position.distance_squared_to(player.global_position) \
				> best.global_position.distance_squared_to(player.global_position):
			best = point
	return best.position


func _spawn_points() -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D:
			points.append(child)
	return points


func _is_occupied(point: Marker3D) -> bool:
	for enemy in _alive:
		if enemy.global_position.distance_to(point.global_position) < CLEARANCE:
			return true
	return false


func _on_enemy_removed(enemy: Node3D) -> void:
	_alive.erase(enemy)
	_cooldown = respawn_delay
