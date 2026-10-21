class_name GameplayActions
extends RefCounted
## InputMap actions that drive gameplay, as opposed to UI or pausing.

const ATTACK := &"attack"
const DODGE := &"dodge"
const ALL: Array[StringName] = [
	MovementInput.LEFT, MovementInput.RIGHT, MovementInput.FORWARD, MovementInput.BACK, ATTACK, DODGE,
]


## Releases every gameplay action, whichever device pressed it.
static func release_all() -> void:
	for action in ALL:
		Input.action_release(action)
