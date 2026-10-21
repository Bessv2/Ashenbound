extends "res://tests/framework/test_case.gd"
## Tests for the player's dodge: the dash, its cooldown and input buffer, its
## invulnerable window against a real Hollow, and the HUD button.

const PlayerScene := preload("res://scenes/player/warden.tscn")
const HollowScene := preload("res://scenes/enemies/hollow.tscn")
## A wall west of the start: its east face is at x = -2.
const WALL := AABB(Vector3(-3.0, 0.0, -3.0), Vector3(1.0, 3.0, 6.0))
## Where the player stands with its back to the wall.
const AGAINST_WALL := Vector3(-1.6, 0.0, 0.0)

var player: PlayerController
var dodge: Dodge
var starts: Array[Vector3] = []


func _ready() -> void:
	add_level(40.0, [WALL])
	player = PlayerScene.instantiate()
	add_child(player)
	dodge = player.dodge
	dodge.started.connect(func(_direction: Vector3) -> void: starts.append(player.global_position))


func _tap_dodge() -> void:
	Input.action_press(GameplayActions.DODGE)
	Input.action_release(GameplayActions.DODGE)


func _place_player(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	await wait_physics_frames(2)


func _dashing() -> bool:
	return dodge.is_active()


func _not_dashing() -> bool:
	return not dodge.is_active()


func _ready_to_dodge() -> bool:
	return dodge.is_ready()


## Dodges with whatever input is held and returns how far the dash itself
## carried the player, measured from the tick it started to the tick it ended.
func _dash_displacement() -> Vector3:
	var before := starts.size()
	_tap_dodge()
	check(await wait_until(func() -> bool: return starts.size() > before, 5), "dodge started")
	check(await wait_until(_not_dashing, 120), "dodge finished")
	var offset := player.global_position - starts[-1]
	return Vector3(offset.x, 0.0, offset.z)


func test_dashes_its_distance_toward_the_movement_input() -> void:
	await _place_player(Vector3.ZERO)
	Input.action_press(MovementInput.RIGHT)
	var moved := await _dash_displacement()
	Input.action_release(MovementInput.RIGHT)
	check_vector_near(moved, Vector3(dodge.data.distance, 0, 0), 0.02, "dash covers its distance to the right")


func test_without_input_dashes_toward_the_facing() -> void:
	await _place_player(Vector3.ZERO)
	var moved := await _dash_displacement()
	check_vector_near(moved, Vector3(0, 0, -dodge.data.distance), 0.02, "dash covers its distance forward")


func test_dash_and_landing_are_frame_rate_independent() -> void:
	var dashes: Array[float] = []
	var landings: Array[float] = []
	for ticks: int in [30, 60, 120]:
		Engine.physics_ticks_per_second = ticks
		await _place_player(Vector3.ZERO)
		await wait_until(_ready_to_dodge, ticks * 2)
		dashes.append((await _dash_displacement()).length())
		await wait_physics_frames(ticks)  # The exit slide stops well within a second.
		landings.append(Vector3(player.global_position.x, 0, player.global_position.z).length())
	Engine.physics_ticks_per_second = 60
	# The dash itself is exact. The slide after it is ordinary deceleration,
	# which updates speed before moving each tick and so stops about half a
	# tick of speed short: 6 m/s × (1/30 − 1/60) s / 2 = 5 cm between 30 Hz
	# and 60 Hz. That is plain movement's behavior, not the dodge's.
	var slide_tolerance := player.stats.move_speed * (1.0 / 30.0 - 1.0 / 60.0) * 0.5 + 0.01
	for i in dashes.size():
		check_near(dashes[i], dodge.data.distance, 0.02, "dash distance at every tick rate %s" % [dashes])
		check_near(landings[i], landings[1], slide_tolerance, "resting point at every tick rate %s" % [landings])
	check(landings[1] < dodge.data.distance + 0.3, "the exit slide is short: rests %.2f m away" % landings[1])


func test_dash_distance_is_exact_for_any_tick_length() -> void:
	# 0.31 s is not a whole number of ticks at any of these rates, so the last
	# tick of each dash is a partial one.
	var data := DodgeData.new()
	data.duration = 0.31
	data.distance = 4.0
	for ticks: int in [24, 30, 60, 90, 120, 144]:
		var dash := Dodge.new()
		dash.data = data
		add_child(dash)
		dash.try_start(Vector3.RIGHT)
		var travelled := Vector3.ZERO
		var steps := 0
		while dash.is_active() and steps < 1000:
			travelled += dash.step(1.0 / ticks) / ticks
			steps += 1
		check_vector_near(travelled, Vector3(4.0, 0, 0), 0.0001, "exact distance at %d Hz" % ticks)
		check(steps == ceili(0.31 * ticks), "%d ticks at %d Hz" % [steps, ticks])
		dash.free()


func test_cooldown_blocks_a_second_dodge_until_ready() -> void:
	await _place_player(Vector3.ZERO)
	await _dash_displacement()
	_tap_dodge()  # 0.3 s in: too early even for the input buffer.
	await wait_physics_frames(20)
	check(starts.size() == 1, "no second dodge during the cooldown")
	check(dodge.cooldown_fraction() > 0.0, "cooldown still running")
	check(await wait_until(_ready_to_dodge, 60), "the cooldown ends")
	_tap_dodge()
	await wait_physics_frames(2)
	check(starts.size() == 2, "dodges again once ready")


func test_a_press_just_before_ready_is_buffered() -> void:
	await _place_player(Vector3.ZERO)
	_tap_dodge()
	await wait_until(_dashing, 5)
	# Press 0.1 s before the cooldown ends, inside the 0.2 s buffer.
	await wait_until(func() -> bool: return dodge.cooldown_fraction() * dodge.data.cooldown <= 0.1, 120)
	_tap_dodge()
	check(await wait_until(func() -> bool: return starts.size() == 2, 12), "the early press dodges as soon as it can")


func _hollow_beside_player() -> EnemyController:
	await _place_player(AGAINST_WALL)
	var hollow: EnemyController = HollowScene.instantiate()
	hollow.position = AGAINST_WALL + Vector3(1.3, 0, 0)
	add_child(hollow)
	check(await wait_until(func() -> bool: return hollow.attack.is_busy(), 10), "the Hollow winds up")
	return hollow


func test_a_hit_inside_the_invulnerable_window_does_nothing() -> void:
	var hollow := await _hollow_beside_player()
	# The hit lands 0.5 s into the windup; dodging at 0.3 s puts it 0.2 s into
	# the dodge, inside the 0.25 s window. Dodging into the wall keeps the
	# player in reach.
	await wait_physics_frames(17)
	Input.action_press(MovementInput.LEFT)
	_tap_dodge()
	var hits: Array = []
	hollow.attack.struck.connect(func(targets: Array[Health]) -> void: hits.append(targets.size()))
	await wait_until(func() -> bool: return not hits.is_empty(), 30)
	Input.action_release(MovementInput.LEFT)
	check(hits == [0], "the hit resolved and found nobody to damage: %s" % [hits])
	check(player.health.current == player.health.max_health, "no damage, health %d" % player.health.current)
	check(player.global_position.distance_to(hollow.global_position) < hollow.attack.data.reach,
			"the player was in reach the whole time")


func test_a_hit_after_the_invulnerable_window_lands() -> void:
	var hollow := await _hollow_beside_player()
	# Dodging right away: the window has closed by the time the hit lands.
	Input.action_press(MovementInput.LEFT)
	_tap_dodge()
	await wait_until(func() -> bool: return not hollow.attack.is_busy() or player.health.current < 100, 40)
	Input.action_release(MovementInput.LEFT)
	check(player.health.current == player.health.max_health - hollow.attack.data.damage,
			"the hit lands after the window, health %d" % player.health.current)


func test_dodging_cancels_the_attack_and_holds_it_off() -> void:
	await _place_player(Vector3.ZERO)
	var attack := player.attack
	var attacks := [0, 0]
	attack.started.connect(func(_direction: Vector3) -> void: attacks[0] += 1)
	attack.canceled.connect(func() -> void: attacks[1] += 1)
	Input.action_press(GameplayActions.ATTACK)
	await wait_until(func() -> bool: return attack.is_busy(), 5)
	_tap_dodge()
	await wait_until(_dashing, 5)
	check(attacks[1] == 1 and not attack.is_busy(), "the attack in its windup was canceled")
	await wait_until(_not_dashing, 30)
	check(attacks[0] == 1, "no attack starts during the dash despite the held button")
	await wait_physics_frames(2)
	Input.action_release(GameplayActions.ATTACK)
	check(attacks[0] == 2, "attacking resumes after the dash")


func test_a_dead_player_cannot_dodge() -> void:
	await _place_player(Vector3.ZERO)
	player.health.apply_damage(player.health.max_health)
	_tap_dodge()
	await wait_physics_frames(5)
	check(starts.is_empty(), "no dodge after death")


func test_dying_mid_dash_ends_it() -> void:
	await _place_player(Vector3.ZERO)
	_tap_dodge()
	await wait_until(func() -> bool: return dodge.is_active() and not player.health.invulnerable, 30)
	check(dodge.is_active(), "past the invulnerable window, still dashing")
	player.health.apply_damage(player.health.max_health)
	check(not dodge.is_active(), "death ends the dash")
	check(not player.health.invulnerable, "and leaves the body vulnerable")


func test_pause_freezes_the_dash() -> void:
	await _place_player(Vector3.ZERO)
	_tap_dodge()
	await wait_until(_dashing, 5)
	await wait_physics_frames(3)
	get_tree().paused = true
	var at := player.global_position
	await wait_physics_frames(30)
	check_vector_near(player.global_position, at, 0.0001, "no movement while paused")
	check(dodge.is_active(), "still dashing when paused")
	get_tree().paused = false
	await wait_until(_not_dashing, 30)
	check_near(Vector3(player.global_position.x, 0, player.global_position.z).length(),
			dodge.data.distance, 0.02, "the dash completes its distance after resuming")


func test_walls_stop_the_dash() -> void:
	await _place_player(Vector3.ZERO)
	Input.action_press(MovementInput.LEFT)
	await _dash_displacement()
	Input.action_release(MovementInput.LEFT)
	await wait_physics_frames(30)
	check(player.global_position.x > WALL.end.x - 0.01, "the dash stops at the wall, x = %.2f" % player.global_position.x)


func test_hud_button_dodges_and_shows_the_cooldown() -> void:
	player.free()
	var main := instantiate_main()
	add_child(main)
	player = main.get_node("Player")
	dodge = player.dodge
	var button: TouchActionButton = main.get_node("HUD").get_node("%DodgeButton")
	await wait_physics_frames(2)
	check(button.cooldown_fraction() == 0.0, "no cooldown shown before dodging")
	var touch := InputEventScreenTouch.new()
	touch.position = button.get_global_rect().get_center()
	touch.pressed = true
	get_viewport().push_input(touch)
	touch = touch.duplicate()
	touch.pressed = false
	get_viewport().push_input(touch)
	check(await wait_until(_dashing, 5), "tapping the button dodges")
	check(button.cooldown_fraction() > 0.9, "the button shows the full cooldown, %.2f" % button.cooldown_fraction())
	check(await wait_until(func() -> bool: return button.cooldown_fraction() == 0.0, 70), "and empties it when ready")
