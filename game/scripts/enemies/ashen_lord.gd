class_name AshenLord
extends EnemyController
## A boss: an EnemyController with three phases on top. The Ashen Lord
## (docs/dungeons/ashen_crypt.md) and the Hollow King
## (docs/dungeons/forgotten_catacombs.md) are both this script with their own
## attacks, data and adds:
##
## 1. From full health: Cinder Cleave (`attack`), and Ash Slam
##    (`slam_attack`) when the player stands close.
## 2. At `phase_two_at` of its health: roars (an inert, invulnerable pause,
##    like rising), summons `summon_count` adds at `summon_points` once, and
##    adds the Ember Ring (`special_attack`) every third attack.
## 3. At `phase_three_at`: roars again, winds up `phase_three_windup_scale`
##    as long and moves `phase_three_speed_scale` as fast; the Ember Ring
##    every other attack.
##
## Each phase starts exactly once and in order, even when one hit crosses
## both thresholds. The adds belong to the encounter that spawned the Lord
## (EncounterController.adopt) and die with him.

signal phase_changed(phase: int)
signal summoned(adds: Array[Node3D])

## Its name on the boss bar.
@export var display_title: String = "THE ASHEN LORD"

@export var slam_attack: MeleeAttack
## The player is close enough for the slam within this distance.
@export_range(0.5, 10.0, 0.1, "suffix:m") var slam_range: float = 3.0
@export_range(0.0, 1.0, 0.01) var phase_two_at: float = 0.6
@export_range(0.0, 1.0, 0.01) var phase_three_at: float = 0.3
@export_range(0.0, 10.0, 0.1, "suffix:s") var roar_seconds: float = 2.0
@export var add_scene: PackedScene
@export_range(0, 10, 1) var summon_count: int = 3
## Where the adds rise. When empty, the Marker3D siblings whose names start
## with "Summon" (markers of the encounter that spawned the Lord).
@export var summon_points: Array[Node3D] = []
@export var phase_three_windup_scale: float = 0.75
@export var phase_three_speed_scale: float = 1.3
## Played while it roars; the intro rise keeps the Animator's own clip.
@export var roar_animation: StringName = &"Spellcast_Raise"
@export var animator: CharacterAnimator

## 1, 2 or 3.
var phase: int = 1
## The adds summoned, alive or not.
var adds: Array[Node3D] = []

var _last_was_slam: bool = false


func _ready() -> void:
	super()
	add_to_group(&"boss")
	if summon_points.is_empty() and get_parent():
		for sibling in get_parent().get_children():
			if sibling is Marker3D and String(sibling.name).begins_with("Summon"):
				summon_points.append(sibling)
	health.damaged.connect(_on_damaged.unbind(2))
	health.died.connect(_on_lord_died)
	if slam_attack:
		slam_attack.struck.connect(_on_attack_struck.unbind(1))


func _physics_process(delta: float) -> void:
	# A phase waiting for the roar in progress to end starts right after it.
	if state != State.RISING and state != State.DEAD and phase < _phase_for_health():
		_enter_phase(phase + 1)
	super(delta)


func _next_attack() -> MeleeAttack:
	var target := _living_target()
	var every := 3 if phase == 2 else 2
	if phase >= 2 and special_attack and (attacks_started + 1) % every == 0:
		_last_was_slam = false
		return special_attack
	if slam_attack and target and _distance_to(target) <= slam_range and not _last_was_slam:
		_last_was_slam = true
		return slam_attack
	_last_was_slam = false
	return attack


## The phase the Lord's health calls for.
func _phase_for_health() -> int:
	var fraction := float(health.current) / health.max_health
	if fraction <= phase_three_at:
		return 3
	if fraction <= phase_two_at:
		return 2
	return 1


func _on_damaged() -> void:
	# A killing blow ends the fight; it starts no phase.
	if health.is_dead():
		return
	if state != State.RISING and state != State.DEAD and phase < _phase_for_health():
		_enter_phase(phase + 1)


func _enter_phase(next: int) -> void:
	phase = next
	for each in [attack, slam_attack, special_attack]:
		if each:
			(each as MeleeAttack).cancel()
	if animator:
		animator.rise_animation = roar_animation
	rise(roar_seconds)
	if next == 2:
		_summon()
	elif next == 3:
		speed_multiplier = phase_three_speed_scale
		for each in [attack, slam_attack, special_attack]:
			if each:
				(each as MeleeAttack).windup_scale = phase_three_windup_scale
	phase_changed.emit(next)


func _summon() -> void:
	if add_scene == null:
		return
	var encounter := get_parent() as EncounterController
	var spawned: Array[Node3D] = []
	for i in summon_count:
		var add := add_scene.instantiate() as Node3D
		var point: Node3D = summon_points[i % summon_points.size()] if not summon_points.is_empty() else self
		add.position = get_parent_node_3d().to_local(point.global_position)
		add.position.y = position.y
		if add is EnemyController:
			(add as EnemyController).hunting = true
		add_sibling(add)
		if add is EnemyController:
			(add as EnemyController).rise(roar_seconds * 0.5)
		if encounter:
			encounter.adopt(add)
		spawned.append(add)
		adds.append(add)
	summoned.emit(spawned)


func _on_lord_died() -> void:
	if slam_attack:
		slam_attack.cancel()
	for add in adds:
		if is_instance_valid(add):
			var add_health := Health.of(add)
			if add_health and not add_health.is_dead():
				add_health.invulnerable = false
				add_health.apply_damage(add_health.current)
