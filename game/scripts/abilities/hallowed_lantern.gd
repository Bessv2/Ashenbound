class_name HallowedLantern
extends Node3D
## The lantern a LanternAbility sets: pulses for its lifetime, then goes. Each
## pulse deals damage and heals through Health; the lantern, its light and
## its rings are presentation.

var ability: LanternAbility
var hero_health: Health
## Pulses so far.
var pulses: int = 0

var _life_left: float = 0.0
var _pulse_left: float = 0.0


func _ready() -> void:
	_life_left = ability.lifetime
	_pulse_left = ability.pulse_interval
	add_child(Champion.ring_mesh("Edge", ability.radius, LanternAbility.COLOR, 0.55))
	var lamp := MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.16
	body.bottom_radius = 0.22
	body.height = 0.5
	lamp.mesh = body
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_color = LanternAbility.COLOR
	glass.emission_enabled = true
	glass.emission = LanternAbility.COLOR
	glass.emission_energy_multiplier = 3.0
	lamp.material_override = glass
	lamp.position.y = 0.6
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamp)
	var light := OmniLight3D.new()
	light.light_color = LanternAbility.COLOR
	light.light_energy = 2.0
	light.omni_range = ability.radius + 1.5
	light.position.y = 1.0
	add_child(light)


func _physics_process(delta: float) -> void:
	_life_left -= delta
	_pulse_left -= delta
	while _pulse_left <= 0.0 and _life_left > -0.0001:
		_pulse_left += ability.pulse_interval
		_pulse()
	if _life_left <= 0.0:
		set_physics_process(false)
		queue_free()


func _pulse() -> void:
	pulses += 1
	for target in Targeting.living_around(self, global_position, ability.radius, ability.target_mask):
		target.apply_damage(ability.pulse_damage(), global_position)
	if hero_health and not hero_health.is_dead():
		var hero := hero_health.get_parent() as Node3D
		var offset := hero.global_position - global_position
		if Vector2(offset.x, offset.z).length() <= ability.radius:
			hero_health.heal(ability.pulse_heal())
	Vfx.ring(get_parent(), global_position, ability.radius, LanternAbility.COLOR, 0.4)
