class_name TileGrid
extends Node3D
## Lays out a grid of modular level pieces (floor tiles, wall segments,
## columns) as MultiMesh chunks, so a whole floor costs a handful of draw
## calls instead of one per tile. Visual only: collision and navigation come
## from the level's own bodies.
##
## Cells run along local +X and +Z from this node's origin, one `spacing` apart,
## centred on the cell. Each cell picks one of `pieces` at random (weighted by
## `weights`, repeatable through `seed`). Cells are grouped into chunks of
## `chunk_cells` × `chunk_cells`: on mobile, a mesh instance is lit by at most
## 8 lights, so smaller chunks keep every local light visible.

@export var pieces: Array[PackedScene] = []
## Relative chance of each piece, matched by index; missing weights count as 1.
@export var weights: PackedFloat32Array = []
@export var cells: Vector2i = Vector2i(1, 1)
@export var spacing: Vector2 = Vector2(4.0, 4.0)
## Turns each cell by a random multiple of 90° (for floor tiles).
@export var random_quarter_turns: bool = false
@export var seed: int = 1
@export_range(1, 64, 1) var chunk_cells: int = 5
@export var cast_shadow: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

## Every piece placed, as [piece index, transform relative to this node]. The
## same data the MultiMeshes hold, readable without a renderer (tests run
## headless, where MultiMesh transforms are not stored).
var placed: Array = []
## The mesh used for each piece, matched by index.
var piece_meshes: Array[Mesh] = []


func _ready() -> void:
	var meshes: Array[Mesh] = []
	var offsets: Array[Transform3D] = []
	for piece in pieces:
		var found := _first_mesh(piece)
		meshes.append(found[0])
		offsets.append(found[1])
	if meshes.is_empty() or meshes.has(null):
		push_error("%s: every piece needs a MeshInstance3D." % name)
		return
	piece_meshes = meshes
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var weight_list := PackedFloat32Array()
	for i in meshes.size():
		weight_list.append(weights[i] if i < weights.size() else 1.0)
	# chunk key → piece index → cell transforms
	var chunks := {}
	for z in cells.y:
		for x in cells.x:
			var piece := rng.rand_weighted(weight_list)
			var cell := Transform3D(Basis(), Vector3((x + 0.5) * spacing.x, 0.0, (z + 0.5) * spacing.y))
			if random_quarter_turns:
				cell.basis = Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5)
			var key := Vector2i(x / chunk_cells, z / chunk_cells)
			if not chunks.has(key):
				chunks[key] = {}
			if not chunks[key].has(piece):
				chunks[key][piece] = []
			chunks[key][piece].append(cell * offsets[piece])
			placed.append([piece, cell * offsets[piece]])
	for key: Vector2i in chunks:
		for piece: int in chunks[key]:
			var transforms: Array = chunks[key][piece]
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = meshes[piece]
			multimesh.instance_count = transforms.size()
			for i in transforms.size():
				multimesh.set_instance_transform(i, transforms[i])
			var instance := MultiMeshInstance3D.new()
			instance.name = "Chunk_%d_%d_%d" % [key.x, key.y, piece]
			instance.multimesh = multimesh
			instance.cast_shadow = cast_shadow
			add_child(instance)


## The first mesh in `scene` and its transform relative to the scene's root.
static func _first_mesh(scene: PackedScene) -> Array:
	if scene == null:
		return [null, Transform3D()]
	var root := scene.instantiate()
	var found: Array = [null, Transform3D()]
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var offset := Transform3D()
		var walk: Node = node
		while walk != root:
			if walk is Node3D:
				offset = (walk as Node3D).transform * offset
			walk = walk.get_parent()
		found = [(node as MeshInstance3D).mesh, offset]
		break
	root.free()
	return found
