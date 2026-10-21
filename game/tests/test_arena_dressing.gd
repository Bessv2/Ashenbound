extends "res://tests/framework/test_case.gd"
## Tests for the arena's visual dressing: the TileGrid builder and the
## per-renderer lighting. Collision and navigation are covered elsewhere.

const ArenaScene := preload("res://scenes/arena/test_arena.tscn")

var arena: Node3D


func _ready() -> void:
	arena = ArenaScene.instantiate()
	add_child(arena)


func _instances(grid: TileGrid) -> int:
	var total := 0
	for chunk: MultiMeshInstance3D in grid.get_children():
		total += chunk.multimesh.instance_count
	return total


## World-space bounds of every piece the grid placed.
func _piece_bounds(grid: TileGrid) -> Array[AABB]:
	var out: Array[AABB] = []
	for entry: Array in grid.placed:
		out.append(grid.global_transform * entry[1] * grid.piece_meshes[entry[0]].get_aabb())
	return out


func test_the_floor_covers_the_arena_in_chunks() -> void:
	var floor: TileGrid = arena.get_node("Dressing/Floor")
	check(_instances(floor) == 100, "10 × 10 tiles, got %d" % _instances(floor))
	check(floor.get_child_count() == 4, "in four 5 × 5 chunks, got %d" % floor.get_child_count())
	var pieces := _piece_bounds(floor)
	var bounds := pieces[0]
	for box in pieces:
		bounds = bounds.merge(box)
	check_near(bounds.position.x, -20.0, 0.01, "starts at the west wall")
	check_near(bounds.end.z, 20.0, 0.01, "ends at the south wall")
	check(bounds.end.y <= 0.01, "the tiles' tops sit at floor level, %.3f" % bounds.end.y)


func test_walls_line_the_edges() -> void:
	check(_instances(arena.get_node("Dressing/NorthWall")) == 10, "ten north wall segments")
	check(_instances(arena.get_node("Dressing/WestWall")) == 10, "ten west wall segments")
	check(_instances(arena.get_node("Dressing/SouthColonnade")) == 21, "21 south columns")
	for box in _piece_bounds(arena.get_node("Dressing/WestWall")):
		check(box.position.x < -20.0 and box.end.x <= -19.3, "a west wall segment stays out of the room: x %.2f to %.2f" % [box.position.x, box.end.x])
	for box in _piece_bounds(arena.get_node("Dressing/NorthWall")):
		check(box.end.z <= -19.3, "a north wall segment stays out of the room: z up to %.2f" % box.end.z)


func test_the_grid_is_repeatable() -> void:
	var a := _transforms(arena.get_node("Dressing/NorthWall"))
	var copy: Node3D = ArenaScene.instantiate()
	add_child(copy)
	check(a == _transforms(copy.get_node("Dressing/NorthWall")), "the same seed lays out the same wall")


func _transforms(grid: TileGrid) -> Array:
	return grid.placed


func test_the_mobile_renderer_keeps_the_main_lighting() -> void:
	var environment: WorldEnvironment = arena.get_node("WorldEnvironment")
	check(RenderingServer.get_current_rendering_method() != "gl_compatibility", "tests run without the Compatibility renderer")
	check(environment.environment.resource_path.ends_with("arena_environment.tres"), "main environment kept")
	check_near((arena.get_node("Moonlight") as DirectionalLight3D).light_energy, 1.05, 0.001, "moonlight unchanged")
