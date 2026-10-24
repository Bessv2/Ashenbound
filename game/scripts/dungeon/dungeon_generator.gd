class_name DungeonGenerator
extends RefCounted
## Lays a dungeon out anew for each run (docs/dungeons/generation.md).
##
## It starts from the dungeon's authored scene, which gives the lighting, the
## environment, the start room, the boss hall with its dressing and boss, and
## the names of the story fights. Everything between is replaced before the
## level enters the tree:
## - a winding chain of fighting rooms from the start to the boss hall, each
##   turning north, east or west, of random size, joined by corridors and
##   sealed by gates during its fight;
## - the story fights in order (their titles drive the quests), with extra
##   untitled fights mixed in at higher tiers;
## - optional sealed vaults off the chain, guarded by Champions, with a hoard;
## - props, braziers and spawn points placed at random, and waves rolled from
##   the dungeon's enemies, larger with the tier and the depth.
## The same seed always builds the same dungeon.

const NORTH := Vector2(0, -1)
const EAST := Vector2(1, 0)
const WEST := Vector2(-1, 0)
const SOUTH := Vector2(0, 1)
## Room sides that hold a 4 m gap must be one of these lengths
## (CryptRoom).
const FIGHT_SIDES: Array[int] = [20, 28]
const VAULT_SIDES: Array[int] = [12, 20]
const CORRIDOR_LENGTHS: Array[int] = [8, 12]
## Space kept free around every room and corridor, past its walls.
const CLEARANCE := 1.5
const MAX_WAVE := 9
const SPAWN_STEP := 3.0
## No enemy rises this close to the doorway the hero comes in by.
const SPAWN_DOOR_CLEARANCE := 6.0
const VAULT_TITLE := "A Sealed Vault"
const VAULT_SUBTITLE := "Its guardians never sleep"
const VAULT_CHAMPION_BONUS := 0.4

const GateScene := preload("res://scenes/dungeon/crypt_gate.tscn")

const ENEMIES := {
	"skeleton": "res://scenes/enemies/skeleton_warrior.tscn",
	"cultist": "res://scenes/enemies/dark_cultist.tscn",
	"knight": "res://scenes/enemies/fallen_knight.tscn",
	"ghoul": "res://scenes/enemies/ghoul.tscn",
	"demon": "res://scenes/enemies/demon.tscn",
	"imp": "res://scenes/enemies/imp.tscn",
}

## Prop kind → [model, scale, collision radius (0: none)]. Tall props only
## stand against the far walls or as pillars, where they cannot hide the hero.
const PROPS := {
	"pillar": ["res://assets/third_party/kaykit/dungeon/pillar_decorated.glb", 0.7, 0.7],
	"column": ["res://assets/third_party/kaykit/dungeon/column.glb", 1.0, 0.5],
	"barrel": ["res://assets/third_party/kaykit/dungeon/barrel_large.glb", 1.0, 0.9],
	"banner": ["res://assets/third_party/kaykit/dungeon/banner_red.glb", 1.0, 0.0],
	"weaponrack": ["res://assets/third_party/kaykit/hexagon/weaponrack.gltf", 2.2, 0.7],
	"crate": ["res://assets/third_party/kaykit/hexagon/crate_A_big.gltf", 2.4, 0.8],
	"rock": ["res://assets/third_party/kaykit/hexagon/rock_single_A.gltf", 8.0, 1.1],
	"rock_tall": ["res://assets/third_party/kaykit/hexagon/rock_single_C.gltf", 9.0, 1.2],
	"boulder": ["res://assets/third_party/kaykit/hexagon/rock_single_E.gltf", 8.0, 1.0],
	"dead_tree": ["res://assets/third_party/kaykit/halloween/tree_dead_large.gltf", 1.1, 0.6],
	"dead_tree_small": ["res://assets/third_party/kaykit/halloween/tree_dead_medium.gltf", 1.0, 0.5],
	"pine": ["res://assets/third_party/kaykit/halloween/tree_pine_orange_large.gltf", 1.0, 0.8],
	"pine_small": ["res://assets/third_party/kaykit/halloween/tree_pine_yellow_medium.gltf", 1.0, 0.6],
	"gravestone": ["res://assets/third_party/kaykit/halloween/gravestone.gltf", 1.0, 0.6],
	"grave": ["res://assets/third_party/kaykit/halloween/grave_A.gltf", 1.0, 0.7],
	"fence": ["res://assets/third_party/kaykit/halloween/fence_broken.gltf", 1.0, 0.0],
	"lantern": ["res://assets/third_party/kaykit/halloween/lantern_standing.gltf", 1.0, 0.3],
	"shrine": ["res://assets/third_party/kaykit/halloween/shrine_candles.gltf", 1.0, 0.8],
	"candles": ["res://assets/third_party/kaykit/halloween/candle_triple.gltf", 1.0, 0.0],
	"skull": ["res://assets/third_party/kaykit/halloween/skull.gltf", 1.2, 0.0],
	"ribcage": ["res://assets/third_party/kaykit/halloween/ribcage.gltf", 1.2, 0.0],
	"coffin": ["res://assets/third_party/kaykit/halloween/coffin.gltf", 1.0, 0.8],
	"stone_pillar": ["res://assets/third_party/kaykit/halloween/pillar.gltf", 1.0, 0.5],
	"plaque": ["res://assets/third_party/kaykit/halloween/plaque_candles.gltf", 1.0, 0.5],
}

## Dungeon id → its enemies (basic ones, picked evenly; a ranged one; an
## elite) and props (far walls, near walls, pillars, a centrepiece).
const RECIPES := {
	"crypt": {"basic": ["skeleton"], "ranged": "cultist", "elite": "knight",
			"far": ["pillar", "banner", "column"], "near": ["barrel", "skull", "coffin"],
			"pillar": "pillar", "centre": ["coffin", "shrine"]},
	"catacombs": {"basic": ["ghoul", "ghoul", "skeleton"], "ranged": "cultist", "elite": "knight",
			"far": ["column", "stone_pillar", "banner"], "near": ["ribcage", "skull", "coffin", "candles"],
			"pillar": "stone_pillar", "centre": ["coffin", "shrine"]},
	"keep": {"basic": ["skeleton", "skeleton", "knight"], "ranged": "cultist", "elite": "knight",
			"far": ["pillar", "banner", "weaponrack"], "near": ["barrel", "crate", "skull"],
			"pillar": "column", "centre": ["weaponrack", "crate"]},
	"forest": {"basic": ["ghoul", "ghoul", "skeleton"], "ranged": "cultist", "elite": "knight",
			"far": ["dead_tree", "pine", "dead_tree_small"], "near": ["gravestone", "grave", "fence", "lantern"],
			"pillar": "dead_tree_small", "centre": ["grave", "shrine"]},
	"volcano": {"basic": ["demon", "imp", "demon"], "ranged": "imp", "elite": "demon",
			"far": ["rock_tall", "pillar", "rock_tall"], "near": ["boulder", "rock", "ribcage", "skull"],
			"pillar": "rock_tall", "centre": ["boulder", "rock"]},
	"temple": {"basic": ["skeleton", "imp", "skeleton"], "ranged": "cultist", "elite": "knight",
			"far": ["column", "shrine", "stone_pillar"], "near": ["plaque", "candles", "coffin", "skull"],
			"pillar": "column", "centre": ["shrine", "coffin"]},
	"ice": {"basic": ["ghoul", "skeleton", "demon"], "ranged": "cultist", "elite": "knight",
			"far": ["pine_small", "rock_tall", "pine"], "near": ["boulder", "rock", "ribcage", "gravestone"],
			"pillar": "rock_tall", "centre": ["boulder", "gravestone"]},
}

## Nodes of an authored level that are its frame, not its layout.
const FRAME := ["PlayerStart", "WorldEnvironment", "Moonlight", "RendererLighting", "Navigation",
		"Encounters", "CombatRooms"]


## A room or corridor being laid out.
class Piece:
	var name: String
	var size: Vector2i
	## Centre of the floor, as (x, z).
	var centre: Vector2
	var kind: String
	## Direction → CryptRoom.Edge, for the sides that are not plain walls.
	var sides := {}
	## The side the hero comes in by (zero for the start).
	var entry := Vector2.ZERO
	var depth: int = 0

	func _init(piece_name: String, piece_size: Vector2i, at: Vector2, piece_kind: String) -> void:
		name = piece_name
		size = piece_size
		centre = at
		kind = piece_kind

	func half_along(direction: Vector2) -> float:
		return size.x * 0.5 if direction.x != 0.0 else size.y * 0.5

	func rect(margin: float) -> Rect2:
		var half := Vector2(size) * 0.5
		return Rect2(centre - half - Vector2.ONE * margin, Vector2(size) + Vector2.ONE * margin * 2.0)


## A doorway between two pieces: the gate in `from`'s side `direction`.
class Link:
	var from: Piece
	var to: Piece
	var direction: Vector2
	var corridor: Piece
	var gate: CryptGate


var dungeon_id: String
var difficulty: Difficulty
var rng := RandomNumberGenerator.new()
## Laid out by generate(), in order: the start, the fights, the boss hall.
var chain: Array[Piece] = []
var vaults: Array[Piece] = []
var corridors: Array[Piece] = []

var _links: Array[Link] = []
var _recipe: Dictionary
var _scenes := {}
var _torch_colors: Array[Color] = []
## Points taken by props in the room being dressed: (x, z, radius).
var _taken: Array[Vector3] = []


func _init(dungeon: String, run_difficulty: Difficulty, layout_seed: int) -> void:
	dungeon_id = dungeon
	difficulty = run_difficulty if run_difficulty else Difficulty.new(1)
	rng.seed = layout_seed
	_recipe = RECIPES.get(dungeon, RECIPES[Dungeons.CRYPT])


## Replaces the layout of `level` (an authored dungeon, not yet in the tree)
## with a new one.
func generate(level: Level) -> void:
	var navigation := level.get_node("Navigation") as Node3D
	var authored_rooms: Array[CryptRoom] = []
	for node in navigation.get_node("Rooms").get_children():
		if node is CryptRoom:
			authored_rooms.append(node)
	var first := authored_rooms[0]
	_torch_colors = [first.torch_light_color, first.torch_core_color, first.torch_edge_color]
	var boss_encounter: EncounterController = level.encounters[level.encounters.size() - 1]
	var start_room := _room_at(authored_rooms, level.player_start.position)
	var authored_hall := _room_at(authored_rooms, boss_encounter.position)
	var fights: Array[Dictionary] = []
	for encounter in level.encounters.slice(0, level.encounters.size() - 1):
		fights.append({"name": String(encounter.name), "title": encounter.title,
				"subtitle": encounter.subtitle, "color": encounter.title_color})
	_lay_out(start_room, authored_hall, boss_encounter, fights)
	var hall := chain[chain.size() - 1]
	var hall_offset := hall.centre - Vector2(authored_hall.position.x, authored_hall.position.z)
	_sift_dressing(level, start_room, authored_hall, hall_offset)
	for container in ["Rooms", "Gates"]:
		_free_children(navigation.get_node(container))
	_free_children(level.get_node("CombatRooms"))
	for encounter in level.get_node("Encounters").get_children():
		if encounter != boss_encounter:
			encounter.free()
	boss_encounter.position += Vector3(hall_offset.x, 0.0, hall_offset.y)
	_build(level, navigation, boss_encounter)


## The authored room whose floor holds `at`.
func _room_at(rooms: Array[CryptRoom], at: Vector3) -> CryptRoom:
	for room in rooms:
		var half := Vector2(room.size) * 0.5
		if absf(at.x - room.position.x) <= half.x and absf(at.z - room.position.z) <= half.y:
			return room
	return rooms[0]


#region Layout

func _lay_out(start_room: CryptRoom, hall: CryptRoom, boss: EncounterController, story: Array[Dictionary]) -> void:
	var fights := story.duplicate()
	var extra := rng.randi_range(0, 1) + int(difficulty.tier >= 4)
	for i in extra:
		var at := rng.randi_range(0, fights.size())
		fights.insert(at, {"name": "Fight%d" % (i + 1), "title": "", "subtitle": "", "color": Color("#E8D9C0")})
	var start := Piece.new(String(start_room.name), start_room.size,
			Vector2(start_room.position.x, start_room.position.z), "start")
	chain.append(start)
	var heading := Vector2.ZERO
	for i in fights.size() + 1:
		var boss_hall := i == fights.size()
		var piece: Piece
		if boss_hall:
			piece = Piece.new(String(boss.name), hall.size, Vector2.ZERO, "boss")
			piece.sides[SOUTH] = CryptRoom.Edge.GAP
		else:
			var size := Vector2i(_pick(FIGHT_SIDES), _pick(FIGHT_SIDES))
			piece = Piece.new(fights[i].name, size, Vector2.ZERO, "fight")
			piece.set_meta(&"fight", fights[i])
		piece.depth = i
		var directions: Array[Vector2] = [NORTH]
		if not boss_hall:
			directions = _headings(heading)
		_attach(chain[chain.size() - 1], piece, directions)
		heading = -piece.entry
		chain.append(piece)
	var vault_count := rng.randi_range(1, 2)
	var parents := chain.slice(1, chain.size() - 1)
	_shuffle(parents)
	for parent: Piece in parents:
		if vaults.size() >= vault_count:
			break
		var vault := Piece.new("Vault%d" % (vaults.size() + 1),
				Vector2i(_pick(VAULT_SIDES), _pick(VAULT_SIDES)), Vector2.ZERO, "vault")
		vault.depth = parent.depth
		var free: Array[Vector2] = []
		for direction in [NORTH, EAST, WEST, SOUTH]:
			if not parent.sides.has(direction):
				free.append(direction)
		_shuffle(free)
		if _try_attach(parent, vault, free):
			vaults.append(vault)


## North, east or west in a random order, never straight back; after a step
## north, a turn comes first, so the way winds.
func _headings(previous: Vector2) -> Array[Vector2]:
	var options: Array[Vector2] = [NORTH, EAST, WEST]
	_shuffle(options)
	if previous == NORTH:
		options.erase(NORTH)
		options.append(NORTH)
	var result: Array[Vector2] = []
	for direction in options:
		if direction != -previous:
			result.append(direction)
	return result


## Joins `piece` to `from` in the first of `directions` with room for it;
## failing that, straight north as far as it takes (always free in the end).
func _attach(from: Piece, piece: Piece, directions: Array[Vector2]) -> void:
	if _try_attach(from, piece, directions):
		return
	var length := CORRIDOR_LENGTHS[0]
	while not _fits(from, piece, NORTH, length):
		length += 4
	_link(from, piece, NORTH, length)


func _try_attach(from: Piece, piece: Piece, directions: Array[Vector2]) -> bool:
	for direction in directions:
		if from.sides.has(direction):
			continue
		var lengths := CORRIDOR_LENGTHS.duplicate()
		_shuffle(lengths)
		for length: int in lengths:
			if _fits(from, piece, direction, length):
				_link(from, piece, direction, length)
				return true
	return false


## Places `piece` beyond `from`'s side `direction`, `length` metres of
## corridor away, if neither it nor its corridor overlaps anything laid out.
func _fits(from: Piece, piece: Piece, direction: Vector2, length: int) -> bool:
	piece.centre = from.centre + direction * (from.half_along(direction) + length + piece.half_along(direction))
	var corridor := _corridor_between(from, direction, length)
	for other in chain + vaults + corridors:
		if other == piece:
			continue
		if piece.rect(CLEARANCE).intersects(other.rect(CLEARANCE)):
			return false
		if other != from and corridor.rect(1.0).intersects(other.rect(CLEARANCE)):
			return false
	return true


func _corridor_between(from: Piece, direction: Vector2, length: int) -> Piece:
	var centre := from.centre + direction * (from.half_along(direction) + length * 0.5)
	var size := Vector2i(length, 4) if direction.x != 0.0 else Vector2i(4, length)
	return Piece.new("Corridor", size, centre, "corridor")


func _link(from: Piece, piece: Piece, direction: Vector2, length: int) -> void:
	var corridor := _corridor_between(from, direction, length)
	corridor.name = "Corridor%d" % (corridors.size() + 1)
	corridors.append(corridor)
	from.sides[direction] = CryptRoom.Edge.GAP
	piece.sides[-direction] = CryptRoom.Edge.GAP
	piece.entry = -direction
	var link := Link.new()
	link.from = from
	link.to = piece
	link.direction = direction
	link.corridor = corridor
	_links.append(link)

#endregion

#region Building

func _build(level: Level, navigation: Node3D, boss_encounter: EncounterController) -> void:
	var rooms := navigation.get_node("Rooms")
	for piece in chain + vaults:
		rooms.add_child(_room(piece))
	for corridor in corridors:
		rooms.add_child(_room(corridor))
	var gates := navigation.get_node("Gates")
	for link in _links:
		link.gate = GateScene.instantiate() as CryptGate
		link.gate.name = link.to.name if link.to.kind == "vault" else link.from.name
		var at := link.from.centre + link.direction * (link.from.half_along(link.direction) + 0.5)
		link.gate.position = Vector3(at.x, 0.0, at.y)
		if link.direction.x != 0.0:
			link.gate.rotation.y = PI * 0.5
		link.gate.open = link.from.kind == "start"
		gates.add_child(link.gate)
	var props := navigation.get_node_or_null("Props")
	if props == null:
		props = Node3D.new()
		props.name = "Props"
		navigation.add_child(props)
	var encounters := level.get_node("Encounters")
	var combat_rooms := level.get_node("CombatRooms")
	var required: Array[EncounterController] = []
	var optional: Array[EncounterController] = []
	for piece in chain.slice(1) + vaults:
		var encounter: EncounterController
		if piece.kind == "boss":
			encounter = boss_encounter
			encounter.depth = piece.depth
		else:
			_taken.clear()
			_dress(props, piece)
			encounter = _encounter(piece)
			encounters.add_child(encounter)
		combat_rooms.add_child(_combat_room(piece, encounter))
		(optional if piece.kind == "vault" else required).append(encounter)
	level.encounters = required
	level.optional_encounters = optional


func _room(piece: Piece) -> CryptRoom:
	var room := CryptRoom.new()
	room.name = piece.name
	room.position = Vector3(piece.centre.x, 0.0, piece.centre.y)
	room.size = piece.size
	if piece.kind == "corridor":
		var across := piece.size.x > piece.size.y
		room.west = CryptRoom.Edge.NONE if across else CryptRoom.Edge.WALL
		room.east = room.west
		room.north = CryptRoom.Edge.WALL if across else CryptRoom.Edge.NONE
		room.south = room.north
	else:
		room.north = piece.sides.get(NORTH, CryptRoom.Edge.WALL)
		room.south = piece.sides.get(SOUTH, CryptRoom.Edge.WALL)
		room.west = piece.sides.get(WEST, CryptRoom.Edge.WALL)
		room.east = piece.sides.get(EAST, CryptRoom.Edge.WALL)
	room.seed = rng.randi_range(1, 9999)
	room.torch_light_color = _torch_colors[0]
	room.torch_core_color = _torch_colors[1]
	room.torch_edge_color = _torch_colors[2]
	return room


## The gate a room is sealed behind (where the hero came in) and the gates it
## opens when cleared (on to the next room, and into its vaults).
func _combat_room(piece: Piece, encounter: EncounterController) -> CombatRoom:
	var area := CombatRoom.new()
	area.name = piece.name
	area.encounter = encounter
	for link in _links:
		if link.to == piece:
			area.seal_gates.append(link.gate)
		elif link.from == piece:
			area.exit_gates.append(link.gate)
	# Covers the room from 2 m past its doorway, so the door never shuts on
	# the hero.
	var shape := BoxShape3D.new()
	shape.size = Vector3(piece.size.x - 2.0 * absf(piece.entry.x), 3.0, piece.size.y - 2.0 * absf(piece.entry.y))
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	area.position = Vector3(piece.centre.x - piece.entry.x, 1.5, piece.centre.y - piece.entry.y)
	return area


func _encounter(piece: Piece) -> EncounterController:
	var encounter := EncounterController.new()
	encounter.name = piece.name
	encounter.position = Vector3(piece.centre.x, 0.0, piece.centre.y)
	encounter.depth = piece.depth
	if piece.kind == "vault":
		encounter.title = VAULT_TITLE
		encounter.subtitle = VAULT_SUBTITLE
		encounter.title_color = Color("#D9A44C")
		encounter.champion_chance_bonus = VAULT_CHAMPION_BONUS
	else:
		var fight: Dictionary = piece.get_meta(&"fight")
		encounter.title = fight.title
		encounter.subtitle = fight.subtitle
		encounter.title_color = fight.color
	var spawns := _spawn_points(piece)
	for i in spawns.size():
		var marker := Marker3D.new()
		marker.name = "Spawn%d" % (i + 1)
		marker.position = Vector3(spawns[i].x, 0.0, spawns[i].y)
		encounter.add_child(marker)
	encounter.data = _waves(piece, spawns.size())
	return encounter


## Spawn points in `piece`, in its own space: a grid clear of the walls, the
## props and the doorway the hero comes in by, shuffled.
func _spawn_points(piece: Piece) -> Array[Vector2]:
	var half := Vector2(piece.size) * 0.5 - Vector2.ONE * 2.5
	var door := piece.entry * piece.half_along(piece.entry)
	var points: Array[Vector2] = []
	var x := -half.x
	while x <= half.x + 0.01:
		var z := -half.y
		while z <= half.y + 0.01:
			var at := Vector2(x, z)
			if at.distance_to(door) >= SPAWN_DOOR_CLEARANCE and _is_clear(piece.centre + at, 1.2):
				points.append(at)
			z += SPAWN_STEP
		x += SPAWN_STEP
	if points.is_empty():
		points.append(Vector2.ZERO)
	_shuffle(points)
	return points.slice(0, MAX_WAVE + 3)


## The waves of a fight in `piece`, using up to `markers` spawn points each.
func _waves(piece: Piece, markers: int) -> EncounterData:
	var data := EncounterData.new()
	var vault := piece.kind == "vault"
	var count := 2 if vault or piece.depth <= 1 else rng.randi_range(2, 3)
	var area := piece.size.x * piece.size.y
	var per_wave := clampi(roundi(area / 190.0) + 1, 3, 5) + difficulty.extra_enemies()
	if vault:
		per_wave = 3 + difficulty.extra_enemies()
	elif piece.depth >= 3:
		per_wave += 1
	per_wave = clampi(mini(per_wave, MAX_WAVE), 1, markers)
	for w in count:
		var wave := WaveData.new()
		var last := w == count - 1
		var elites := 0
		if last and (piece.depth >= 2 or vault):
			elites = 1 + int(difficulty.tier >= 5)
		var names := _shuffled_markers(markers)
		for i in per_wave:
			var kind: String
			if i < elites:
				kind = _recipe.elite
			elif rng.randf() < 0.25:
				kind = _recipe.ranged
			else:
				kind = _pick(_recipe.basic)
			wave.enemies.append(_scene(ENEMIES[kind]))
			wave.markers.append(names[i])
		data.waves.append(wave)
	return data


func _shuffled_markers(count: int) -> PackedStringArray:
	var names: Array[String] = []
	for i in count:
		names.append("Spawn%d" % (i + 1))
	_shuffle(names)
	return PackedStringArray(names)


## Props along the walls (tall ones by the far walls, short ones by the near
## ones, none in a doorway), sometimes pillars or a centrepiece, and two
## braziers in the far corners.
func _dress(props: Node, piece: Piece) -> void:
	var half := Vector2(piece.size) * 0.5
	var far_slots: Array[Vector2] = []
	var near_slots: Array[Vector2] = []
	var x := -half.x + 2.0
	while x <= half.x - 2.0:
		far_slots.append(Vector2(x, -half.y + 1.6))
		near_slots.append(Vector2(x, half.y - 1.6))
		x += 4.0
	var z := -half.y + 4.0
	while z <= half.y - 2.0:
		far_slots.append(Vector2(-half.x + 1.6, z))
		near_slots.append(Vector2(half.x - 1.6, z))
		z += 4.0
	var doors: Array[Vector2] = []
	for direction: Vector2 in piece.sides:
		doors.append(direction * piece.half_along(direction))
	var place := func(slots: Array[Vector2], kinds: Array, count: int) -> void:
		_shuffle(slots)
		var placed := 0
		for slot in slots:
			if placed >= count:
				break
			if doors.any(func(door: Vector2) -> bool: return door.distance_to(slot) < 4.0):
				continue
			if _add_prop(props, piece, _pick(kinds), slot):
				placed += 1
	place.call(far_slots, _recipe.far, rng.randi_range(3, 5))
	place.call(near_slots, _recipe.near, rng.randi_range(2, 4))
	if piece.kind != "vault" and mini(piece.size.x, piece.size.y) >= 20:
		match rng.randi_range(0, 2):
			1:
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						_add_prop(props, piece, _recipe.pillar, Vector2(sx * half.x * 0.45, sz * half.y * 0.45))
			2:
				_add_prop(props, piece, _pick(_recipe.centre), Vector2.ZERO)
	for corner in [Vector2(-half.x + 2.0, -half.y + 2.0), Vector2(half.x - 2.0, -half.y + 2.0)]:
		var fire := FlameFx.new()
		fire.name = "%sFire%d" % [piece.name, props.get_child_count()]
		fire.size = 0.6
		fire.core_color = _torch_colors[1]
		fire.edge_color = _torch_colors[2]
		fire.ember_count = 8
		fire.position = Vector3(piece.centre.x + corner.x, 2.2, piece.centre.y + corner.y)
		props.add_child(fire)


## A prop of `kind` at `at` in `piece`'s space, unless it would crowd another.
func _add_prop(props: Node, piece: Piece, kind: String, at: Vector2) -> bool:
	var info: Array = PROPS[kind]
	var radius: float = info[2]
	var world := piece.centre + at
	if not _is_clear(world, maxf(radius, 0.4)):
		return false
	_taken.append(Vector3(world.x, world.y, maxf(radius, 0.4)))
	var model := _scene(info[0]).instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * float(info[1])
	model.rotation.y = rng.randi_range(0, 3) * PI * 0.5
	var node: Node3D = model
	if radius > 0.0:
		var body := StaticBody3D.new()
		var shape := CylinderShape3D.new()
		shape.height = 3.0
		shape.radius = radius
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = 1.5
		body.add_child(collision)
		body.add_child(model)
		node = body
	node.name = "%sProp%d" % [piece.name, props.get_child_count() + 1]
	node.position = Vector3(world.x, 0.0, world.y)
	props.add_child(node)
	return true


func _is_clear(at: Vector2, radius: float) -> bool:
	for taken in _taken:
		if at.distance_to(Vector2(taken.x, taken.y)) < taken.z + radius + 0.6:
			return false
	return true


## Keeps the authored dressing of the start room where it is and moves the
## boss hall's with the hall; everything else of the authored layout goes.
func _sift_dressing(level: Level, start: CryptRoom, hall: CryptRoom, hall_offset: Vector2) -> void:
	var start_rect := _floor_of(start).grow(1.5)
	var hall_rect := _floor_of(hall).grow(1.5)
	var items: Array[Node3D] = []
	var navigation := level.get_node("Navigation")
	for container in [level, navigation]:
		for child in container.get_children():
			if child is Node3D and not FRAME.has(String(child.name)) and not ["Rooms", "Gates"].has(String(child.name)):
				if _is_group(child):
					for item in child.get_children():
						if item is Node3D:
							items.append(item)
				else:
					items.append(child)
	for item in items:
		var at := Vector2(item.position.x, item.position.z)
		if start_rect.has_point(at):
			continue
		if hall_rect.has_point(at):
			item.position += Vector3(hall_offset.x, 0.0, hall_offset.y)
			continue
		item.free()


func _floor_of(room: CryptRoom) -> Rect2:
	var half := Vector2(room.size) * 0.5
	return Rect2(Vector2(room.position.x, room.position.z) - half, half * 2.0)


## A plain folder node (Props, Fires, Banners), as opposed to a prop itself.
func _is_group(node: Node) -> bool:
	return node.get_class() == "Node3D" and node.get_script() == null and node.scene_file_path == "" \
			and node.get_child_count() > 0


func _free_children(node: Node) -> void:
	for child in node.get_children():
		child.free()

#endregion

func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


func _pick(options: Array) -> Variant:
	return options[rng.randi_range(0, options.size() - 1)]


## Shuffles `items` in place with this generator's seed (Array.shuffle uses
## the global one).
func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
