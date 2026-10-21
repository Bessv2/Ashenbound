extends "res://tests/framework/test_case.gd"
## Tests for the Warden's starter abilities against the acceptance checks in
## docs/characters/warden.md: Cleave, Bulwark Guard and Ember Brand.

const WardenScene := preload("res://scenes/player/warden.tscn")
const DummyScene := preload("res://scenes/enemies/training_dummy.tscn")
const HollowScene := preload("res://scenes/enemies/hollow.tscn")

var warden: PlayerController
var cleave: CleaveAbility
var guard: GuardAbility
var brand: BrandAbility


func _ready() -> void:
	add_level(40.0)
	warden = WardenScene.instantiate()
	add_child(warden)
	cleave = warden.get_node("Cleave")
	guard = warden.get_node("Guard")
	brand = warden.get_node("Brand")


func _tap(action: StringName) -> void:
	Input.action_press(action)
	Input.action_release(action)


func _dummy(at: Vector3) -> TrainingDummy:
	var dummy: TrainingDummy = DummyScene.instantiate()
	dummy.position = at
	add_child(dummy)
	return dummy


func _hollow(at: Vector3) -> EnemyController:
	var hollow: EnemyController = HollowScene.instantiate()
	hollow.position = at
	add_child(hollow)
	return hollow


func _flat_position() -> Vector3:
	return Vector3(warden.global_position.x, 0.0, warden.global_position.z)


# --- Cleave ---------------------------------------------------------------

func test_cleave_hits_everything_in_its_arc_once() -> void:
	await wait_physics_frames(2)
	# The Warden faces -Z. Aim assist picks the nearest target, straight ahead.
	var ahead := _dummy(Vector3(0, 0, -1.6))
	var beside := _dummy(Vector3(2.2, 0, 0))
	var behind := _dummy(Vector3(0, 0, 2.0))
	var too_far := _dummy(Vector3(0, 0, -3.2))
	_tap(GameplayActions.ABILITY_1)
	await wait_physics_frames(60)
	check(ahead.health.current == 25, "ahead takes 25, has %d" % ahead.health.current)
	check(beside.health.current == 25, "beside (90°, inside the 220° arc) takes 25, has %d" % beside.health.current)
	check(behind.health.current == 50, "behind is outside the arc")
	check(too_far.health.current == 50, "beyond 2.6 m is out of reach")


func test_cleave_has_a_cooldown() -> void:
	await wait_physics_frames(2)
	var starts := [0]
	cleave.attack.started.connect(func(_d: Vector3) -> void: starts[0] += 1)
	_tap(GameplayActions.ABILITY_1)
	await wait_physics_frames(60)
	_tap(GameplayActions.ABILITY_1)
	await wait_physics_frames(5)
	check(starts[0] == 1, "no second cleave during the 4 s cooldown")
	check(await wait_until(func() -> bool: return cleave.is_ready(), 200), "the cooldown ends")
	_tap(GameplayActions.ABILITY_1)
	await wait_physics_frames(2)
	check(starts[0] == 2, "cleaves again once ready")


func test_cleave_slows_the_warden() -> void:
	await wait_physics_frames(2)
	Input.action_press(MovementInput.RIGHT)
	await wait_physics_frames(30)
	_tap(GameplayActions.ABILITY_1)
	await wait_physics_frames(15)
	var speed := Vector2(warden.velocity.x, warden.velocity.z).length()
	Input.action_release(MovementInput.RIGHT)
	check(cleave.is_busy(), "still cleaving")
	check(speed <= warden.stats.move_speed * 0.2 + 0.01, "moving at 20%% speed, got %.2f m/s" % speed)


func test_dodging_cancels_the_cleave() -> void:
	await wait_physics_frames(2)
	var target := _dummy(Vector3(0, 0, -1.6))
	_tap(GameplayActions.ABILITY_1)
	await wait_physics_frames(3)
	check(cleave.is_busy(), "winding up")
	_tap(GameplayActions.DODGE)
	await wait_physics_frames(40)
	check(target.health.current == 50, "the canceled cleave never lands")


func test_cleave_cancels_the_basic_attack_and_holds_it_off() -> void:
	await wait_physics_frames(2)
	var basic_starts := [0, 0]
	warden.attack.started.connect(func(_d: Vector3) -> void: basic_starts[0] += 1)
	warden.attack.canceled.connect(func() -> void: basic_starts[1] += 1)
	Input.action_press(GameplayActions.ATTACK)
	await wait_until(func() -> bool: return warden.attack.is_busy(), 5)
	_tap(GameplayActions.ABILITY_1)
	await wait_physics_frames(2)
	check(basic_starts[1] == 1 and cleave.is_busy(), "the basic attack gave way to the cleave")
	await wait_until(func() -> bool: return not cleave.is_busy(), 60)
	check(basic_starts[0] == 1, "no basic attack started during the cleave")
	await wait_physics_frames(2)
	Input.action_release(GameplayActions.ATTACK)
	check(basic_starts[0] == 2, "basic attacks resume afterwards")


# --- Bulwark Guard --------------------------------------------------------

func test_guard_reduces_a_hit_and_counters_once() -> void:
	await wait_physics_frames(2)
	var hollow := _hollow(Vector3(0, 0, -1.3))
	check(await wait_until(func() -> bool: return hollow.attack.is_busy(), 10), "the Hollow winds up")
	_tap(GameplayActions.ABILITY_2)
	await wait_until(func() -> bool: return warden.health.current < 100, 40)
	check(warden.health.current == 98, "the 12 damage hit is cut to 2, health %d" % warden.health.current)
	await wait_physics_frames(3)
	check(hollow.health.current == 15, "the counter hits the Hollow for 15, it has %d" % hollow.health.current)
	# The Hollow's next hit lands 1.2 s after the first, after the 1 s guard.
	await wait_until(func() -> bool: return warden.health.current < 98, 120)
	check(warden.health.current == 86, "full damage once the guard is down, health %d" % warden.health.current)
	check(hollow.health.current == 15, "only one counter per guard")


func test_guard_counters_only_the_first_hit() -> void:
	await wait_physics_frames(2)
	var neighbor := _dummy(Vector3(1.5, 0, 0))
	_tap(GameplayActions.ABILITY_2)
	await wait_physics_frames(2)
	warden.health.apply_damage(10)
	await wait_physics_frames(3)
	warden.health.apply_damage(10)
	await wait_physics_frames(3)
	check(guard.is_guarding(), "both hits land during one guard")
	check(neighbor.health.current == 35, "one counter of 15, the neighbor has %d" % neighbor.health.current)
	check(warden.health.current == 96, "both hits cut to 2, health %d" % warden.health.current)


func test_guard_roots_the_warden() -> void:
	await wait_physics_frames(2)
	Input.action_press(MovementInput.RIGHT)
	_tap(GameplayActions.ABILITY_2)
	await wait_physics_frames(10)
	var at := _flat_position()
	await wait_physics_frames(30)
	var moved := _flat_position().distance_to(at)
	Input.action_release(MovementInput.RIGHT)
	check(guard.is_guarding(), "still guarding")
	check(moved < 0.01, "does not move while guarding, moved %.3f m" % moved)


func test_guard_ends_on_time_and_on_dodge() -> void:
	await wait_physics_frames(2)
	_tap(GameplayActions.ABILITY_2)
	await wait_physics_frames(2)
	check(warden.health.damage_multiplier == 0.2, "guard up")
	await wait_physics_frames(62)
	check(not guard.is_guarding() and warden.health.damage_multiplier == 1.0, "down after 1 s")
	await wait_until(func() -> bool: return guard.is_ready(), 400)
	_tap(GameplayActions.ABILITY_2)
	await wait_physics_frames(2)
	_tap(GameplayActions.DODGE)
	await wait_physics_frames(2)
	check(not guard.is_guarding() and warden.health.damage_multiplier == 1.0, "a dodge drops the guard")


func test_mitigation_rounds_and_still_reports_the_hit() -> void:
	var hits: Array[int] = []
	warden.health.hit.connect(func(amount: int) -> void: hits.append(amount))
	warden.health.damage_multiplier = 0.2
	check(warden.health.apply_damage(12) == 2, "12 becomes 2")
	check(warden.health.apply_damage(2) == 0, "2 rounds to nothing")
	check(hits == [12, 2], "both hits are reported before mitigation: %s" % [hits])


# --- Ember Brand ----------------------------------------------------------

func test_brand_needs_a_target_in_range() -> void:
	await wait_physics_frames(2)
	var distant := _dummy(Vector3(0, 0, -7.8))
	_tap(GameplayActions.ABILITY_3)
	await wait_physics_frames(3)
	check(brand.cooldown_fraction() == 0.0, "no target within 7 m: no cooldown spent")
	check(not distant.has_node("Burning"), "nothing branded")


func test_brand_burns_the_nearest_enemy_for_eight_ticks() -> void:
	await wait_physics_frames(2)
	var near := _dummy(Vector3(0, 0, -5))
	var farther := _dummy(Vector3(6, 0, 0))
	_tap(GameplayActions.ABILITY_3)
	await wait_physics_frames(2)
	check(brand.last_target == near and near.has_node("Burning"), "the nearest enemy is branded")
	check(not farther.has_node("Burning"), "only one")
	await wait_physics_frames(27)
	check(near.health.current == 50, "no tick before 0.5 s")
	await wait_physics_frames(4)
	check(near.health.current == 46, "first tick of 4 at 0.5 s, health %d" % near.health.current)
	await wait_physics_frames(240)
	check(near.health.current == 18, "8 ticks of 4 in all, health %d" % near.health.current)
	check(not near.has_node("Burning"), "the burn ends")


func test_burn_ticks_are_frame_rate_independent() -> void:
	# 0.35 s is not a whole number of ticks at 30 Hz, so a timer that drops
	# its leftover time would fall behind there.
	var healths: Array[int] = []
	for ticks: int in [30, 60, 120]:
		Engine.physics_ticks_per_second = ticks
		var target := _dummy(Vector3(0, 0, -4))
		await wait_physics_frames(1)
		Burning.apply(target.health, 4, 0.35, 20)
		await wait_physics_frames(int(ticks * 3.6))  # Ten ticks: 0.35 s to 3.5 s.
		healths.append(target.health.current)
		target.free()
	Engine.physics_ticks_per_second = 60
	check(healths == [10, 10, 10], "ten ticks in 3.6 s at 30, 60 and 120 Hz: %s" % [healths])


func test_rebranding_restarts_instead_of_stacking() -> void:
	var target := _dummy(Vector3(0, 0, -4))
	await wait_physics_frames(1)
	Burning.apply(target.health, 4, 0.5, 8)
	await wait_physics_frames(91)  # Three ticks.
	Burning.apply(target.health, 4, 0.5, 8)
	var burns := target.get_children().filter(func(c: Node) -> bool: return c is Burning)
	check(burns.size() == 1, "one burn per enemy")
	check((burns[0] as Burning).ticks_left == 8, "the count restarts")
	await wait_physics_frames(31)
	check(target.health.current == 50 - 4 * 4, "one tick per interval, not two, health %d" % target.health.current)


func test_a_dead_target_stops_burning() -> void:
	var hollow := _hollow(Vector3(0, 0, -12))  # Beyond aggro range.
	await wait_physics_frames(1)
	Burning.apply(hollow.health, 4, 0.5, 8)
	await wait_physics_frames(31)
	hollow.health.apply_damage(hollow.health.max_health)
	await wait_physics_frames(2)
	check(not hollow.has_node("Burning"), "the burn is gone with the target's life")


# --- Shared ---------------------------------------------------------------

func test_only_one_ability_at_a_time() -> void:
	await wait_physics_frames(2)
	_tap(GameplayActions.ABILITY_2)
	await wait_physics_frames(2)
	_tap(GameplayActions.ABILITY_1)
	await wait_physics_frames(2)
	check(guard.is_guarding() and not cleave.is_busy(), "no cleave while guarding")
	check(cleave.cooldown_fraction() == 0.0, "and no cooldown spent on it")


func test_death_cancels_abilities() -> void:
	await wait_physics_frames(2)
	_tap(GameplayActions.ABILITY_2)
	await wait_physics_frames(2)
	warden.health.damage_multiplier = 1.0  # Let the killing blow through.
	warden.health.apply_damage(warden.health.max_health)
	check(not guard.is_guarding(), "the guard drops on death")


func test_pause_holds_cooldowns() -> void:
	await wait_physics_frames(2)
	_tap(GameplayActions.ABILITY_2)
	await wait_physics_frames(10)
	get_tree().paused = true
	var left := guard.cooldown_fraction()
	await wait_physics_frames(60)
	check(guard.cooldown_fraction() == left, "no cooldown progress while paused")
	get_tree().paused = false


func test_hud_buttons_follow_the_abilities() -> void:
	warden.free()
	var main := instantiate_main()
	add_child(main)
	var hud := main.get_node("HUD")
	var player: PlayerController = main.get_node("Player")
	await wait_physics_frames(2)
	var expected := {"CleaveButton": "CLEAVE", "GuardButton": "GUARD", "BrandButton": "BRAND"}
	for button_name in expected:
		var button: TouchActionButton = hud.get_node("%" + button_name)
		check(button.visible and button.label == expected[button_name], "%s reads %s" % [button_name, expected[button_name]])
	var guard_button: TouchActionButton = hud.get_node("%GuardButton")
	var touch := InputEventScreenTouch.new()
	touch.position = guard_button.get_global_rect().get_center()
	touch.pressed = true
	get_viewport().push_input(touch)
	touch = touch.duplicate()
	touch.pressed = false
	get_viewport().push_input(touch)
	var main_guard: GuardAbility = player.get_node("Guard")
	check(await wait_until(func() -> bool: return main_guard.is_guarding(), 5), "tapping GUARD raises the guard")
	check(guard_button.cooldown_fraction() > 0.9, "and the button shows the cooldown")
