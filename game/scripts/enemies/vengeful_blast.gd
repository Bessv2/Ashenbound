class_name VengefulBlast
extends Node3D
## Where a Vengeful champion fell, the ground erupts: a ring on the floor
## shows the area and fills in for DELAY seconds, then everything on
## `target_mask` inside RADIUS takes the hit once, and the blast is gone.
## Long enough to dodge out of, like any enemy telegraph.
##
## The fill and the burst are presentation; the damage is dealt once, here,
## through Health.

const RADIUS := 3.0
const DELAY := 1.2
## Before the champion's damage scale.
const DAMAGE := 16
const COLOR := Color(0.75, 0.35, 1.0)

var damage: int = DAMAGE
var target_mask: int = 2

var _left: float = DELAY
var _fill: MeshInstance3D
var _fill_material: StandardMaterial3D


## Starts an eruption at `at` (world, on the floor), under `parent` so it goes
## when the level goes. `damage_scale` is the fallen champion's.
static func erupt(parent: Node, at: Vector3, damage_scale: float, mask: int) -> VengefulBlast:
	var blast := VengefulBlast.new()
	blast.name = "VengefulBlast"
	blast.damage = maxi(roundi(DAMAGE * damage_scale), 1)
	blast.target_mask = mask
	parent.add_child(blast)
	blast.global_position = Vector3(at.x, 0.0, at.z)
	# The fuse: the blast's warning, as the ring grows.
	Audio.play(&"ignite", blast.global_position, 0.8, 4.0)
	return blast


func _ready() -> void:
	var edge := Champion.ring_mesh("Edge", RADIUS, COLOR, 0.8)
	add_child(edge)
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.02
	disc.radial_segments = 40
	disc.rings = 1
	_fill = MeshInstance3D.new()
	_fill.name = "Fill"
	_fill.mesh = disc
	_fill.position.y = 0.04
	_fill.scale = Vector3(0.05, 1.0, 0.05)
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill_material = StandardMaterial3D.new()
	_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_material.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, 0.35)
	_fill.material_override = _fill_material
	add_child(_fill)


## Seconds until it erupts.
func time_left() -> float:
	return maxf(_left, 0.0)


func _physics_process(delta: float) -> void:
	_left -= delta
	var grown := clampf(1.0 - _left / DELAY, 0.05, 1.0)
	_fill.scale = Vector3(grown, 1.0, grown)
	if _left > 0.0:
		return
	for target in Targeting.living_around(self, global_position, RADIUS, target_mask):
		target.apply_damage(damage, global_position)
	Vfx.ring(get_parent(), global_position, RADIUS, COLOR, 0.4)
	Vfx.burst(get_parent(), global_position + Vector3.UP * 0.3, COLOR, 22, 6.0, 0.5, 0.14)
	Vfx.flames(get_parent(), global_position + Vector3.UP * 0.3, COLOR, 14, 2.4, 0.55)
	Vfx.smoke(get_parent(), global_position + Vector3.UP * 0.5, Color(0.3, 0.26, 0.24), 8, 2.6, 1.4)
	Vfx.scorch(get_parent(), global_position, RADIUS)
	Audio.play(&"explosion", global_position)
	queue_free()
	set_physics_process(false)
