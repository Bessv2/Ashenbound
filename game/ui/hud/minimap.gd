class_name Minimap
extends Control
## The round map at the top right: the rooms of the level around the hero,
## turned so up on the map is up on screen, with the enemies as red marks
## (a boss bigger) and the hero as an ember arrow. Rooms appear once the hero
## has stood in them or next to them, so the way ahead stays unknown.
## Hidden in levels without rooms. Reads the world; changes nothing.

const BACKDROP := Color(0.08, 0.07, 0.08, 0.82)
const RIM := Color(0.62, 0.38, 0.2, 0.95)
const ROOM := Color(0.47, 0.44, 0.42, 0.95)
const ROOM_EDGE := Color(0.75, 0.66, 0.55, 0.9)
const HERO := Color("#DB6028")
const ENEMY := Color(0.86, 0.16, 0.12)
## Metres from the hero to the rim.
const RANGE := 24.0
## How far beyond a room's floor the hero may stand and still reveal it.
const REVEAL_MARGIN := 6.0
## Redraws per second (the map moves slowly; drawing costs little but is
## not free on a phone).
const RATE := 12.0

## The camera's turn, so the map turns with the view.
var yaw_degrees: float = 45.0
var player: Node3D

## Each room's floor in world X/Z, and whether it has been seen.
var _rooms: Array[Rect2] = []
var _seen: Array[bool] = []
var _wait: float = 0.0


## Reads the rooms of `level` (every CryptRoom under it). Hides the map when
## there are none.
func track_level(level: Node) -> void:
	_rooms.clear()
	_seen.clear()
	if level:
		_collect(level)
	visible = not _rooms.is_empty()
	queue_redraw()


## The rooms found, in world X/Z (for tests).
func rooms() -> Array[Rect2]:
	return _rooms


## Whether room `index` is on the map yet.
func is_seen(index: int) -> bool:
	return _seen[index]


func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is CryptRoom:
			var room := child as CryptRoom
			var centre := Vector2(room.global_position.x, room.global_position.z)
			var half := Vector2(room.size) * 0.5
			_rooms.append(Rect2(centre - half, half * 2.0))
			_seen.append(false)
		_collect(child)


func _process(delta: float) -> void:
	if not visible:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 1.0 / RATE
	_reveal()
	queue_redraw()


## Marks the rooms the hero stands in or beside as seen.
func _reveal() -> void:
	if player == null or not is_instance_valid(player):
		return
	var at := Vector2(player.global_position.x, player.global_position.z)
	for i in _rooms.size():
		if not _seen[i] and _rooms[i].grow(REVEAL_MARGIN).has_point(at):
			_seen[i] = true


## Where world point `at` (X/Z) lands on the map, relative to its centre.
func to_map(at: Vector2, origin: Vector2, scale: float) -> Vector2:
	var yaw := deg_to_rad(yaw_degrees)
	var forward := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var offset := at - origin
	return Vector2(offset.dot(right), -offset.dot(forward)) * scale


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	draw_circle(centre, radius, BACKDROP, true, -1.0, true)
	var origin := Vector2.ZERO
	if player and is_instance_valid(player):
		origin = Vector2(player.global_position.x, player.global_position.z)
	var scale := (radius - 6.0) / RANGE
	for i in _rooms.size():
		if not _seen[i]:
			continue
		var room := _rooms[i]
		var corners := PackedVector2Array()
		for corner in [room.position, Vector2(room.end.x, room.position.y), room.end, Vector2(room.position.x, room.end.y)]:
			corners.append(centre + to_map(corner, origin, scale))
		# Only the part inside the frame.
		for part in Geometry2D.intersect_polygons(corners, _disc(centre, radius - 5.0)):
			draw_colored_polygon(part, ROOM)
			part.append(part[0])
			draw_polyline(part, ROOM_EDGE, 1.5, true)
	for enemy in get_tree().get_nodes_in_group(EnemyController.GROUP):
		var body := enemy as EnemyController
		if body == null or body.health == null or body.health.is_dead():
			continue
		var spot := to_map(Vector2(body.global_position.x, body.global_position.z), origin, scale)
		if spot.length() > radius - 6.0:
			continue
		var boss := body.is_in_group(&"boss")
		draw_circle(centre + spot, 6.0 if boss else 3.5, ENEMY, true, -1.0, true)
	_draw_hero(centre)
	draw_arc(centre, radius - 2.0, 0.0, TAU, 72, RIM, 4.0, true)
	draw_arc(centre, radius - 7.0, 0.0, TAU, 72, Color(0, 0, 0, 0.5), 2.0, true)


## A circle as a polygon, for clipping.
func _disc(centre: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 32:
		points.append(centre + Vector2.from_angle(TAU * i / 32.0) * radius)
	return points


func _draw_hero(centre: Vector2) -> void:
	var facing := 0.0
	var visual: Node3D = player.get(&"visual") if player and is_instance_valid(player) else null
	if visual:
		# Models face -Z (MovementStats.yaw_of); turn that into the map's frame.
		var ahead := -visual.global_basis.z
		var on_map := to_map(Vector2(ahead.x, ahead.z), Vector2.ZERO, 1.0)
		if not on_map.is_zero_approx():
			facing = atan2(on_map.x, -on_map.y)
	var tip := Vector2(0, -11).rotated(facing)
	var left := Vector2(-7, 7).rotated(facing)
	var right := Vector2(7, 7).rotated(facing)
	draw_colored_polygon(PackedVector2Array([centre + tip, centre + right, centre + left]), HERO)
	draw_polyline(PackedVector2Array([centre + tip, centre + right, centre + left, centre + tip]), Color(0, 0, 0, 0.7), 1.5, true)
