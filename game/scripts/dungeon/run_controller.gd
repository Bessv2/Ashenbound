class_name RunController
extends Node
## Decides how a run ends: in victory when every encounter in `encounters` is
## cleared, in defeat when the player dies. Whichever happens first stands;
## the other is ignored afterwards. Counts the run's time and kills.
##
## Lives in the dungeon scene, so a restart (scene reload) starts a new run
## with nothing carried over.

signal ended(victory: bool)

enum Result { RUNNING, VICTORY, DEFEAT }

@export var player_health: Health
@export var encounters: Array[EncounterController] = []

var result: Result = Result.RUNNING
## Seconds of play, paused time excluded.
var elapsed: float = 0.0
var kills: int = 0


func _ready() -> void:
	if player_health:
		player_health.died.connect(_finish.bind(Result.DEFEAT))
	for encounter in encounters:
		encounter.cleared.connect(_on_encounter_cleared)
		encounter.enemy_killed.connect(_on_enemy_killed.unbind(1))


func _physics_process(delta: float) -> void:
	if result == Result.RUNNING:
		elapsed += delta


func is_over() -> bool:
	return result != Result.RUNNING


func _on_enemy_killed() -> void:
	if result == Result.RUNNING:
		kills += 1


func _on_encounter_cleared() -> void:
	for encounter in encounters:
		if encounter.phase != EncounterController.Phase.CLEARED:
			return
	_finish(Result.VICTORY)


func _finish(how: Result) -> void:
	if result != Result.RUNNING:
		return
	result = how
	ended.emit(how == Result.VICTORY)
