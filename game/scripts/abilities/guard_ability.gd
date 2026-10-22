class_name GuardAbility
extends Ability
## Bulwark Guard: for `duration`, damage to `health` is scaled by
## `damage_multiplier` and the owner stands still. The first hit taken during
## a guard triggers `counter`, a MeleeAttack around the owner, once.
##
## The mitigation itself lives in Health; this only switches it on and off.

## Started on the first hit of each guard. Use zero windup to answer at once.
@export var counter: MeleeAttack
@export var health: Health
@export_range(0.05, 10.0, 0.05, "suffix:s") var duration: float = 1.0
@export_range(0.0, 1.0, 0.05) var damage_multiplier: float = 0.2
## Shown while the guard is up. Visual only.
@export var visual: Node3D

var _guard_left: float = 0.0
var _countered: bool = false


var _base_duration: float = 0.0


func _ready() -> void:
	_base_duration = duration
	health.hit.connect(_on_hit)
	if visual:
		visual.hide()


## Skills: Shield Wall (GUARD_DURATION_MS) and Retribution
## (COUNTER_DAMAGE_PCT).
func apply_stats(stats: CharacterStats, damage_scale: float) -> void:
	duration = _base_duration + stats.value(SkillStats.GUARD_DURATION_MS) / 1000.0
	if counter:
		counter.damage_scale = damage_scale * (1.0 + stats.value(SkillStats.COUNTER_DAMAGE_PCT) / 100.0)


func _physics_process(delta: float) -> void:
	super(delta)
	if _guard_left <= 0.0:
		return
	_guard_left -= delta
	if _guard_left <= 0.0:
		_lower()


func is_guarding() -> bool:
	return _guard_left > 0.0


func is_busy() -> bool:
	return is_guarding() or counter.is_busy()


func movement_multiplier() -> float:
	return 0.0


func cancel() -> void:
	if is_guarding():
		_lower()
	counter.cancel()


func _activate(_toward: Vector3) -> bool:
	_guard_left = duration
	_countered = false
	health.damage_multiplier = damage_multiplier
	if visual:
		visual.show()
	return true


func _lower() -> void:
	_guard_left = 0.0
	health.damage_multiplier = 1.0
	if visual:
		visual.hide()


func _on_hit(_amount: int) -> void:
	if is_guarding() and not _countered:
		_countered = true
		# All around the owner, so the direction does not matter.
		counter.try_start(Vector3.FORWARD)
