extends "res://tests/framework/test_case.gd"
## Tests for the Dark Cultist: its telegraphed shadow bolt, the projectile,
## and keeping its distance.

const CultistScene := preload("res://scenes/enemies/dark_cultist.tscn")
const BoltScene := preload("res://scenes/combat/shadow_bolt.tscn")
const WardenScene := preload("res://scenes/player/warden.tscn")

var player: PlayerController


## A 60 m floor with `walls` (baked into its navigation mesh) and the player
## at the origin.
func _setup(walls: Array[AABB] = []) -> void:
	var region := add_level(60.0, walls)
	player = WardenScene.instantiate()
	add_child(player)
	await wait_for_navigation(region)


func _cultist_at(position: Vector3) -> EnemyController:
	var cultist: EnemyController = CultistScene.instantiate()
	cultist.position = position
	add_child(cultist)
	return cultist


func _bolts() -> Array[Projectile]:
	var found: Array[Projectile] = []
	for child in get_children():
		if child is Projectile:
			found.append(child)
	return found


func _distance(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


func test_the_bolt_is_telegraphed_then_flies_and_hits() -> void:
	await _setup()
	var cultist := _cultist_at(Vector3(0, 0, -8))
	var telegraph: AttackTelegraph = cultist.get_node("Visual/Telegraph")
	check(await wait_until(func() -> bool: return cultist.state == EnemyController.State.TELEGRAPH, 30),
			"a cultist 8 m away starts casting without walking closer")
	check(telegraph.visible, "the line telegraph shows during the windup")
	check_near(telegraph.mesh.get_aabb().size.z, 12.0, 0.01, "the line shows the bolt's full range")
	check(_bolts().is_empty(), "nothing flies during the windup")
	check(await wait_until(func() -> bool: return not _bolts().is_empty(), 50), "the bolt is released after the windup")
	check(not telegraph.visible, "the telegraph goes with the release")
	var bolt := _bolts()[0]
	var start := bolt.global_position
	await wait_physics_frames(15)
	if is_instance_valid(bolt):
		check_near(start.distance_to(bolt.global_position), 2.5, 0.2, "the bolt flies at 10 m/s")
	check(await wait_until(func() -> bool: return player.health.current < player.health.max_health, 60),
			"the bolt hits the player")
	check(player.health.current == player.health.max_health - 10, "for 10 damage: %d" % player.health.current)
	await wait_physics_frames(2)
	check(_bolts().is_empty(), "the bolt is spent on the hit")


func test_a_dodging_player_takes_nothing() -> void:
	await _setup()
	var cultist := _cultist_at(Vector3(0, 0, -8))
	check(await wait_until(func() -> bool: return not _bolts().is_empty(), 90), "a bolt is released")
	player.health.invulnerable = true
	check(await wait_until(func() -> bool: return _bolts().is_empty(), 60), "the bolt reaches the player")
	player.health.invulnerable = false
	check(player.health.current == player.health.max_health, "no damage through the invulnerable window")
	cultist.free()


func test_walls_stop_bolts_and_bolts_stop_at_their_range() -> void:
	await _setup([AABB(Vector3(-3, 0, -3.5), Vector3(6, 3, 1))])
	player.position = Vector3(0, 0, -6)
	var bolt: Projectile = BoltScene.instantiate()
	bolt.position = Vector3(0, 1.1, 0)
	bolt.direction = Vector3.FORWARD
	var hits: Array[Object] = []
	bolt.impacted.connect(func(collider: Object) -> void: hits.append(collider))
	add_child(bolt)
	await wait_physics_frames(30)
	check(hits.size() == 1 and hits[0] is StaticBody3D, "the wall stops the bolt")
	check(player.health.current == player.health.max_health, "the player behind the wall is safe")
	var stray: Projectile = BoltScene.instantiate()
	stray.position = Vector3(0, 1.1, 0)
	stray.direction = Vector3.BACK
	stray.max_distance = 5.0
	add_child(stray)
	await wait_physics_frames(25)
	check(is_instance_valid(stray), "still flying before its range")
	await wait_physics_frames(10)
	check(not is_instance_valid(stray), "gone once it has flown its range")


func test_backs_away_from_a_close_player_and_attacks_when_cornered() -> void:
	await _setup([AABB(Vector3(-5, 0, 10.4), Vector3(10, 3, 1))])
	var cultist := _cultist_at(Vector3(0, 0, -3))
	await wait_physics_frames(45)
	check(_distance(cultist, player) > 4.0, "backs away, now %.2f m" % _distance(cultist, player))
	check(not cultist.is_attacking() or _distance(cultist, player) >= 5.0, "does not cast point-blank")
	cultist.free()
	# The wall runs along z = 10.4 to 11.4, right behind this one.
	player.position = Vector3(0, 0, 7)
	var cornered := _cultist_at(Vector3(0, 0, 10))
	check(await wait_until(func() -> bool: return cornered.is_attacking(), 90),
			"with its back to a wall it casts anyway")
	check(_distance(cornered, player) < 5.0, "still close, at %.2f m" % _distance(cornered, player))


func test_closes_in_until_it_can_see_the_player() -> void:
	await _setup([AABB(Vector3(-2, 0, 3.5), Vector3(4, 3, 1))])
	var far := _cultist_at(Vector3(0, 0, -11.5))
	check(await wait_until(func() -> bool: return far.is_attacking(), 240), "a distant cultist walks into range and casts")
	check(_distance(far, player) <= 9.1, "casting from within 9 m, at %.2f m" % _distance(far, player))
	far.free()
	# The wall runs along z = 3.5 to 4.5, between the two.
	var blocked := _cultist_at(Vector3(0, 0, 7))
	await wait_physics_frames(20)
	check(not blocked.is_attacking(), "no cast through a wall")
	check(await wait_until(func() -> bool: return blocked.is_attacking(), 300), "walks around the wall and casts")
	var query := PhysicsRayQueryParameters3D.create(blocked.global_position + Vector3.UP, player.global_position + Vector3.UP, 1)
	check(get_viewport().world_3d.direct_space_state.intersect_ray(query).is_empty(), "with a clear line to the player")
