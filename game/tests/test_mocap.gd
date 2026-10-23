extends "res://tests/framework/test_case.gd"
## Tests for the motion-captured clips (docs/ANIMATION.md): the retargeted
## library, which scenes use which clips, combos that alternate, and that the
## classic look and combat timing are untouched.

const WardenScene := preload("res://scenes/player/warden.tscn")
const GhoulScene := preload("res://scenes/enemies/ghoul.tscn")
const SkeletonScene := preload("res://scenes/enemies/skeleton_warrior.tscn")

const ANIMATED_SCENES := [
	"res://scenes/player/warden.tscn", "res://scenes/player/reaver.tscn",
	"res://scenes/player/hexbinder.tscn", "res://scenes/player/dreadhunter.tscn",
	"res://scenes/player/reliquary.tscn", "res://scenes/player/gravecaller.tscn",
	"res://scenes/player/forsaken_skeleton.tscn",
	"res://scenes/enemies/skeleton_warrior.tscn", "res://scenes/enemies/ghoul.tscn",
	"res://scenes/enemies/dark_cultist.tscn", "res://scenes/enemies/fallen_knight.tscn",
	"res://scenes/enemies/ashen_lord.tscn", "res://scenes/enemies/hollow_king.tscn",
]


func _exit_tree() -> void:
	ArtStyle.override_look = -1


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await wait_physics_frames(1)
	Input.action_release(action)


func test_the_library_is_retargeted_onto_the_kaykit_rig() -> void:
	var library: AnimationLibrary = CharacterAnimator.MocapClips
	check(library.get_animation_list().size() >= 20, "the clips: %d" % library.get_animation_list().size())
	var swing := library.get_animation(&"Sword_Regular_A")
	var arm := swing.find_track(^"Rig/Skeleton3D:upperarm.r", Animation.TYPE_ROTATION_3D)
	check(arm >= 0, "it drives the KayKit rig's bones")
	var start := swing.rotation_track_interpolate(arm, 0.0)
	var middle := swing.rotation_track_interpolate(arm, swing.length * 0.5)
	check(start.angle_to(middle) > 0.2, "and the arm really swings: %.2f rad" % start.angle_to(middle))
	check(library.get_animation(&"Idle_Loop").loop_mode == Animation.LOOP_LINEAR, "loops loop")
	check(library.get_animation(&"Death01").loop_mode == Animation.LOOP_NONE, "one-shots do not")


func test_every_mocap_clip_a_scene_names_exists() -> void:
	var library: AnimationLibrary = CharacterAnimator.MocapClips
	var named := 0
	for path: String in ANIMATED_SCENES:
		var scene := (load(path) as PackedScene).instantiate()
		var animator := scene.get_node(^"Animator") as CharacterAnimator
		var entries: Array[String] = []
		entries.append_array(animator.mocap_attacks)
		entries.append_array(animator.mocap_abilities)
		entries.append_array([animator.mocap_idle, animator.mocap_run, animator.mocap_hit, animator.mocap_death])
		for entry in entries:
			for clip in entry.split("|", false):
				named += 1
				check(library.has_animation(StringName(clip)), "%s names %s" % [path.get_file(), clip])
		check(animator.mocap_attacks.size() <= animator.attacks.size(), "%s: one entry per attack at most" % path.get_file())
		scene.free()
	check(named > 30, "the scenes name their clips: %d" % named)


func test_classic_keeps_the_kaykit_clips() -> void:
	ArtStyle.override_look = ArtStyle.Look.CLASSIC
	add_level(40.0)
	var warden: PlayerController = WardenScene.instantiate()
	add_child(warden)
	var animator := warden.get_node("Animator") as CharacterAnimator
	var player: AnimationPlayer = warden.get_node("Visual/Model/AnimationPlayer")
	check(not animator.uses_mocap and not player.has_animation_library(CharacterAnimator.MOCAP_LIBRARY), "no mocap in classic")
	await wait_physics_frames(2)
	await _tap(GameplayActions.ATTACK)
	await wait_process_frames(2)
	check(player.current_animation == "2H_Melee_Attack_Slice", "the KayKit swing: %s" % player.current_animation)


func test_looks_a_and_b_swing_mocap_combos_and_flinch_and_die_in_mocap() -> void:
	for look in [ArtStyle.Look.HEROIC, ArtStyle.Look.GRIM]:
		ArtStyle.override_look = look
		var level := add_level(40.0)
		var warden: PlayerController = WardenScene.instantiate()
		add_child(warden)
		var player: AnimationPlayer = warden.get_node("Visual/Model/AnimationPlayer")
		await wait_physics_frames(2)
		var swings: Array[String] = []
		for i in 3:
			await _tap(GameplayActions.ATTACK)
			await wait_process_frames(2)
			swings.append(player.current_animation)
			await wait_physics_frames(40)
		check(swings == ["mocap/Sword_Regular_A", "mocap/Sword_Regular_B", "mocap/Sword_Regular_A"],
				"look %d: blows alternate as a combo: %s" % [look, swings])
		warden.health.apply_damage(5)
		await wait_process_frames(2)
		check(player.current_animation.begins_with("mocap/Hit_"), "look %d: a mocap flinch: %s" % [look, player.current_animation])
		warden.health.apply_damage(1000)
		await wait_process_frames(2)
		check(player.current_animation == "mocap/Death01", "look %d: a mocap death: %s" % [look, player.current_animation])
		warden.free()
		level.free()
		await wait_physics_frames(2)


func test_ghouls_shamble_and_scratch_like_the_dead() -> void:
	ArtStyle.override_look = ArtStyle.Look.HEROIC
	add_level(40.0)
	var ghoul: EnemyController = GhoulScene.instantiate()
	add_child(ghoul)
	var animator := ghoul.get_node("Animator") as CharacterAnimator
	check(animator.idle_animation == &"mocap/Zombie_Idle_Loop" and animator.run_animation == &"mocap/Zombie_Walk_Fwd_Loop",
			"a zombie idle and shamble")
	ghoul.free()


func test_mocap_changes_nothing_in_combat() -> void:
	var frames: Array[int] = []
	for look in [ArtStyle.Look.CLASSIC, ArtStyle.Look.HEROIC]:
		ArtStyle.override_look = look
		var level := add_level(30.0)
		var warden: PlayerController = WardenScene.instantiate()
		add_child(warden)
		var skeleton: EnemyController = SkeletonScene.instantiate()
		skeleton.position = Vector3(0, 0, -1.4)
		skeleton.set_physics_process(false)
		add_child(skeleton)
		await wait_physics_frames(2)
		var before := skeleton.health.current
		warden.attack.try_start(Vector3.FORWARD)
		var waited := 0
		while skeleton.health.current == before and waited < 120:
			await wait_physics_frames(1)
			waited += 1
		frames.append(waited)
		check(before - skeleton.health.current == 10, "look %d: the same 10 damage" % look)
		warden.free()
		skeleton.free()
		level.free()
		await wait_physics_frames(2)
	check(frames[0] == frames[1], "the blow lands on the same frame: %s" % [frames])
