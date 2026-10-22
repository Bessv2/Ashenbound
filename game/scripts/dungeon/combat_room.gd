class_name CombatRoom
extends Area3D
## A room that locks the player in while its encounter is fought.
##
## When the player walks into this area, `seal_gates` close and `encounter`
## starts. When the encounter is cleared, `seal_gates` and `exit_gates` open
## and the player recovers `heal_on_clear` health. Each happens once.
##
## Give the area a CollisionShape3D that covers the room from 2 m past its
## entrance, so the door does not close on the player.

signal sealed
signal cleared

const PLAYER_LAYER := 2

@export var encounter: EncounterController
@export var seal_gates: Array[CryptGate] = []
@export var exit_gates: Array[CryptGate] = []
@export_range(0, 1000, 1) var heal_on_clear: int = 30

var _player: PlayerController


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitorable = false
	body_entered.connect(_on_body_entered)
	if encounter:
		encounter.cleared.connect(_on_encounter_cleared)
	else:
		push_error("%s has no encounter to start." % name)


func is_sealed() -> bool:
	return encounter != null and encounter.phase == EncounterController.Phase.ACTIVE


func _on_body_entered(body: Node3D) -> void:
	if not body is PlayerController or encounter == null:
		return
	if encounter.phase != EncounterController.Phase.WAITING:
		return
	_player = body
	for gate in seal_gates:
		gate.open = false
	sealed.emit()
	encounter.start()


func _on_encounter_cleared() -> void:
	for gate in seal_gates + exit_gates:
		gate.open = true
	if _player and is_instance_valid(_player):
		_player.health.heal(heal_on_clear)
	cleared.emit()
