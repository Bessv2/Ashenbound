class_name CryptRoom
extends Node3D
## One rectangular room or corridor of the crypt, built when it enters the
## tree: the floor, the walls with their collision, and wall torches. The origin
## is the centre of the floor, whose top is at y = 0. North is -Z.
##
## Seen from the camera (south-east, looking north-west), the north and west
## walls are the far ones: full-height stone walls. The south and east walls
## are the near ones: low colonnades, so they never hide the player.
##
## Each side can be a solid wall, a wall with a 4 m gap in its middle (for a
## CryptGate, or a corridor joining from outside), or absent (the open ends of
## a corridor). A side with a gap should be 12, 20 or 28 m long, so the wall
## pieces on either side of the gap come out whole.
##
## Place a CryptRoom under the level's BakedNavigationRegion: it builds in its
## own _ready, before the region bakes in its _ready.

enum Edge { WALL, GAP, NONE }

## Width of the gap an Edge.GAP leaves, and of every corridor.
const GAP_WIDTH := 4.0
const FAR_WALL_HEIGHT := 3.0
const NEAR_WALL_HEIGHT := 1.0
const WALL_PIECE_LENGTH := 4.0
const COLUMN_SPACING := 2.0
const TORCH_HEIGHT := 2.2

const FloorPiece := preload("res://assets/third_party/kaykit/dungeon/floor_tile_large.glb")
const WallPiece := preload("res://assets/third_party/kaykit/dungeon/wall.glb")
const CrackedWallPiece := preload("res://assets/third_party/kaykit/dungeon/wall_cracked.glb")
const ColumnPiece := preload("res://assets/third_party/kaykit/dungeon/column.glb")
const CornerPiece := preload("res://assets/third_party/kaykit/dungeon/pillar_decorated.glb")
const TorchPiece := preload("res://assets/third_party/kaykit/dungeon/torch_mounted.glb")
## North walls stand between the camera and anyone in the corridor behind
## them, so they open up around the hero.
const CutoutMaterial := preload("res://resources/materials/dungeon_cutout.tres")

## Interior floor size in metres (x across, y along north-south). Multiples of 4.
@export var size: Vector2i = Vector2i(12, 12)
@export var north: Edge = Edge.WALL
@export var south: Edge = Edge.WALL
@export var west: Edge = Edge.WALL
@export var east: Edge = Edge.WALL
@export var torches: bool = true
## The torches' fire: warm by default; the Forgotten Catacombs burn cold.
@export var torch_light_color: Color = Color(1.0, 0.5, 0.2)
@export var torch_core_color: Color = Color(1.0, 0.85, 0.45)
@export var torch_edge_color: Color = Color(1.0, 0.35, 0.08)
## Varies the floor tile turns and cracked walls between rooms.
@export var seed: int = 1

## Every collision box built, in this node's space, for tests.
var collision_boxes: Array[AABB] = []

var _half: Vector2
var _grids: int = 0


func _ready() -> void:
	if size.x % 4 != 0 or size.y % 4 != 0:
		push_error("%s: room sizes must be multiples of 4 m, got %s." % [name, size])
	_half = Vector2(size) * 0.5
	_build_floor()
	_build_north()
	_build_south()
	_build_west()
	_build_east()
	if torches:
		_place_torches()
	_add_dust()


## Motes of dust and ash hanging in the air of the room, catching the torch
## light. Visual only; a few dozen slow CPU particles.
func _add_dust() -> void:
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = clampi(int(size.x * size.y / 12.0), 12, 60)
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(_half.x, 1.6, _half.y)
	dust.position = Vector3(0.0, 1.9, 0.0)
	dust.direction = Vector3(0.3, 1.0, 0.1)
	dust.spread = 60.0
	dust.gravity = Vector3(0.0, 0.02, 0.0)
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.2
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 1))
	dust.color_ramp = fade
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.09, 0.09)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 0.72, 0.45, 0.22)
	material.albedo_texture = FlameFx.soft_dot()
	mesh.material = material
	dust.mesh = mesh
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)


func _build_floor() -> void:
	# The body reaches under the walls, so doorways and corner seams have floor.
	_add_box(AABB(Vector3(-_half.x - 1.0, -1.0, -_half.y - 1.0), Vector3(size.x + 2.0, 1.0, size.y + 2.0)))
	var grid := _grid([FloorPiece], Vector2i(size.x / 4, size.y / 4), Vector2(4.0, 4.0))
	grid.random_quarter_turns = true
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid.position = Vector3(-_half.x, -0.05, -_half.y)
	add_child(grid)


func _build_north() -> void:
	var z := -_half.y - 0.5
	match north:
		Edge.WALL:
			_far_wall_along_x(z, -_half.x, _half.x)
		Edge.GAP:
			_far_wall_along_x(z, -_half.x, -GAP_WIDTH * 0.5)
			_far_wall_along_x(z, GAP_WIDTH * 0.5, _half.x)
	if north != Edge.NONE and west != Edge.NONE:
		# The north-west corner, where the two far walls meet.
		var corner := CornerPiece.instantiate() as Node3D
		corner.name = "CornerPillar"
		for part: GeometryInstance3D in corner.find_children("*", "GeometryInstance3D", true, false):
			part.material_override = CutoutMaterial
		corner.transform = Transform3D(Basis.from_scale(Vector3(0.55, 1.0, 0.55)),
				Vector3(-_half.x - 0.5, 0.0, z))
		add_child(corner)
		_add_box(AABB(Vector3(-_half.x - 1.0, 0.0, z - 0.5), Vector3(1.0, FAR_WALL_HEIGHT, 1.0)))


func _build_south() -> void:
	var z := _half.y + 0.5
	match south:
		Edge.WALL:
			_near_wall_along_x(z, -_half.x, _half.x)
		Edge.GAP:
			_near_wall_along_x(z, -_half.x, -GAP_WIDTH * 0.5)
			_near_wall_along_x(z, GAP_WIDTH * 0.5, _half.x)


## West: a far wall (see-through around the hero, like the north walls, since
## a corridor can now run behind it).
func _build_west() -> void:
	var x := -_half.x - 0.5
	match west:
		Edge.WALL:
			_far_wall_along_z(x, -_half.y, _half.y)
		Edge.GAP:
			_far_wall_along_z(x, -_half.y, -GAP_WIDTH * 0.5)
			_far_wall_along_z(x, GAP_WIDTH * 0.5, _half.y)


## East: a near colonnade.
func _build_east() -> void:
	var x := _half.x + 0.5
	match east:
		Edge.WALL:
			_near_wall_along_z(x, -_half.y, _half.y)
		Edge.GAP:
			_near_wall_along_z(x, -_half.y, -GAP_WIDTH * 0.5)
			_near_wall_along_z(x, GAP_WIDTH * 0.5, _half.y)


## A full-height wall whose inner face runs along z = `z_center` + 0.5, from
## x = `from` to `to`.
func _far_wall_along_x(z_center: float, from: float, to: float) -> void:
	var grid := _wall_grid(to - from)
	grid.material_override = CutoutMaterial
	grid.position = Vector3(from, 0.0, z_center - 0.5)
	add_child(grid)
	_add_box(AABB(Vector3(from, 0.0, z_center - 0.5), Vector3(to - from, FAR_WALL_HEIGHT, 1.0)))


## A full-height wall whose inner face runs along x = `x_center` + 0.5, from
## z = `from` to `to`.
func _far_wall_along_z(x_center: float, from: float, to: float) -> void:
	var grid := _wall_grid(to - from)
	grid.material_override = CutoutMaterial
	# Cells run along local +X; this basis turns them to run along +Z.
	grid.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)),
			Vector3(x_center + 0.5, 0.0, from))
	add_child(grid)
	_add_box(AABB(Vector3(x_center - 0.5, 0.0, from), Vector3(1.0, FAR_WALL_HEIGHT, to - from)))


func _near_wall_along_x(z_center: float, from: float, to: float) -> void:
	var grid := _column_grid(to - from)
	grid.position = Vector3(from - COLUMN_SPACING * 0.5, 0.0, z_center - 0.5)
	add_child(grid)
	_add_box(AABB(Vector3(from, 0.0, z_center - 0.5), Vector3(to - from, NEAR_WALL_HEIGHT, 1.0)))


func _near_wall_along_z(x_center: float, from: float, to: float) -> void:
	var grid := _column_grid(to - from)
	grid.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)),
			Vector3(x_center + 0.5, 0.0, from - COLUMN_SPACING * 0.5))
	add_child(grid)
	_add_box(AABB(Vector3(x_center - 0.5, 0.0, from), Vector3(1.0, NEAR_WALL_HEIGHT, to - from)))


func _wall_grid(length: float) -> TileGrid:
	var grid := _grid([WallPiece, CrackedWallPiece], Vector2i(roundi(length / WALL_PIECE_LENGTH), 1),
			Vector2(WALL_PIECE_LENGTH, 1.0))
	grid.weights = PackedFloat32Array([3.0, 1.0])
	return grid


## Columns at both ends and every COLUMN_SPACING between.
func _column_grid(length: float) -> TileGrid:
	return _grid([ColumnPiece], Vector2i(roundi(length / COLUMN_SPACING) + 1, 1),
			Vector2(COLUMN_SPACING, 1.0))


func _grid(pieces: Array[PackedScene], cells: Vector2i, spacing: Vector2) -> TileGrid:
	var grid := TileGrid.new()
	_grids += 1
	grid.name = "Grid%d" % _grids
	grid.pieces = pieces
	grid.cells = cells
	grid.spacing = spacing
	grid.seed = seed * 100 + _grids
	return grid


## Torches on the inner faces of the far walls: one in the middle of each
## stretch of north wall, and one per 12 m (at least one) along the west wall,
## or one in the middle of each stretch beside a west gap.
func _place_torches() -> void:
	var north_x: Array[float] = []
	match north:
		Edge.WALL:
			north_x = [-_half.x * 0.5, _half.x * 0.5]
		Edge.GAP:
			var middle := (_half.x + GAP_WIDTH * 0.5) * 0.5
			north_x = [-middle, middle]
	for x in north_x:
		_add_torch(Transform3D(Basis(), Vector3(x, TORCH_HEIGHT, -_half.y)))
	var west_z: Array[float] = []
	match west:
		Edge.WALL:
			var count := maxi(1, ceili(size.y / 12.0))
			for i in count:
				west_z.append(-_half.y + (i + 0.5) * size.y / float(count))
		Edge.GAP:
			var middle := (_half.y + GAP_WIDTH * 0.5) * 0.5
			west_z = [-middle, middle]
	for z in west_z:
		_add_torch(Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)),
				Vector3(-_half.x, TORCH_HEIGHT, z)))


func _add_torch(at: Transform3D) -> void:
	var torch := TorchPiece.instantiate() as Node3D
	torch.name = "Torch%d" % (get_child_count())
	torch.transform = at
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.55, 0.45)
	light.light_color = torch_light_color
	light.light_energy = 2.4
	light.omni_range = 8.0
	torch.add_child(light)
	var flame := FlameFx.new()
	flame.name = "Fire"
	flame.light = light
	flame.core_color = torch_core_color
	flame.edge_color = torch_edge_color
	flame.size = 0.42
	flame.ember_count = 5
	flame.position = Vector3(0.0, 0.42, 0.32)
	torch.add_child(flame)
	add_child(torch)


func _add_box(box: AABB) -> void:
	var shape := BoxShape3D.new()
	shape.size = box.size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.name = "Body%d" % collision_boxes.size()
	body.position = box.get_center()
	body.add_child(collision)
	add_child(body)
	collision_boxes.append(box)
