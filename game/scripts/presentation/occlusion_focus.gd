class_name OcclusionFocus
extends Node3D
## Tells occluder materials (resources/shaders/occluder_cutout.gdshader) where
## the hero is, so walls and pillars between it and the camera open up. Place
## it on the hero at chest height. Visual only.

const PARAMETER := &"occlusion_focus"


func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set(PARAMETER, get_global_transform_interpolated().origin)
