extends "res://tests/framework/test_case.gd"
## Tests for encounters (waves, rising spawns, hunting) and for how a run ends.

const WardenScene := preload("res://scenes/player/warden.tscn")
const SkeletonScene := preload("res://scenes/enemies/skeleton_warrior.tscn")

var player: PlayerController


func _ready() -> void:
	add_level(60.0)
	player = WardenScene.instantiate()
	add_child(player)


## An encounter with `waves` waves of `per_wave` Skeleton Warriors each, its
## markers spread 4 m apart on a line 12 m north of the player.
func _make_encounter(waves: int, per_wave: int, rise_time: float = 0.3) -> EncounterController:
	var data := EncounterData.new()
	data.wave_delay = 0.5
	data.rise_time = rise_time
	for w in waves:
		var wave := WaveData.new()
		for i in per_wave:
			wave.enemies.append(SkeletonScene)
			wave.markers.append("Spawn%d" % i)
		data.waves.append(wave)
	var encounter := EncounterController.new()
	encounter.data = data
	for i in per_wave:
		var marker := Marker3D.new()
		marker.name = "Spawn%d" % i
		marker.position = Vector3(-4.0 + 4.0 * i, 0, -12)
		encounter.add_child(marker)
	add_child(encounter)
	return encounter


func _kill(enemies: Array[Node3D]) -> void:
	for enemy in enemies:
		var health := Health.of(enemy)
		health.invulnerable = false
		health.apply_damage(health.max_health)


func test_waves_advance_only_when_the_wave_is_dead() -> void:
	var encounter := _make_encounter(2, 2)
	var waves: Array[int] = []
	encounter.wave_started.connect(func(index: int) -> void: waves.append(index))
	encounter.start()
	check(waves == [0] and encounter.living_enemies().size() == 2, "wave 0 with two enemies: %s" % [waves])
	await wait_physics_frames(25)
	_kill([encounter.living_enemies()[0]])
	await wait_physics_frames(60)
	check(waves == [0], "one survivor holds the wave: %s" % [waves])
	_kill(encounter.living_enemies())
	await wait_physics_frames(10)
	check(waves == [0], "the next wave waits for the delay")
	await wait_physics_frames(30)
	check(waves == [0, 1] and encounter.living_enemies().size() == 2, "wave 1 after the delay: %s" % [waves])


func test_clearing_the_last_wave_clears_the_encounter_once() -> void:
	var encounter := _make_encounter(2, 1)
	var cleared := [0]
	encounter.cleared.connect(func() -> void: cleared[0] += 1)
	encounter.start()
	await wait_physics_frames(25)
	_kill(encounter.living_enemies())
	await wait_physics_frames(45)
	check(cleared[0] == 0, "not cleared after the first wave")
	_kill(encounter.living_enemies())
	await wait_physics_frames(45)
	check(cleared[0] == 1 and encounter.phase == EncounterController.Phase.CLEARED, "cleared once")
	encounter.start()
	await wait_physics_frames(45)
	check(encounter.living_enemies().is_empty(), "a cleared encounter does not start again")


func test_rising_enemies_cannot_act_or_be_hurt() -> void:
	var encounter := _make_encounter(1, 1, 0.8)
	encounter.start()
	var enemy := encounter.living_enemies()[0] as EnemyController
	var at := enemy.global_position
	check(enemy.state == EnemyController.State.RISING, "rising")
	check(enemy.health.apply_damage(50) == 0, "no damage while rising")
	await wait_physics_frames(30)
	check_vector_near(enemy.global_position, at, 0.05, "does not move while rising")
	var animation: AnimationPlayer = enemy.get_node("Visual/Model/AnimationPlayer")
	check(animation.current_animation == "Spawn_Ground_Skeletons", "plays the rise clip, got %s" % animation.current_animation)
	await wait_physics_frames(25)
	check(enemy.state != EnemyController.State.RISING, "risen after 0.8 s")
	check(enemy.health.apply_damage(5) == 5, "can be hurt once risen")


func test_encounter_enemies_hunt_from_anywhere() -> void:
	var encounter := _make_encounter(1, 1)
	encounter.get_node("Spawn0").position = Vector3(0, 0, -25)
	encounter.start()
	var enemy := encounter.living_enemies()[0] as EnemyController
	check(enemy.global_position.distance_to(player.global_position) > enemy.behavior.leash_radius,
			"spawned beyond the leash range")
	await wait_physics_frames(60)
	check(enemy.state == EnemyController.State.APPROACH, "hunts the player, state %s" % enemy.state)


func _make_run(encounter: EncounterController) -> RunController:
	var run := RunController.new()
	run.player_health = player.health
	run.encounters = [encounter]
	add_child(run)
	return run


func test_clearing_every_encounter_wins_the_run() -> void:
	var encounter := _make_encounter(1, 2)
	var run := _make_run(encounter)
	var results: Array[bool] = []
	run.ended.connect(func(victory: bool) -> void: results.append(victory))
	encounter.start()
	await wait_physics_frames(25)
	_kill(encounter.living_enemies())
	check(results == [true] and run.kills == 2, "victory with 2 kills: %s, %d" % [results, run.kills])
	player.health.apply_damage(1000)
	check(results == [true] and run.result == RunController.Result.VICTORY, "a death after victory changes nothing")


func test_dying_loses_the_run_for_good() -> void:
	var encounter := _make_encounter(1, 1)
	var run := _make_run(encounter)
	var results: Array[bool] = []
	run.ended.connect(func(victory: bool) -> void: results.append(victory))
	encounter.start()
	await wait_physics_frames(25)
	player.health.apply_damage(1000)
	_kill(encounter.living_enemies())
	check(results == [false] and run.result == RunController.Result.DEFEAT, "defeat stands: %s" % [results])
	var elapsed := run.elapsed
	await wait_physics_frames(10)
	check_near(run.elapsed, elapsed, 0.0001, "the clock stops when the run ends")


func test_main_scene_starts_its_encounter_only_when_asked() -> void:
	var quiet := instantiate_main()
	add_child(quiet)
	var quiet_encounter: EncounterController = quiet.get_node("Level/Enemies/Encounter")
	await wait_physics_frames(120)
	check(quiet_encounter.phase == EncounterController.Phase.WAITING, "tests get a quiet arena")
	quiet.free()
	var busy := instantiate_main(true)
	add_child(busy)
	var busy_encounter: EncounterController = busy.get_node("Level/Enemies/Encounter")
	await wait_physics_frames(120)
	check(busy_encounter.wave == 0 and busy_encounter.living_enemies().size() == 3, "the game starts wave 1 with 3 Skeleton Warriors")
