class_name VeilRendAbility
extends Ability
## Veil Rend (the Reaver's signature, docs/characters/reaver.md): a short dash
## along the facing, unhurt while it lasts. When it ends, every enemy within
## `width` of the path actually travelled (walls stop it) takes one hit and is
## Marked: it takes more damage for a few seconds. It always activates, so it
## doubles as an escape. The dash passes through enemies (not walls).

@export_range(1.0, 15.0, 0.1, "suffix:m") var distance: float = 6.0
@export_range(0.05, 1.0, 0.01, "suffix:s") var seconds: float = 0.18
@export_range(1, 1000, 1) var damage: int = 14
## How far from the path an enemy can be and still be cut.
@export_range(0.2, 5.0, 0.1, "suffix:m") var width: float = 1.2
@export_range(0.0, 2.0, 0.01) var mark_bonus: float = 0.25
@export_range(0.1, 30.0, 0.1, "suffix:s") var mark_seconds: float = 4.0
## Physics layers that can be cut (default: layer 3, "enemy").
@export_flags_3d_physics var target_mask: int = 4

## The enemies cut by the last dash.
var last_hits: Array[Health] = []

var _left: float = 0.0
var _direction: Vector3 = Vector3.ZERO
var _start: Vector3 = Vector3.ZERO
var _scale: float = 1.0
var _bonus_scale: float = 0.0
## The body's collision mask before the dash (it passes through enemies).
var _mask: int = 0


## Skills: Veil Rend Mastery (veil_rend_damage_pct), Mark for Death
## (mark_damage_pct, added to the mark), Phantom Step (dash_cooldown_pct).
func apply_stats(stats: CharacterStats, damage_scale: float) -> void:
	_scale = damage_scale * (1.0 + stats.value("veil_rend_damage_pct") / 100.0)
	_bonus_scale = stats.value("mark_damage_pct") / 100.0
	cooldown_scale *= 1.0 - stats.value("dash_cooldown_pct") / 100.0


func is_busy() -> bool:
	return _left > 0.0


func facing() -> Vector3:
	return _direction if is_busy() else Vector3.ZERO


func cancel() -> void:
	if _left > 0.0:
		_left = 0.0
		_end_protection()


func _physics_process(delta: float) -> void:
	super(delta)
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		_end_protection()
		_cut()


func _activate(toward: Vector3) -> bool:
	var body := _body()
	if body == null or toward.is_zero_approx():
		return false
	_direction = Vector3(toward.x, 0.0, toward.z).normalized()
	_start = body.global_position
	_left = seconds
	last_hits.clear()
	body.push(_direction * distance, seconds)
	_mask = body.collision_mask
	body.collision_mask = _mask & ~target_mask
	if body.health:
		body.health.invulnerable = true
	return true


## Damages and marks every living enemy along the path from the start to
## where the dash ended.
func _cut() -> void:
	var body := _body()
	var end := body.global_position
	var path := Vector3(end.x - _start.x, 0.0, end.z - _start.z)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width * 2.0, 2.0, path.length() + width * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = target_mask
	var middle := (_start + end) / 2.0 + Vector3.UP
	var yaw := MovementStats.yaw_of(path.normalized() if path.length() > 0.01 else _direction)
	query.transform = Transform3D(Basis(Vector3.UP, yaw), middle)
	for found in body.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var health := Health.of(found.collider)
		if health == null or health.is_dead() or last_hits.has(health):
			continue
		last_hits.append(health)
		# The cut lands first; the mark sets up the follow-up.
		health.apply_damage(maxi(roundi(damage * _scale), 1), _start)
		Marked.apply(health, mark_bonus + _bonus_scale, mark_seconds)


func _end_protection() -> void:
	var body := _body()
	if body and _mask != 0:
		body.collision_mask = _mask
		_mask = 0
	# A dodge that cancelled the dash keeps its own invulnerable window.
	if body and body.health and not (body.dodge and body.dodge.is_active()):
		body.health.invulnerable = false


func _body() -> PlayerController:
	return get_parent() as PlayerController
