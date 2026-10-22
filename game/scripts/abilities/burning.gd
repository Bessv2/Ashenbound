class_name Burning
extends Node3D
## A burn on a body: `damage` to its Health every `interval`, `ticks` times,
## the first tick one interval after it is applied. Applying it again to a
## burning body restarts the count instead of adding a second burn.
##
## The ember mark it shows above the body is visual only; the damage comes
## from the ticks, through Health.

const MARK_HEIGHT := 2.4
const MARK_COLOR := Color(1.0, 0.45, 0.12)

var damage: int = 4
var interval: float = 0.5
var ticks_left: int = 0

var _health: Health
var _until_tick: float = 0.0


## Burns `target`'s body, or restarts the burn already on it. Returns the burn.
## `effect` names the kind of damage over time (a bleed is another effect, so
## it does not replace a burn); `color` tints its mark.
static func apply(target: Health, damage_per_tick: int, tick_interval: float, tick_count: int,
		effect: String = "Burning", color: Color = MARK_COLOR) -> Burning:
	var body := target.get_parent()
	var burn: Burning = null
	for child in body.get_children():
		if child is Burning and child.name == effect:
			burn = child
	if burn == null:
		burn = Burning.new()
		burn.name = effect
		burn._health = target
		burn.add_child(_build_mark(color))
		body.add_child(burn)
	burn.damage = damage_per_tick
	burn.interval = tick_interval
	burn.ticks_left = tick_count
	burn._until_tick = tick_interval
	return burn


func _physics_process(delta: float) -> void:
	_until_tick -= delta
	# Leftover time carries into the next tick, so the rate does not depend
	# on the physics tick rate.
	while _until_tick <= 0.0 and ticks_left > 0:
		ticks_left -= 1
		_until_tick += interval
		if _health.is_dead():
			ticks_left = 0
		else:
			_health.apply_damage(damage)
	if ticks_left <= 0 or _health.is_dead():
		queue_free()


static func _build_mark(color: Color) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	sphere.radial_segments = 10
	sphere.rings = 5
	mark.mesh = sphere
	mark.position.y = MARK_HEIGHT
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	mark.material_override = material
	return mark
