extends "res://tests/framework/test_case.gd"
## Tests for the presentation layer: the dressed KayKit models and the
## CharacterAnimator that plays their clips from gameplay signals.

const WardenScene := preload("res://scenes/player/warden.tscn")
const HollowScene := preload("res://scenes/enemies/hollow.tscn")

var warden: PlayerController
var player: AnimationPlayer


func _ready() -> void:
	add_level(40.0)
	warden = WardenScene.instantiate()
	add_child(warden)
	player = warden.get_node("Visual/Model/AnimationPlayer")


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await wait_physics_frames(1)
	Input.action_release(action)


func test_the_warden_idles_then_runs() -> void:
	await wait_process_frames(3)
	check(player.current_animation == "Idle", "idle at rest, got %s" % player.current_animation)
	Input.action_press(MovementInput.RIGHT)
	await wait_physics_frames(20)
	check(player.current_animation == "Running_A", "runs while moving, got %s" % player.current_animation)
	Input.action_release(MovementInput.RIGHT)
	await wait_physics_frames(30)
	check(player.current_animation == "Idle", "idles again after stopping, got %s" % player.current_animation)


func test_attacks_and_abilities_play_their_clips() -> void:
	await wait_physics_frames(2)
	await _tap(GameplayActions.ATTACK)
	await wait_process_frames(2)
	check(player.current_animation == "2H_Melee_Attack_Slice", "basic attack, got %s" % player.current_animation)
	await wait_until(func() -> bool: return not warden.attack.is_busy(), 60)
	await _tap(GameplayActions.ABILITY_1)
	await wait_process_frames(2)
	check(player.current_animation == "2H_Melee_Attack_Spin", "Cleave spins, got %s" % player.current_animation)


func test_dodge_plays_the_dodge_clip_sped_up_to_fit() -> void:
	await wait_physics_frames(2)
	await _tap(GameplayActions.DODGE)
	await wait_process_frames(2)
	check(player.current_animation == "Dodge_Forward", "dodge clip, got %s" % player.current_animation)
	var clip_time := player.get_animation(&"Dodge_Forward").length / player.get_playing_speed()
	check(clip_time <= warden.dodge.data.duration + 0.01, "the clip lasts no longer than the dodge: %.2f s" % clip_time)


func test_the_warden_carries_only_the_greatsword() -> void:
	await wait_process_frames(1)
	var model: Node3D = warden.get_node("Visual/Model")
	var visible_weapons: Array = []
	for name in ["1H_Sword", "1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "2H_Sword"]:
		var part := model.find_child(name, true, false) as Node3D
		check(part != null, "%s exists in the model" % name)
		if part and part.visible:
			visible_weapons.append(name)
	check(visible_weapons == ["2H_Sword"], "only the greatsword shows: %s" % [visible_weapons])


func test_animations_stop_while_paused() -> void:
	await wait_process_frames(5)
	get_tree().paused = true
	var position := player.current_animation_position
	await wait_process_frames(10)
	check_near(player.current_animation_position, position, 0.0001, "the clip holds while paused")


func test_the_hollow_dies_with_its_death_clip() -> void:
	var hollow: EnemyController = HollowScene.instantiate()
	hollow.position = Vector3(0, 0, -12)
	add_child(hollow)
	var hollow_player: AnimationPlayer = hollow.get_node("Visual/Model/AnimationPlayer")
	await wait_process_frames(2)
	hollow.health.apply_damage(hollow.health.max_health)
	await wait_process_frames(2)
	check(hollow_player.current_animation == "Death_C_Skeletons", "death clip, got %s" % hollow_player.current_animation)
	check(hollow.health.is_dead() and hollow.state == EnemyController.State.DEAD, "the animator leaves gameplay state alone")


func test_the_hollow_swings_its_blade_when_it_attacks() -> void:
	var hollow: EnemyController = HollowScene.instantiate()
	hollow.position = Vector3(0, 0, -1.3)
	add_child(hollow)
	var hollow_player: AnimationPlayer = hollow.get_node("Visual/Model/AnimationPlayer")
	check(await wait_until(func() -> bool: return hollow.is_attacking(), 20), "attacking")
	await wait_process_frames(2)
	check(hollow_player.current_animation == "1H_Melee_Attack_Chop", "attack clip, got %s" % hollow_player.current_animation)
	check(hollow.get_node("Visual/Model/Rig/Skeleton3D/RightHand/Blade") != null, "the blade rides the right hand")
