class_name GameplayActions
extends RefCounted
## InputMap actions that drive gameplay, as opposed to UI or pausing.

const ATTACK := &"attack"
const DODGE := &"dodge"
const ABILITY_1 := &"ability_1"
const ABILITY_2 := &"ability_2"
const ABILITY_3 := &"ability_3"
const ALL: Array[StringName] = [
	MovementInput.LEFT, MovementInput.RIGHT, MovementInput.FORWARD, MovementInput.BACK,
	ATTACK, DODGE, ABILITY_1, ABILITY_2, ABILITY_3,
]


## Releases every gameplay action, whichever device pressed it.
static func release_all() -> void:
	for action in ALL:
		Input.action_release(action)
