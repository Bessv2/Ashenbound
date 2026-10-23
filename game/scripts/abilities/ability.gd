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
## The colour of its HUD button's ring and flash.
@export var hud_color: Color = Color(0.95, 0.45, 0.2)
## Played when the ability is used (a SoundBank cue; CharacterSounds plays it).
@export var sound: StringName

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


## Takes the hero's final numbers (CharacterStats calls it after every
## recalculation): `stats` for skill-only stats that change this ability, and
## `damage_scale` (weapon and damage %) for its strikes. Each ability knows its
## own skill stats, so a new class needs no change in CharacterStats.
func apply_stats(_stats: CharacterStats, _damage_scale: float) -> void:
	pass


## A short count for the HUD button's badge (souls held), or "" for none.
func badge_text() -> String:
	return ""


## Ends whatever is still playing out. The cooldown keeps running.
func cancel() -> void:
	pass


## Performs the ability. Returns false if it could not take effect.
func _activate(_facing: Vector3) -> bool:
	return false
