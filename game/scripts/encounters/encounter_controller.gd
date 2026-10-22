class_name EncounterController
extends Node3D
## Runs one encounter. Spawns its waves in order at the Marker3D children the
## data names, starts the next wave `wave_delay` after every enemy of the
## current one has died, and reports when the last wave is dead.
##
## Spawned enemies become its children, hunt the player wherever it is, and
## rise out of the ground first (see EnemyController.rise()). A wave counts an
## enemy as gone when its Health dies, not when its corpse is removed.

signal started
signal wave_started(index: int)
signal enemy_killed(enemy: Node3D)
## One of its enemies rose as a Champion.
signal champion_spawned(enemy: EnemyController)
signal cleared

enum Phase { WAITING, ACTIVE, CLEARED }

@export var data: EncounterData
## Starts by itself `start_delay` seconds after entering the tree. When false,
## something else calls start() (a room trigger).
@export var auto_start: bool = false
## Shown as a banner when the encounter starts (empty: no banner).
@export var title: String = ""
@export var subtitle: String = ""
## The banner's colour (a boss's is red).
@export var title_color: Color = Color("#E8D9C0")
@export_range(0.0, 30.0, 0.1, "suffix:s") var start_delay: float = 1.5

var phase: Phase = Phase.WAITING
## The crypt tier its enemies are scaled to (set by Main); null is tier 1.
var difficulty: Difficulty
## The wave being fought (0-based), or -1 before the first.
var wave: int = -1

var _living: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _start_left: float = 0.0
var _next_wave_left: float = -1.0


func _ready() -> void:
	_start_left = start_delay


func _physics_process(delta: float) -> void:
	if phase == Phase.WAITING and auto_start:
		_start_left -= delta
		if _start_left <= 0.0:
			start()
	elif phase == Phase.ACTIVE and _next_wave_left >= 0.0:
		_next_wave_left -= delta
		if _next_wave_left < 0.0:
			_begin_wave(wave + 1)


func start() -> void:
	if phase != Phase.WAITING or data == null or data.waves.is_empty():
		return
	phase = Phase.ACTIVE
	started.emit()
	_begin_wave(0)


## The enemies of the current wave that are still alive.
func living_enemies() -> Array[Node3D]:
	return _living.duplicate()


func _begin_wave(index: int) -> void:
	wave = index
	_next_wave_left = -1.0
	var wave_data := data.waves[index]
	for i in wave_data.enemies.size():
		var marker_name := wave_data.markers[i] if i < wave_data.markers.size() else ""
		_spawn(wave_data.enemies[i], marker_name)
	wave_started.emit(index)


## Makes `enemy` (already in the tree, e.g. summoned by a boss) part of the
## current wave: the wave and the encounter are not over until it dies too.
func adopt(enemy: Node3D) -> void:
	if phase != Phase.ACTIVE or _living.has(enemy):
		return
	var health := Health.of(enemy)
	if health == null or health.is_dead():
		return
	if difficulty:
		difficulty.apply(enemy)
	health.died.connect(_on_enemy_died.bind(enemy), CONNECT_ONE_SHOT)
	_living.append(enemy)


func _spawn(scene: PackedScene, marker_name: String) -> void:
	var marker := get_node_or_null(marker_name) as Marker3D
	if marker == null:
		push_error("%s: no spawn marker named '%s'." % [name, marker_name])
		return
	var enemy := scene.instantiate() as Node3D
	# Positioned before entering the tree so physics interpolation starts there.
	enemy.position = marker.position
	if enemy is EnemyController:
		(enemy as EnemyController).hunting = true
	if difficulty:
		difficulty.apply(enemy)
	var champion := _maybe_promote(enemy)
	add_child(enemy)
	if enemy is EnemyController:
		(enemy as EnemyController).rise(data.rise_time)
	if champion:
		champion_spawned.emit(enemy)
	var health := Health.of(enemy)
	if health == null:
		push_error("%s: %s has no Health and could never be defeated." % [name, enemy.name])
		return
	health.died.connect(_on_enemy_died.bind(enemy), CONNECT_ONE_SHOT)
	_living.append(enemy)


## Raises `enemy` as a Champion at the tier's chance, when it may be one.
## Without a difficulty (a bare encounter in a test), none are.
func _maybe_promote(enemy: Node3D) -> Champion:
	if difficulty == null or not enemy is EnemyController or not (enemy as EnemyController).champion_eligible:
		return null
	if _rng.randf() >= difficulty.champion_chance():
		return null
	var controller := enemy as EnemyController
	return Champion.promote(controller, Champion.roll(controller, difficulty.champion_affix_count(), _rng))


func _on_enemy_died(enemy: Node3D) -> void:
	_living.erase(enemy)
	enemy_killed.emit(enemy)
	if not _living.is_empty():
		return
	if wave + 1 < data.waves.size():
		_next_wave_left = data.wave_delay
	else:
		phase = Phase.CLEARED
		cleared.emit()
