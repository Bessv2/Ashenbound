class_name Ability
extends Node
## An active ability with a cooldown, started by its owner on an InputMap
## action. Subclasses implement _activate() and, when the ability plays out
## over time, is_busy(), movement_multiplier(), facing() and cancel().
##
## The cooldown starts when the ability activates and runs on the physics
## clock, so it pauses with the game. An ability that cannot take effect
## (no target, say) does not activate and does not spend its cooldown.

signal activated

## Shown on the HUD button.
@export var display_name: String = ""
## The InputMap action that starts it.
@export var action: StringName
@export_range(0.0, 120.0, 0.05, "suffix:s") var cooldown: float = 1.0

## Scales the cooldown spent from now on (cooldown reduction on gear).
var cooldown_scale: float = 1.0
## Scales the damage the ability deals (damage % on gear).
var power: float = 1.0

var _cooldown_left: float = 0.0


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func is_ready() -> bool:
	return _cooldown_left <= 0.0 and not is_busy()


## Share of the cooldown still to run: 1 right after activation, 0 when ready.
func cooldown_fraction() -> float:
	var full := cooldown * cooldown_scale
	return clampf(_cooldown_left / full, 0.0, 1.0) if full > 0.0 else 0.0


## Activates the ability if it is ready and can take effect. `facing` is the
## owner's flat facing direction. Returns whether it activated.
func try_activate(facing: Vector3) -> bool:
	if not is_ready() or not _activate(facing):
		return false
	_cooldown_left = cooldown * cooldown_scale
	activated.emit()
	return true


## Whether the ability is still playing out. While busy, the owner starts no
## other ability or basic attack.
func is_busy() -> bool:
	return false


## Speed factor the owner should apply while the ability is busy.
func movement_multiplier() -> float:
	return 1.0


## The flat direction the owner should face while busy, or zero to leave the
## facing alone.
func facing() -> Vector3:
	return Vector3.ZERO


## Ends whatever is still playing out. The cooldown keeps running.
func cancel() -> void:
	pass


## Performs the ability. Returns false if it could not take effect.
func _activate(_facing: Vector3) -> bool:
	return false
