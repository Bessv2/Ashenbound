class_name DeadfallTrap
extends Node3D
## A rune-snare set by Deadfall. For `hold_time` it slows everything on
## `target_mask` standing in its `radius` almost to a stop (enemies that walk
## in are caught too). Then it erupts: each body in it takes `bolts` ×
## `bolt_damage` once, and the snare is gone. It belongs to the level, so it
## goes when the level goes.
##
## The rune ring, its fill and the eruption's sparks are presentation; the
## damage is dealt once, here, through Health.

const HOLD_FACTOR := 0.05
## How long each catch lasts; renewed while the body stays in.
const CATCH_SECONDS := 0.3

var radius: float = 3.0
var hold_time: float = 2.0
var bolts: int = 6
var bolt_damage: int = 4
var target_mask: int = 4
## The bodies the eruption hit.
var erupted_on: Array[Health] = []

var _left: float = 0.0
var _fill: MeshInstance3D


## Sets a snare at `at` (world, on the floor) under `parent`.
static func set_at(parent: Node, at: Vector3, trap_radius: float, hold: float, bolt_count: int,
		damage_per_bolt: int, mask: int) -> DeadfallTrap:
	var trap := DeadfallTrap.new()
	trap.name = "DeadfallTrap"
	trap.radius = trap_radius
	trap.hold_time = hold
	trap.bolts = bolt_count
	trap.bolt_damage = damage_per_bolt
	trap.target_mask = mask
	parent.add_child(trap)
	trap.global_position = Vector3(at.x, 0.0, at.z)
	return trap


func _ready() -> void:
	_left = hold_time
	add_child(Champion.ring_mesh("Rune", radius, DeadfallAbility.COLOR, 0.85))
	var inner := Champion.ring_mesh("RuneInner", radius * 0.55, DeadfallAbility.COLOR, 0.5)
	add_child(inner)
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 32
	disc.rings = 1
	_fill = MeshInstance3D.new()
	_fill.mesh = disc
	_fill.position.y = 0.04
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var color := DeadfallAbility.COLOR
	material.albedo_color = Color(color.r, color.g, color.b, 0.22)
	_fill.material_override = material
	add_child(_fill)
	Vfx.burst(self, global_position + Vector3.UP * 0.2, color, 12, 2.0, 0.4)


## Seconds until it erupts.
func time_left() -> float:
	return maxf(_left, 0.0)


func _caught() -> Array[Health]:
	return Targeting.living_around(self, global_position, radius, target_mask)


func _physics_process(delta: float) -> void:
	_left -= delta
	var inside := _caught()
	if _left > 0.0:
		for health in inside:
			Slowed.apply(health.get_parent(), HOLD_FACTOR, CATCH_SECONDS)
		var grown := 1.0 - _left / maxf(hold_time, 0.01)
		_fill.scale = Vector3(grown, 1.0, grown)
		return
	for health in inside:
		if health.apply_damage(bolts * bolt_damage, global_position) > 0:
			erupted_on.append(health)
	var parent := get_parent()
	Vfx.ring(parent, global_position, radius, DeadfallAbility.COLOR, 0.35)
	Vfx.debris(parent, global_position + Vector3.UP * 0.2, Color(0.55, 0.5, 0.42), 6, 4.5, 0.5)
	for i in bolts:
		var angle := TAU * i / bolts
		var out := Vector3(cos(angle), 0.0, sin(angle))
		Vfx.burst(parent, global_position + out * radius * 0.5 + Vector3.UP * 0.4, DeadfallAbility.COLOR, 4, 7.0, 0.3, 0.08)
	set_physics_process(false)
	queue_free()
