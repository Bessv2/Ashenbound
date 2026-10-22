class_name ChargedShotAbility
extends Ability
## Charged Shot (the Dreadhunter, Precision): draws for `draw_time`, nearly
## standing still, then looses a bolt that pierces everything in a line `reach`
## long and `half_width` to either side, stopping at the first wall. Every
## enemy in the line takes `damage` once. Aimed at the nearest enemy within
## `reach` when there is one, else along the hero's facing. Always activates;
## a dodge during the draw cancels the shot.
##
## The tracer is presentation; the damage is dealt once, here, through Health.

const COLOR := Color(1.0, 0.78, 0.35)
const WORLD_LAYER := 1

@export_range(0.0, 3.0, 0.05, "suffix:s") var draw_time: float = 0.5
@export_range(1.0, 40.0, 0.5, "suffix:m") var reach: float = 18.0
@export_range(0.1, 3.0, 0.05, "suffix:m") var half_width: float = 0.6
@export_range(0, 1000, 1) var damage: int = 24
@export_flags_3d_physics var target_mask: int = 4

## The bodies the last shot hit.
var last_hit: Array[Health] = []
## Flat world direction of the shot being drawn, or of the last one.
var direction: Vector3 = Vector3.FORWARD

var _draw_left: float = 0.0
var _scale: float = 1.0


## Skills: Drawn Shaft and Piercing Volley (charged_shot_damage_pct). Its
## damage also scales with the weapon and damage %, like the basic attack.
func apply_stats(stats: CharacterStats, damage_scale: float) -> void:
	_scale = damage_scale * (1.0 + stats.value("charged_shot_damage_pct") / 100.0)


## Damage the shot deals to each enemy in its line.
func shot_damage() -> int:
	return maxi(roundi(damage * _scale), 1)


func _physics_process(delta: float) -> void:
	super(delta)
	if _draw_left <= 0.0:
		return
	_draw_left -= delta
	if _draw_left <= 0.0:
		_loose()


func is_busy() -> bool:
	return _draw_left > 0.0


func movement_multiplier() -> float:
	return 0.15


func facing() -> Vector3:
	return direction


func cancel() -> void:
	_draw_left = 0.0


func _activate(toward: Vector3) -> bool:
	var archer := get_parent() as Node3D
	var target := Targeting.nearest_living(archer, reach, target_mask)
	if target:
		var offset := (target.get_parent() as Node3D).global_position - archer.global_position
		direction = Vector3(offset.x, 0.0, offset.z).normalized()
	elif not toward.is_zero_approx():
		direction = Vector3(toward.x, 0.0, toward.z).normalized()
	last_hit = []
	_draw_left = draw_time
	if draw_time <= 0.0:
		_loose()
	return true


## How far the shot flies before a wall stops it.
func _length(from: Vector3) -> float:
	var chest := Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from + chest, from + chest + direction * reach, WORLD_LAYER)
	var wall := (get_parent() as Node3D).get_world_3d().direct_space_state.intersect_ray(query)
	return reach if wall.is_empty() else (wall.position - (from + chest)).length()


func _loose() -> void:
	_draw_left = 0.0
	var archer := get_parent() as Node3D
	var from := archer.global_position
	var length := _length(from)
	for health in Targeting.living_within(archer, length + half_width, target_mask):
		var offset := (health.get_parent() as Node3D).global_position - from
		offset.y = 0.0
		var along := offset.dot(direction)
		var aside := (offset - direction * along).length()
		if along >= 0.0 and along <= length and aside <= half_width + 0.4:
			if health.apply_damage(shot_damage(), from) > 0:
				last_hit.append(health)
	if archer.get_parent():
		_tracer(archer.get_parent(), from, length)


## A glowing streak along the shot that fades in 0.25 s.
func _tracer(parent: Node, from: Vector3, length: float) -> void:
	var streak := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, length)
	streak.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = COLOR
	streak.material_override = material
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(streak)
	streak.global_position = from + Vector3.UP * 1.0 + direction * length * 0.5
	streak.rotation.y = MovementStats.yaw_of(direction)
	var tween := streak.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.25).from(1.0)
	tween.tween_callback(streak.queue_free)
	for health in last_hit:
		Vfx.burst(parent, (health.get_parent() as Node3D).global_position + Vector3.UP, COLOR, 10, 4.0, 0.3)
