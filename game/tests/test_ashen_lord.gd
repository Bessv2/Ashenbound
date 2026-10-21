extends "res://tests/framework/test_case.gd"
## Tests for the Ashen Lord: phases, summons, attack choice, the Ember Ring and
## the boss bar.

const LordScene := preload("res://scenes/enemies/ashen_lord.tscn")
const RingScene := preload("res://scenes/combat/ember_ring.tscn")
const WardenScene := preload("res://scenes/player/warden.tscn")
const CryptScene := preload("res://scenes/dungeon/crypt.tscn")

var player: PlayerController


func _setup() -> void:
	add_level(60.0)
	player = WardenScene.instantiate()
	add_child(player)


## An encounter holding just the Lord, 12 m north of the player, with three
## summon markers. Started, so the Lord is spawned (and rising).
func _lord_encounter() -> EncounterController:
	var data := EncounterData.new()
	data.rise_time = 0.2
	var wave := WaveData.new()
	wave.enemies.append(LordScene)
	wave.markers.append("North")
	data.waves.append(wave)
	var encounter := EncounterController.new()
	encounter.data = data
	for spot: Array in [["North", Vector3(0, 0, -12)], ["SummonA", Vector3(-6, 0, -8)],
			["SummonB", Vector3(6, 0, -8)], ["SummonC", Vector3(0, 0, -16)]]:
		var marker := Marker3D.new()
		marker.name = spot[0]
		marker.position = spot[1]
		encounter.add_child(marker)
	add_child(encounter)
	encounter.start()
	return encounter


func _lord(encounter: EncounterController) -> AshenLord:
	return encounter.living_enemies()[0] as AshenLord


func _hit(lord: AshenLord, amount: int) -> void:
	lord.health.invulnerable = false
	lord.health.apply_damage(amount)


func test_phases_start_once_each_and_in_order_even_from_one_big_hit() -> void:
	_setup()
	player.health.invulnerable = true
	var encounter := _lord_encounter()
	var lord := _lord(encounter)
	var phases: Array[int] = []
	lord.phase_changed.connect(func(p: int) -> void: phases.append(p))
	await wait_physics_frames(20)
	_hit(lord, 210)  # 390 / 600 = 65 %: still phase 1.
	check(phases.is_empty() and lord.phase == 1, "phase 1 above 60 %")
	_hit(lord, 240)  # 150 / 600 = 25 %: past both thresholds at once.
	check(phases == [2], "phase 2 first: %s" % [phases])
	check(lord.state == EnemyController.State.RISING and lord.health.invulnerable, "it roars, untouchable")
	check(await wait_until(func() -> bool: return phases.size() == 2, 200), "then phase 3 after the roar")
	check(phases == [2, 3], "in order: %s" % [phases])
	await wait_physics_frames(260)
	check(phases == [2, 3], "and never again: %s" % [phases])


func test_phase_two_summons_three_adds_once_and_they_die_with_the_lord() -> void:
	_setup()
	player.health.invulnerable = true
	var encounter := _lord_encounter()
	var lord := _lord(encounter)
	await wait_physics_frames(20)
	_hit(lord, 250)  # 350 / 600 = 58 %.
	check(lord.phase == 2 and lord.adds.size() == 3, "three adds: %d" % lord.adds.size())
	check(encounter.living_enemies().size() == 4, "the encounter counts them")
	await wait_physics_frames(150)
	_hit(lord, 200)  # 150 / 600 = 25 %: phase 3.
	await wait_physics_frames(150)
	check(lord.phase == 3 and lord.adds.size() == 3, "phase 3 summons no more")
	var cleared := [false]
	encounter.cleared.connect(func() -> void: cleared[0] = true)
	_hit(lord, 1000)
	await wait_physics_frames(2)
	for add in lord.adds:
		check(not is_instance_valid(add) or Health.of(add).is_dead(), "an add dies with the Lord")
	check(cleared[0], "and the encounter is cleared")


func test_phase_three_is_faster() -> void:
	_setup()
	player.health.invulnerable = true
	var encounter := _lord_encounter()
	var lord := _lord(encounter)
	await wait_physics_frames(20)
	_hit(lord, 430)  # 170 / 600: phases 2 then 3.
	check(await wait_until(func() -> bool: return lord.phase == 3, 200), "phase 3")
	check_near(lord.speed_multiplier, 1.3, 0.001, "30 % faster")
	check_near(lord.attack.windup_time(), 1.0 * 0.75, 0.001, "cleave windup 25 % shorter")
	check_near(lord.slam_attack.windup_time(), 1.2 * 0.75, 0.001, "slam windup 25 % shorter")


func test_slams_when_close_and_rings_every_third_attack_in_phase_two() -> void:
	_setup()
	player.health.invulnerable = true
	var encounter := _lord_encounter()
	var lord := _lord(encounter)
	var used: Array[String] = []
	lord.state_changed.connect(func(_from: EnemyController.State, to: EnemyController.State) -> void:
		if to == EnemyController.State.TELEGRAPH:
			used.append(lord.current_attack.name))
	check(await wait_until(func() -> bool: return used.size() >= 3, 60 * 12), "three attacks: %s" % [used])
	check(used.slice(0, 3) == ["AshSlam", "CinderCleave", "AshSlam"], "close up it alternates slam and cleave: %s" % [used])
	_hit(lord, 250)
	used.clear()
	lord.attacks_started = 0
	check(await wait_until(func() -> bool: return used.size() >= 3, 60 * 14), "three more: %s" % [used])
	check(used[2] == "EmberRing" and not used.slice(0, 2).has("EmberRing"), "the third is the ring: %s" % [used])


func test_the_ember_ring_hits_once_as_it_passes_and_misses_far_or_dodging_targets() -> void:
	_setup()
	player.global_position = Vector3(5, 0, 0)
	var ring: EmberRing = RingScene.instantiate()
	ring.damage = 20
	ring.max_radius = 10.0
	ring.duration = 2.0
	add_child(ring)
	await wait_physics_frames(40)  # Radius 6.7: past the player.
	check(player.health.current == 80, "the ring burns once as it passes: %d" % player.health.current)
	await wait_physics_frames(90)
	check(player.health.current == 80, "and only once")
	check(not is_instance_valid(ring), "the ring is gone at full size")
	player.health.revive()
	player.global_position = Vector3(11, 0, 0)
	var far: EmberRing = RingScene.instantiate()
	add_child(far)
	await wait_physics_frames(130)
	check(player.health.current == 100, "beyond 10 m the ring cannot reach")
	player.global_position = Vector3(4, 0, 0)
	var dodged: EmberRing = RingScene.instantiate()
	add_child(dodged)
	player.health.invulnerable = true
	await wait_physics_frames(40)
	player.health.invulnerable = false
	await wait_physics_frames(80)
	check(player.health.current == 100, "dodging through the edge avoids it for good")


func test_the_boss_bar_follows_the_lord_in_the_throne() -> void:
	var main := instantiate_main(false, CryptScene)
	add_child(main)
	var hud := main.get_node("HUD")
	var bar: BossBar = hud.get_node("%BossBar")
	var hero: PlayerController = main.get_node("Player")
	hero.health.invulnerable = true
	await wait_physics_frames(5)
	check(not bar.visible, "no bar before the boss")
	hero.global_position = Vector3(0, 0, -80)
	var encounter: EncounterController = main.level.get_node("Encounters/Throne")
	check(await wait_until(func() -> bool: return bar.visible, 30), "the bar shows when the Lord rises")
	var lord := encounter.living_enemies()[0] as AshenLord
	check(bar.tracked() == lord.health, "tracking the Lord's health")
	_hit(lord, 1000)
	await wait_process_frames(3)
	check(not bar.visible, "gone when he dies")
