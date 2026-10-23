class_name Minion
extends CharacterBody3D
## A risen skeleton serving the Gravecaller (Raise the Forsaken; docs/
## characters/gravecaller.md). It fights the enemy nearest to it within
## `reach` of itself, follows the hero when there is none, and crumbles when
## its time runs out, when its Health is spent, or when the hero dies.
##
## Collision: it stands on the player layer, so enemies body-block on it and
## their swings, bolts and rings can hit it, but enemies never choose it as
## a target, and the hero walks through it. It plans no paths (it steers
## straight), and it is a top-level child of the hero, so it goes with the
## hero and never outlives the run.

const FOLLOW_DISTANCE := 2.5
const COLOR := Color(0.35, 1.0, 0.8)

@export var movement: MovementStats
@export var attack: MeleeAttack
@export var health: Health
@export var visual: Node3D
@export_range(1.0, 30.0, 0.5, "suffix:m") var reach: float = 10.0
@export_range(0.5, 4.0, 0.1, "suffix:m") var attack_range: float = 1.5

## The hero it serves.
var hero: PlayerController
var lifetime: float = 15.0

var _life_left: float = 0.0
var _gone: bool = false


func _ready() -> void:
	top_level = true
	_life_left = lifetime
	health.died.connect(crumble)


## Seconds it has left.
func time_left() -> float:
	return maxf(_life_left, 0.0)


func _physics_process(delta: float) -> void:
	if _gone:
		return
	_life_left -= delta
	if _life_left <= 0.0 or hero == null or not is_instance_valid(hero) or not hero.is_alive():
		crumble()
		return
	var desired := Vector3.ZERO
	var target := Targeting.nearest_living(self, reach, attack.target_mask)
	if target:
		var offset := (target.get_parent() as Node3D).global_position - global_position
		offset.y = 0.0
		if offset.length() <= attack_range:
			if not attack.is_busy():
				attack.try_start(offset.normalized())
		elif not attack.is_busy():
			desired = offset.normalized() * movement.move_speed
	else:
		var to_hero := hero.global_position - global_position
		to_hero.y = 0.0
		if to_hero.length() > FOLLOW_DISTANCE:
			desired = to_hero.normalized() * movement.move_speed
	var horizontal := movement.step_velocity(Vector3(velocity.x, 0.0, velocity.z), desired, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	if visual:
		if attack.is_busy():
			visual.rotation.y = MovementStats.yaw_of(attack.direction)
		else:
			movement.turn_toward(visual, desired, delta)


## Falls apart in a burst of soul-fire and is gone. Once.
func crumble() -> void:
	if _gone:
		return
	_gone = true
	attack.cancel()
	if get_parent():
		Vfx.burst(get_parent(), global_position + Vector3.UP, COLOR, 14, 3.0, 0.5)
		Vfx.smoke(get_parent(), global_position + Vector3.UP * 0.6, COLOR.darkened(0.4), 4, 1.2, 0.9)
		Audio.play(&"bones_collapse", global_position + Vector3.UP, 1.1)
	queue_free()


func is_gone() -> bool:
	return _gone
