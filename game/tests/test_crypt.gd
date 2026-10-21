extends "res://tests/framework/test_case.gd"
## Tests for the Ashen Crypt: room building, gates, combat rooms that seal and
## heal, and a run through the whole dungeon.

const CryptScene := preload("res://scenes/dungeon/crypt.tscn")
const GateScene := preload("res://scenes/dungeon/crypt_gate.tscn")
const WardenScene := preload("res://scenes/player/warden.tscn")

var main: Node3D
var player: PlayerController
var level: Level


func _add_crypt() -> void:
	main = instantiate_main(false, CryptScene)
	add_child(main)
	player = main.get_node("Player")
	level = main.level


func _teleport(to: Vector3) -> void:
	player.global_position = to
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _gate(gate_name: String) -> CryptGate:
	return level.get_node("Navigation/Gates/" + gate_name)


func _encounter(room: String) -> EncounterController:
	return level.get_node("Encounters/" + room)


## Kills every living enemy of `encounter`'s waves until it is cleared.
func _clear(encounter: EncounterController) -> bool:
	return await wait_until(func() -> bool:
		for enemy in encounter.living_enemies():
			var health := Health.of(enemy)
			health.invulnerable = false
			health.apply_damage(health.max_health)
		return encounter.phase == EncounterController.Phase.CLEARED, 600)


## The end of a navigation path from `from` to `to` over the crypt's map, at
## floor height (the baked mesh floats a little above the floor).
func _path_end(from: Vector3, to: Vector3) -> Vector3:
	var map := (level.get_node("Navigation") as NavigationRegion3D).get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	var end := path[path.size() - 1] if not path.is_empty() else from
	return Vector3(end.x, 0.0, end.z)


## Whether any of `room`'s collision boxes covers the point (x, 1, z) in its space.
func _blocked(room: CryptRoom, x: float, z: float) -> bool:
	for box in room.collision_boxes:
		if box.has_point(Vector3(x, 0.5, z)):
			return true
	return false


func test_rooms_leave_gaps_only_where_asked() -> void:
	var walled := CryptRoom.new()
	walled.size = Vector2i(20, 12)
	add_child(walled)
	var gapped := CryptRoom.new()
	gapped.size = Vector2i(20, 12)
	gapped.north = CryptRoom.Edge.GAP
	gapped.south = CryptRoom.Edge.GAP
	add_child(gapped)
	var corridor := CryptRoom.new()
	corridor.size = Vector2i(4, 8)
	corridor.north = CryptRoom.Edge.NONE
	corridor.south = CryptRoom.Edge.NONE
	add_child(corridor)
	for z: float in [-6.5, 6.5]:
		check(_blocked(walled, 0.0, z), "a wall closes the middle of the side at z = %s" % z)
		check(not _blocked(gapped, 0.0, z) and not _blocked(gapped, 1.9, z), "a gap opens 4 m at z = %s" % z)
		check(_blocked(gapped, 2.1, z) and _blocked(gapped, 9.9, z), "the rest of the side stays walled at z = %s" % z)
		check(not _blocked(corridor, 0.0, z * 4.0 / 6.0 + 0.1), "corridor ends are open")
	for x: float in [-10.5, 10.5]:
		check(_blocked(walled, x, 0.0) and _blocked(gapped, x, 0.0), "west and east are always walled")
	check(_blocked(corridor, -2.5, 0.0) and _blocked(corridor, 2.5, 0.0), "corridor sides are walled")
	check(not _blocked(walled, 0.0, 0.0) and not _blocked(walled, 9.4, 5.4), "the floor space is free")


func test_a_closed_gate_blocks_the_way_and_an_open_one_does_not() -> void:
	add_level(30.0)
	var gate: CryptGate = GateScene.instantiate()
	gate.position = Vector3(0, 0, -3)
	add_child(gate)
	player = WardenScene.instantiate()
	add_child(player)
	await wait_physics_frames(5)
	# Without a camera, forward is north (-Z).
	var walk_north := func(frames: int) -> void:
		Input.action_press(MovementInput.FORWARD)
		await wait_physics_frames(frames)
		MovementInput.release_all()
	await walk_north.call(60)
	check(player.global_position.z > -3.0, "a closed door stops the player at z = %.2f" % player.global_position.z)
	var changes: Array[bool] = []
	gate.changed.connect(func(open: bool) -> void: changes.append(open))
	gate.open = true
	gate.open = true
	check(changes == [true], "opening emits once: %s" % [changes])
	_teleport(Vector3(0, 0, 0))
	await walk_north.call(90)
	check(player.global_position.z < -6.0, "an open door lets the player through, z = %.2f" % player.global_position.z)


func test_the_crypt_is_one_connected_dungeon_behind_its_gates() -> void:
	_add_crypt()
	var region: NavigationRegion3D = level.get_node("Navigation")
	check(await wait_for_navigation(region), "the crypt bakes its navigation mesh")
	var start := level.player_start.global_position
	check_vector_near(player.global_position, start, 0.01, "the player starts at the level's start")
	var ossuary := Vector3(0, 0, -24)
	var throne := Vector3(0, 0, -88)
	check(_path_end(start, ossuary).distance_to(ossuary) < 0.5, "the gatehouse leads to the ossuary")
	check(_path_end(start, throne).distance_to(throne) > 20.0, "a closed gate cuts the path to the throne")
	_gate("Ossuary").open = true
	_gate("Chapel").open = true
	check(await wait_until(func() -> bool: return _path_end(start, throne).distance_to(throne) < 0.5, 120),
			"with every gate open, a path runs from the gatehouse to the throne")
	_gate("Gatehouse").open = false
	check(await wait_until(func() -> bool: return _path_end(start, ossuary).distance_to(ossuary) > 5.0, 120),
			"closing a gate rebakes the navigation mesh")


func test_entering_a_combat_room_seals_it_and_clearing_it_opens_and_heals() -> void:
	_add_crypt()
	var encounter := _encounter("Ossuary")
	await wait_physics_frames(60)
	check(encounter.phase == EncounterController.Phase.WAITING and _gate("Gatehouse").open,
			"nothing happens until the player walks in")
	_teleport(Vector3(0, 0, -15))
	await wait_physics_frames(5)
	check(encounter.phase == EncounterController.Phase.WAITING, "the first 2 m past the doorway do not seal")
	_teleport(Vector3(0, 0, -20))
	check(await wait_until(func() -> bool: return encounter.phase == EncounterController.Phase.ACTIVE, 10),
			"walking in starts the encounter")
	check(not _gate("Gatehouse").open and not _gate("Ossuary").open, "both doors are shut")
	player.health.apply_damage(50)
	check(await _clear(encounter), "the encounter can be cleared")
	await wait_physics_frames(2)
	check(_gate("Gatehouse").open and _gate("Ossuary").open, "clearing opens both doors")
	check(player.health.current == player.health.max_health - 20, "clearing heals 30: %d" % player.health.current)
	_teleport(Vector3(0, 0, -10))
	await wait_physics_frames(5)
	_teleport(Vector3(0, 0, -20))
	await wait_physics_frames(60)
	check(encounter.phase == EncounterController.Phase.CLEARED and _gate("Gatehouse").open,
			"walking back in does nothing")


func test_healing_never_exceeds_max_health_and_skips_the_dead() -> void:
	var health := Health.new()
	health.max_health = 100
	add_child(health)
	var healed: Array[int] = []
	health.healed.connect(func(amount: int, _remaining: int) -> void: healed.append(amount))
	check(health.heal(30) == 0 and healed.is_empty(), "nothing to heal at full health")
	health.apply_damage(10)
	check(health.heal(30) == 10 and health.current == 100 and healed == [10], "heals up to the maximum")
	health.apply_damage(100)
	check(health.heal(30) == 0 and health.is_dead(), "the dead stay dead")


func test_a_run_through_the_crypt_ends_in_victory_at_the_throne() -> void:
	_add_crypt()
	var run: RunController = main.get_node("Run")
	var rooms := {"Ossuary": -20.0, "Chapel": -50.0, "Throne": -85.0}
	for room: String in rooms:
		check(not run.is_over(), "the run goes on before the %s" % room)
		_teleport(Vector3(0, 0, rooms[room]))
		var encounter := _encounter(room)
		check(await wait_until(func() -> bool: return encounter.phase == EncounterController.Phase.ACTIVE, 10),
				"the %s starts" % room)
		check(await _clear(encounter), "the %s is cleared" % room)
		await wait_physics_frames(2)
	check(run.result == RunController.Result.VICTORY, "clearing the throne wins the run")
	var death_screen: DeathScreen = main.get_node("DeathScreen")
	check(death_screen.visible, "the victory screen opens")
