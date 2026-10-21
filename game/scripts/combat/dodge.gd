class_name Dodge
extends Node
## A short dash in a fixed direction that briefly makes its owner ignore damage.
##
## The owning body drives it: it calls try_start() and then step() once per
## physics tick, and moves with the velocity step() returns. The dash covers
## `data.distance` over `data.duration` at any tick rate, because the last
## tick only moves for the part of it that is still inside the dash.

## The dash started; `direction` is the flat world direction it moves in.
signal started(direction: Vector3)
## The dash ran its full duration.
signal finished
## The dash was cut short by cancel().
signal canceled

@export var data: DodgeData
## Optional. Ignores damage for `data.invulnerable_time` after each start.
@export var health: Health

## Flat world direction of the current or last dash.
var direction: Vector3 = Vector3.FORWARD

var _active: bool = false
var _elapsed: float = 0.0
var _cooldown_left: float = 0.0


func _ready() -> void:
	if data == null:
		data = DodgeData.new()


func is_active() -> bool:
	return _active


## Whether try_start() would start a dash now.
func is_ready() -> bool:
	return not _active and _cooldown_left <= 0.0


## Share of the cooldown still to run: 1 right after a start, 0 when ready.
func cooldown_fraction() -> float:
	if data.cooldown <= 0.0:
		return 0.0
	return clampf(_cooldown_left / data.cooldown, 0.0, 1.0)


## Starts a dash toward `toward` (flattened) if one is ready. Returns whether
## it started.
func try_start(toward: Vector3) -> bool:
	var flat := Vector3(toward.x, 0.0, toward.z)
	if not is_ready() or flat.is_zero_approx():
		return false
	direction = flat.normalized()
	_active = true
	_elapsed = 0.0
	_cooldown_left = data.cooldown
	_set_invulnerable(data.invulnerable_time > 0.0)
	started.emit(direction)
	return true


## Advances the dodge by one physics tick and returns the horizontal velocity
## its owner should move with during that tick: zero when no dash is running.
func step(delta: float) -> Vector3:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if not _active:
		return Vector3.ZERO
	var moving_time := minf(delta, data.duration - _elapsed)
	_elapsed += delta
	_set_invulnerable(_elapsed < data.invulnerable_time)
	var velocity := direction * (data.distance / data.duration) * (moving_time / delta)
	if _elapsed >= data.duration:
		_stop()
		finished.emit()
	return velocity


## Ends a dash in progress early. The cooldown keeps running.
func cancel() -> void:
	if _active:
		_stop()
		canceled.emit()


func _stop() -> void:
	_active = false
	_set_invulnerable(false)


func _set_invulnerable(value: bool) -> void:
	if health:
		health.invulnerable = value
