extends SceneTree
## Retargets Quaternius's Universal Animation Library (CC0) onto the KayKit
## rig (Rig_Medium, shared by every hero and enemy model) and saves the
## result as one AnimationLibrary: game/assets/third_party/quaternius/mocap.res.
##
## Usage (from the repository root, after tools/anim/fetch_ual.py):
##   godot --headless --path game --script ../tools/anim/retarget_ual.gd
## UAL1 and UAL2 name the two source .glb files (default: the fetch cache).
##
## How: both rigs rest in a T-pose and face +Z, so each mapped KayKit bone is
## given its source bone's rotation away from rest, in world space:
##   target_global = (source_global × source_rest_global⁻¹) × target_rest_global
## and its local rotation follows from its parent's. The source's clavicles,
## second spine bone, neck and fingers fold into the bones the KayKit rig has.
## The hips' movement is scaled by the ratio of hip heights.

const OUT := "res://assets/third_party/quaternius/mocap.res"
const TARGET := "res://assets/third_party/kaykit/characters/Knight.glb"
const FPS := 30.0

## KayKit bone ← UAL bone.
const MAP := {
	"hips": "pelvis", "spine": "spine_01", "chest": "spine_03", "head": "Head",
	"upperarm.l": "upperarm_l", "lowerarm.l": "lowerarm_l", "wrist.l": "hand_l",
	"upperarm.r": "upperarm_r", "lowerarm.r": "lowerarm_r", "wrist.r": "hand_r",
	"upperleg.l": "thigh_l", "lowerleg.l": "calf_l", "foot.l": "foot_l", "toes.l": "ball_l",
	"upperleg.r": "thigh_r", "lowerleg.r": "calf_r", "foot.r": "foot_r", "toes.r": "ball_r",
}

## The clips taken, by source library.
const CLIPS := {
	"UAL1": ["Sword_Attack", "Sword_Idle", "Spell_Simple_Shoot", "Spell_Simple_Enter", "Roll",
			"Hit_Chest", "Hit_Head", "Death01", "Punch_Jab", "Punch_Cross", "Idle_Loop", "Jog_Fwd_Loop"],
	"UAL2": ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C", "Sword_Heavy_Combo", "Sword_Dash",
			"Sword_Block", "Shield_Dash", "Shield_OneShot", "Melee_Hook", "Hit_Knockback", "OverhandThrow",
			"Consume", "Zombie_Scratch", "Zombie_Walk_Fwd_Loop", "Zombie_Idle_Loop", "Idle_Shield_Loop"],
}


func _init() -> void:
	var cache := OS.get_environment("HOME").path_join(".cache/ashenbound-anim")
	var sources := {
		"UAL1": OS.get_environment("UAL1") if OS.has_environment("UAL1") else cache.path_join("UAL1_Standard.glb"),
		"UAL2": OS.get_environment("UAL2") if OS.has_environment("UAL2") else cache.path_join("UAL2_Standard.glb"),
	}
	var target_scene: Node = (load(TARGET) as PackedScene).instantiate()
	var target: Skeleton3D = target_scene.find_children("*", "Skeleton3D", true, false)[0]
	var target_path := String(target_scene.get_path_to(target))
	var library := AnimationLibrary.new()
	for key: String in CLIPS:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(sources[key], state) != OK:
			push_error("cannot read %s" % sources[key])
			quit(1)
			return
		var scene := doc.generate_scene(state)
		var source: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var source_path := String(scene.get_path_to(source))
		for clip: String in CLIPS[key]:
			if not player.has_animation(clip):
				push_error("%s has no %s" % [key, clip])
				continue
			var retargeted := _retarget(player.get_animation(clip), source, source_path, target, target_path)
			retargeted.loop_mode = Animation.LOOP_LINEAR if clip.ends_with("_Loop") or clip.ends_with("_Idle") else Animation.LOOP_NONE
			library.add_animation(StringName(clip), retargeted)
			print("%s: %.2f s" % [clip, retargeted.length])
		scene.free()
	target_scene.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var error := ResourceSaver.save(library, OUT, ResourceSaver.FLAG_COMPRESS)
	print("saved %s (%d clips): %s" % [OUT, library.get_animation_list().size(), error_string(error)])
	quit(0 if error == OK else 1)


func _retarget(anim: Animation, source: Skeleton3D, source_path: String, target: Skeleton3D,
		target_path: String) -> Animation:
	var rotation_tracks := {}
	var position_tracks := {}
	for t in anim.get_track_count():
		var bone := String(anim.track_get_path(t)).trim_prefix(source_path + ":")
		match anim.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				rotation_tracks[bone] = t
			Animation.TYPE_POSITION_3D:
				position_tracks[bone] = t
	var source_rest := _global_rests(source)
	var target_rest := _global_rests(target)
	var scale := target_rest[target.find_bone("hips")].origin.y / source_rest[source.find_bone("pelvis")].origin.y
	var out := Animation.new()
	var frames := maxi(int(ceil(anim.length * FPS)), 1)
	out.length = anim.length
	var out_tracks := {}
	for bone: String in MAP:
		var track := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(track, NodePath("%s:%s" % [target_path, bone]))
		out_tracks[bone] = track
	var hips_position := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hips_position, NodePath("%s:hips" % target_path))
	var pelvis := source.find_bone("pelvis")
	var hips := target.find_bone("hips")
	for f in frames + 1:
		var time := minf(f / FPS, anim.length)
		# The source's pose at `time`, in skeleton space.
		var source_global: Array[Transform3D] = []
		source_global.resize(source.get_bone_count())
		for i in source.get_bone_count():
			var name := source.get_bone_name(i)
			var local := source.get_bone_rest(i)
			if rotation_tracks.has(name):
				local.basis = Basis(anim.rotation_track_interpolate(rotation_tracks[name], time))
			if position_tracks.has(name):
				local.origin = anim.position_track_interpolate(position_tracks[name], time)
			var parent := source.get_bone_parent(i)
			source_global[i] = source_global[parent] * local if parent >= 0 else local
		# The target, parents before children (bone indices are ordered so).
		var target_global: Array[Basis] = []
		target_global.resize(target.get_bone_count())
		for i in target.get_bone_count():
			var parent := target.get_bone_parent(i)
			var parent_basis := target_global[parent] if parent >= 0 else Basis()
			var name := target.get_bone_name(i)
			if MAP.has(name):
				var s := source.find_bone(MAP[name])
				var delta := source_global[s].basis.orthonormalized() * source_rest[s].basis.orthonormalized().inverse()
				target_global[i] = delta * target_rest[i].basis.orthonormalized()
				var local_rotation := (parent_basis.inverse() * target_global[i]).get_rotation_quaternion()
				out.rotation_track_insert_key(out_tracks[name], time, local_rotation)
			else:
				target_global[i] = parent_basis * target.get_bone_rest(i).basis
		var moved := (source_global[pelvis].origin - source_rest[pelvis].origin) * scale
		out.position_track_insert_key(hips_position, time, target.get_bone_rest(hips).origin + moved)
	return out


static func _global_rests(skeleton: Skeleton3D) -> Array[Transform3D]:
	var rests: Array[Transform3D] = []
	rests.resize(skeleton.get_bone_count())
	for i in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(i)
		rests[i] = rests[parent] * skeleton.get_bone_rest(i) if parent >= 0 else skeleton.get_bone_rest(i)
	return rests
