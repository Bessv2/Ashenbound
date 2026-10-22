extends "res://tests/framework/test_case.gd"
## Tests for the end of a run: the Ash reward, paid once, the summary, and the
## Milestone 3 gate (several runs in a row, each clean).

const CryptScene := preload("res://scenes/dungeon/crypt.tscn")

## Ash for a full crypt run: Ossuary 3 + 3 Skeletons and a Cultist (1 each,
## 2); Chapel 2 Cultists, 2 + 2 Skeletons and the Fallen Knight (10); the
## Ashen Lord (50).
const CRYPT_ASH := 3 + 3 + 2 + 2 * 2 + 4 + 10 + 50


func _add_crypt() -> Node3D:
	var main := instantiate_main(false, CryptScene)
	add_child(main)
	return main


## Walks into each combat room and kills everything there, in order.
func _clear_crypt(main: Node3D) -> bool:
	var player: PlayerController = main.get_node("Player")
	var level: Level = main.level
	for room: Array in [["Ossuary", -20.0], ["Chapel", -50.0], ["Throne", -85.0]]:
		player.global_position = Vector3(0, 0, room[1])
		player.reset_physics_interpolation()
		var encounter: EncounterController = level.get_node("Encounters/" + room[0])
		var done := await wait_until(func() -> bool:
			for enemy in encounter.living_enemies():
				var health := Health.of(enemy)
				health.invulnerable = false
				health.apply_damage(health.max_health)
			return encounter.phase == EncounterController.Phase.CLEARED, 900)
		if not done:
			return false
		await wait_physics_frames(2)
	return true


func test_a_run_reward_is_paid_once() -> void:
	var before: int = Profile.ash
	check(Profile.grant_run_reward("test-run-a", 7), "the first claim pays")
	check(not Profile.grant_run_reward("test-run-a", 7), "the same run cannot be paid twice")
	check(Profile.ash == before + 7, "paid exactly once: %d" % (Profile.ash - before))
	check(not Profile.grant_run_reward("", 5), "a run needs an id")


func test_three_runs_in_a_row_start_clean_and_pay_once_each() -> void:
	var ids: Array[String] = []
	for attempt in 3:
		var before: int = Profile.ash
		var main := _add_crypt()
		var run: RunController = main.get_node("Run")
		var player: PlayerController = main.get_node("Player")
		player.health.invulnerable = true
		await wait_physics_frames(5)
		check(run.result == RunController.Result.RUNNING and run.kills == 0 and run.ash == 0,
				"run %d starts from nothing" % attempt)
		check(not ids.has(run.run_id), "run %d has its own id" % attempt)
		ids.append(run.run_id)
		for encounter in main.level.encounters:
			check(encounter.phase == EncounterController.Phase.WAITING and encounter.living_enemies().is_empty(),
					"run %d: %s waits, empty" % [attempt, encounter.name])
		check(get_tree().get_nodes_in_group(PlayerController.GROUP).size() == 1, "run %d: one hero" % attempt)
		check(get_tree().get_nodes_in_group(&"boss").is_empty(), "run %d: no boss left over" % attempt)
		check(await _clear_crypt(main), "run %d: every room cleared" % attempt)
		check(run.result == RunController.Result.VICTORY, "run %d is won" % attempt)
		check(run.ash == CRYPT_ASH, "run %d earned %d Ash, expected %d" % [attempt, run.ash, CRYPT_ASH])
		check(Profile.ash == before + CRYPT_ASH, "run %d paid once: %d" % [attempt, Profile.ash - before])
		check(not run.claim_reward(), "run %d cannot be paid again" % attempt)
		main.free()
		await wait_physics_frames(3)
		check(get_tree().get_nodes_in_group(PlayerController.GROUP).is_empty(), "run %d leaves no hero" % attempt)


func test_a_defeat_keeps_the_ash_earned_and_shows_the_summary() -> void:
	var main := _add_crypt()
	var run: RunController = main.get_node("Run")
	var player: PlayerController = main.get_node("Player")
	var before: int = Profile.ash
	player.global_position = Vector3(0, 0, -20)
	var encounter: EncounterController = main.level.get_node("Encounters/Ossuary")
	check(await wait_until(func() -> bool: return not encounter.living_enemies().is_empty(), 10), "the Ossuary wakes")
	await wait_physics_frames(60)
	var first := encounter.living_enemies()[0]
	Health.of(first).apply_damage(1000)
	player.health.apply_damage(30)
	player.health.apply_damage(1000)
	check(run.result == RunController.Result.DEFEAT, "the run is lost")
	check(run.ash == 1 and Profile.ash == before + 1, "the Ash earned is kept: %d" % (Profile.ash - before))
	check(run.damage_taken == 100, "damage taken counted: %d" % run.damage_taken)
	var screen: DeathScreen = main.get_node("DeathScreen")
	var details: Label = screen.get_node("%Details")
	check(screen.visible and details.visible, "the summary shows")
	check(details.text.contains("Ash earned 1") and details.text.contains("Enemies slain 1"), details.text)


func test_victory_waits_two_seconds_before_the_summary() -> void:
	var main := _add_crypt()
	var player: PlayerController = main.get_node("Player")
	player.health.invulnerable = true
	await wait_physics_frames(5)
	check(await _clear_crypt(main), "cleared")
	var screen: DeathScreen = main.get_node("DeathScreen")
	var root: Control = screen.get_node("Root")
	check(not player.input_enabled, "the hero stops at once")
	await wait_physics_frames(90)
	check(root.modulate.a < 0.01, "nothing shows for the first moments")
	check(await wait_until(func() -> bool: return root.modulate.a > 0.99, 120), "then the summary fades in")
	check((screen.get_node("%Details") as Label).text.contains("Ash earned %d" % CRYPT_ASH), "with the Ash")
