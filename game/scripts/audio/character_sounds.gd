class_name CharacterSounds
extends Node
## The sounds a hero, enemy or summon makes, played from its own gameplay
## signals. Add it as a child of the body; it finds its siblings:
## - Health: being struck (`impact` plus a thud), hurt voices, the death cry;
## - each MeleeAttack (and RangedAttack): its AttackData's windup sound when
##   the attack starts (an enemy's telegraph) and swing sound when it lands;
##   a critical hit adds a crack;
## - each Ability: its `sound` when used;
## - Dodge: a rustle; EnemyController: a growl as it winds up, and earth
##   breaking as it rises.
## Sound only: it never touches the signals' outcome.

## What the body sounds like when struck (a SoundBank cue): hit_bone for
## skeletons, hit_metal for the armoured, hit_flesh for heroes.
@export var impact: StringName = &"hit_bone"
## Voice when hurt, at most every few tenths of a second (SoundBank gap).
@export var hurt: StringName
@export_range(0.0, 1.0, 0.05) var hurt_chance: float = 1.0
@export var death: StringName
## A second layer on death: bones collapsing, armour falling.
@export var death_layer: StringName
## Voice as an enemy winds up an attack, some of the time.
@export var growl: StringName
@export_range(0.0, 1.0, 0.05) var growl_chance: float = 0.35
## Heroes: a footstep every `step_length` metres walked.
@export var footsteps: StringName
@export_range(0.5, 4.0, 0.1, "suffix:m") var step_length: float = 1.8
## Scales the pitch of everything the body makes: big bodies sound deeper.
@export_range(0.3, 2.0, 0.01) var pitch: float = 1.0

var _body: Node3D
var _walked: float = 0.0
var _last_position: Vector3
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_body = get_parent() as Node3D
	if _body == null:
		return
	_last_position = _body.global_position
	for child in _body.get_children():
		if child is Health:
			var health := child as Health
			health.damaged.connect(_on_damaged.bind(health))
			health.died.connect(_on_died)
		elif child is MeleeAttack:
			var attack := child as MeleeAttack
			attack.started.connect(_on_attack_started.bind(attack).unbind(1))
			attack.struck.connect(_on_attack_struck.bind(attack))
		elif child is Ability:
			var ability := child as Ability
			ability.activated.connect(_on_ability.bind(ability))
		elif child is Dodge:
			(child as Dodge).started.connect(_play.bind(&"dodge").unbind(1))
	if _body is EnemyController:
		(_body as EnemyController).state_changed.connect(_on_state_changed)
	set_physics_process(footsteps != &"")


func _physics_process(_delta: float) -> void:
	var at := _body.global_position
	var moved := Vector2(at.x - _last_position.x, at.z - _last_position.z).length()
	_last_position = at
	# A jump (respawn, teleport) is not a stride.
	if moved > 1.0:
		return
	_walked += moved
	if _walked >= step_length:
		_walked = 0.0
		_play(footsteps)


func _play(cue: StringName, volume_db: float = 0.0) -> void:
	if cue != &"" and is_instance_valid(_body) and _body.is_inside_tree():
		Audio.play(cue, _body.global_position + Vector3.UP, pitch, volume_db)


func _on_damaged(amount: int, _remaining: int, health: Health) -> void:
	# Big blows sound bigger: up to +3 dB for a hit of a quarter of the health.
	var weight := clampf(float(amount) / maxf(health.max_health * 0.25, 1.0), 0.0, 1.0)
	_play(impact, -3.0 + weight * 6.0)
	_play(&"hit_thud", -2.0 + weight * 4.0)
	if hurt != &"" and _rng.randf() < hurt_chance and not health.is_dead():
		_play(hurt)


func _on_died() -> void:
	_play(death)
	_play(death_layer)


func _on_attack_started(attack: MeleeAttack) -> void:
	if attack.data:
		Audio.play(attack.data.windup_sound, _body.global_position + Vector3.UP, pitch * attack.data.sound_pitch)


func _on_attack_struck(targets: Array[Health], attack: MeleeAttack) -> void:
	if attack.data == null:
		return
	Audio.play(attack.data.swing_sound, _body.global_position + Vector3.UP, pitch * attack.data.sound_pitch)
	if not targets.is_empty() and attack.last_hit_critical:
		var target := targets[0].get_parent() as Node3D
		if target:
			Audio.play(&"hit_crit", target.global_position + Vector3.UP)


func _on_ability(ability: Ability) -> void:
	_play(ability.sound)


func _on_state_changed(_previous: EnemyController.State, current: EnemyController.State) -> void:
	match current:
		EnemyController.State.TELEGRAPH:
			if growl != &"" and _rng.randf() < growl_chance:
				_play(growl)
		EnemyController.State.RISING:
			_play(&"rocks_fall")
