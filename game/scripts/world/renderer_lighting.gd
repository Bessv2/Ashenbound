class_name RendererLighting
extends Node
## Gives the Compatibility renderer (the web preview, see docs/WEB_PREVIEW.md)
## its own lighting. It lights the same scene noticeably brighter and flatter
## than the Mobile renderer the Android build uses, so the level carries a
## second environment and moonlight strength for it. Visual only.

@export var world_environment: WorldEnvironment
@export var moonlight: DirectionalLight3D
@export var compatibility_environment: Environment
@export_range(0.0, 4.0, 0.05) var compatibility_moonlight_energy: float = 1.0


func _ready() -> void:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		return
	if world_environment and compatibility_environment:
		world_environment.environment = compatibility_environment
	if moonlight:
		moonlight.light_energy = compatibility_moonlight_energy
