extends "res://tests/framework/test_case.gd"
## Tests for the Fallen Knight elite: its attack pattern, the shield bash's
## push, the frontal guard and the elite bar.

const KnightScene := preload("res://scenes/enemies/fallen_knight.tscn")
const WardenScene := preload("res://scenes/player/warden.tscn")

var player: PlayerController


func _ready() -> void:
	add_level(60.0)
	player = WardenScene.instantiate()
	add_child(player)


func _knight_at(position: Vector3) -> EnemyController:
	var knight: EnemyController = KnightScene.instantiate()
	knight.position = position
	add_child(knight)
	return knight


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_every_third_attack_is_a_shield_bash() -> void:
	player.health.invulnerable = true
	var knight := _knight_at(Vector3(0, 0, -1.6))
	var used: Array[String] = []
	knight.state_changed.connect(func(_from: EnemyController.State, to: EnemyController.State) -> void:
		if to == EnemyController.State.TELEGRAPH:
			used.append(knight.current_attack.name))
	check(await wait_until(func() -> bool: return used.size() >= 6, 60 * 15), "six attacks: %s" % [used])
	check(used.slice(0, 6) == ["Cleave", "Cleave", "ShieldBash", "Cleave", "Cleave", "ShieldBash"],
			"cleave, cleave, bash, repeated: %s" % [used])


func test_the_cleave_hits_hard_and_the_bash_pushes_back() -> void:
	var knight := _knight_at(Vector3(0, 0, -1.6))
	check(await wait_until(func() -> bool: return player.health.current < 100, 120), "the first cleave lands")
	check(player.health.current == 100 - 26, "for 26: %d" % player.health.current)
	knight.attacks_started = 2  # The next attack is the third: a bash.
	await wait_until(func() -> bool: return not knight.is_attacking(), 120)
	player.health.revive()
	player.global_position = Vector3(0, 0, 0)
	var before := _flat_distance(player.global_position, knight.global_position)
	check(await wait_until(func() -> bool: return player.health.current < 100, 180), "the bash lands")
	check(player.health.current == 100 - 8, "for 8: %d" % player.health.current)
	check(player.is_being_pushed(), "and shoves the player")
	await wait_physics_frames(20)
	var after := _flat_distance(player.global_position, knight.global_position)
	check_near(after - before, 3.0, 0.4, "about 3 m back (from %.2f to %.2f)" % [before, after])


func test_a_push_covers_the_same_distance_at_any_tick_rate() -> void:
	for ticks: int in [30, 60, 120]:
		Engine.physics_ticks_per_second = ticks
		player.global_position = Vector3.ZERO
		player.velocity = Vector3.ZERO
		await wait_physics_frames(2)
		player.push(Vector3(3, 0, 0))
		await wait_physics_frames(ticks)
		check_near(player.global_position.x, 3.0, 0.05, "pushed 3 m at %d ticks" % ticks)
	Engine.physics_ticks_per_second = 60


func test_the_shield_halves_hits_from_the_front_while_it_is_not_swinging() -> void:
	var knight := _knight_at(Vector3(0, 0, -20))
	knight.set_physics_process(false)  # Stands still, facing -Z.
	await wait_physics_frames(2)
	var health := knight.health
	var front := knight.global_position + Vector3(0, 0, -2)
	var behind := knight.global_position + Vector3(0, 0, 2)
	var side := knight.global_position + Vector3(2, 0, 0)
	check(health.apply_damage(20, front) == 10, "a hit from the front deals half")
	check(health.apply_damage(20, behind) == 20, "a hit from behind deals all")
	check(health.apply_damage(20, side) == 20, "a hit from the side deals all")
	check(health.apply_damage(20) == 20, "a hit from nowhere (burning) deals all")
	knight.attack.try_start(Vector3.FORWARD)
	knight.state = EnemyController.State.TELEGRAPH
	check(health.apply_damage(20, front) == 20, "mid-swing the shield is down")


func test_the_warden_strikes_the_shield_for_half() -> void:
	var knight := _knight_at(Vector3(0, 0, -1.5))
	knight.set_physics_process(false)
	knight.visual.rotation.y = PI  # Facing the Warden, south of it.
	await wait_physics_frames(2)
	player.attack.try_start(Vector3.FORWARD)
	check(await wait_until(func() -> bool: return knight.health.current < 140, 30), "the basic attack lands")
	check(knight.health.current == 140 - 5, "half of 10 through the shield: %d" % knight.health.current)
	knight.visual.rotation.y = 0.0  # Back turned.
	await wait_until(func() -> bool: return not player.attack.is_busy(), 60)
	player.attack.try_start(Vector3.FORWARD)
	check(await wait_until(func() -> bool: return knight.health.current < 135, 30), "the second attack lands")
	check(knight.health.current == 135 - 10, "full damage in the back: %d" % knight.health.current)


func test_the_elite_bar_shows_its_name_and_health() -> void:
	var knight := _knight_at(Vector3(0, 0, -20))
	knight.set_physics_process(false)
	await wait_physics_frames(2)
	var bar: EliteBar = knight.get_node("EliteBar")
	check(bar.visible and bar.title == "FALLEN KNIGHT", "the bar is up with its name")
	check_near(bar.fraction(), 1.0, 0.001, "full at the start")
	knight.health.apply_damage(70)
	check_near(bar.fraction(), 0.5, 0.001, "half after 70 damage")
	knight.health.apply_damage(1000)
	check(not bar.visible, "gone when the knight dies")
