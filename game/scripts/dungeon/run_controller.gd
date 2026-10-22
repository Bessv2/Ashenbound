class_name RunController
extends Node
## Decides how a run ends: in victory when every encounter in `encounters` is
## cleared, in defeat when the player dies. Whichever happens first stands;
## the other is ignored afterwards. Counts the run's time, kills, damage taken
## and the Ash earned (each killed enemy's `ash_value`), and pays the Ash out
## once through claim_reward().
##
## Lives in the dungeon scene, so a restart (scene reload) starts a new run
## with nothing carried over.

signal ended(victory: bool)
## An enemy of the run's encounters died while the run was on.
signal kill_counted(enemy: Node3D)

enum Result { RUNNING, VICTORY, DEFEAT }

@export var player_health: Health
@export var encounters: Array[EncounterController] = []

var result: Result = Result.RUNNING
## Seconds of play, paused time excluded.
var elapsed: float = 0.0
var kills: int = 0
var damage_taken: int = 0
## Ash and gold earned so far; a defeat keeps what was earned.
var ash: int = 0
var gold: int = 0
## Unique per run, so a reward can be claimed only once.
var run_id: String = ""


func _ready() -> void:
	run_id = "%d-%d" % [Time.get_unix_time_from_system() * 1000.0, randi()]
	if player_health:
		player_health.died.connect(_finish.bind(Result.DEFEAT))
		player_health.damaged.connect(_on_player_damaged.unbind(1))
	var listed := encounters.duplicate()
	encounters.clear()
	watch(listed)


## Adds `list` to the encounters that must be cleared to win.
func watch(list: Array[EncounterController]) -> void:
	for encounter in list:
		if encounters.has(encounter):
			continue
		encounters.append(encounter)
		encounter.cleared.connect(_on_encounter_cleared)
		encounter.enemy_killed.connect(_on_enemy_killed)


func _physics_process(delta: float) -> void:
	if result == Result.RUNNING:
		elapsed += delta


func is_over() -> bool:
	return result != Result.RUNNING


## Pays this run's Ash and gold into `profile` (the Profile autoload by default). Only
## after the run is over, and only once: returns false otherwise.
func claim_reward(profile: Node = null) -> bool:
	if result == Result.RUNNING:
		return false
	if profile == null:
		profile = get_node_or_null(^"/root/Profile")
	return profile != null and profile.grant_run_reward(run_id, ash, gold)


func _on_enemy_killed(enemy: Node3D) -> void:
	if result != Result.RUNNING:
		return
	kills += 1
	if enemy is EnemyController:
		ash += (enemy as EnemyController).ash_value
		gold += (enemy as EnemyController).gold_value
	kill_counted.emit(enemy)


func _on_player_damaged(amount: int) -> void:
	if result == Result.RUNNING:
		damage_taken += amount


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
