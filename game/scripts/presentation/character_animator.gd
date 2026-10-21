class_name CharacterAnimator
extends Node
## Plays a character model's animations from gameplay signals: locomotion from
## the body's speed, one-shot clips for attacks, dodges and abilities, a flinch
## on hits and a death clip. Presentation only: it reads gameplay state and
## never changes it, so combat timing stays with the gameplay nodes.
##
## One-shot clips are sped up to fit the action they show (an attack's windup
## plus recovery, a dodge's duration), within `max_speed_scale`.

@export var body: CharacterBody3D
@export var animation_player: AnimationPlayer
@export var health: Health
@export var dodge: Dodge
## Attacks and the clip each one plays, matched by index.
@export var attacks: Array[MeleeAttack] = []
@export var attack_animations: Array[StringName] = []
## Abilities that are not attacks (an attack-based ability is listed under
## `attacks`) and the clip each one plays, matched by index.
@export var abilities: Array[Ability] = []
@export var ability_animations: Array[StringName] = []

@export var idle_animation: StringName = &"Idle"
@export var run_animation: StringName = &"Running_A"
@export var hit_animation: StringName = &"Hit_A"
@export var death_animation: StringName = &"Death_A"
@export var dodge_animation: StringName = &"Dodge_Forward"
## Horizontal speed at which the run clip plays at normal speed.
@export_range(0.5, 20.0, 0.1, "suffix:m/s") var run_reference_speed: float = 5.0
## Below this horizontal speed the character idles.
@export_range(0.0, 2.0, 0.05, "suffix:m/s") var run_threshold: float = 0.4
@export_range(1.0, 5.0, 0.1) var max_speed_scale: float = 3.0
@export_range(0.0, 0.5, 0.01, "suffix:s") var blend_time: float = 0.12

## The one-shot clip playing now, or &"" while the locomotion clips run.
var action: StringName = &""
var _dead := false


func _ready() -> void:
	for clip in [idle_animation, run_animation]:
		if animation_player.has_animation(clip):
			animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animation_player.animation_finished.connect(_on_animation_finished)
	for i in mini(attacks.size(), attack_animations.size()):
		attacks[i].started.connect(_on_attack_started.bind(attacks[i], attack_animations[i]).unbind(1))
	for i in mini(abilities.size(), ability_animations.size()):
		abilities[i].activated.connect(_play_action.bind(ability_animations[i], 0.0))
	if dodge:
		dodge.started.connect(_play_action.bind(dodge_animation, dodge.data.duration if dodge.data else 0.0).unbind(1))
	if health:
		health.hit.connect(_on_hit.unbind(1))
		health.died.connect(_on_died)
		health.revived.connect(_on_revived)
	_play(idle_animation, 1.0)


func _process(_delta: float) -> void:
	if _dead or action != &"":
		return
	var speed := Vector2(body.velocity.x, body.velocity.z).length() if body else 0.0
	if speed > run_threshold:
		_play(run_animation, clampf(speed / run_reference_speed, 0.6, 1.5))
	else:
		_play(idle_animation, 1.0)


func _on_attack_started(attack: MeleeAttack, clip: StringName) -> void:
	_play_action(clip, attack.data.windup + attack.data.recovery)


## Plays `clip` once, sped up to last `fit_time` seconds when that is given.
func _play_action(clip: StringName, fit_time: float) -> void:
	if _dead or not animation_player.has_animation(clip):
		return
	var speed := 1.0
	if fit_time > 0.0:
		speed = clampf(animation_player.get_animation(clip).length / fit_time, 1.0, max_speed_scale)
	action = clip
	animation_player.play(clip, blend_time, speed)


func _on_hit() -> void:
	# A flinch never interrupts an attack, dodge or ability.
	if action == &"":
		_play_action(hit_animation, 0.0)


func _on_died() -> void:
	_dead = true
	action = death_animation
	if animation_player.has_animation(death_animation):
		animation_player.play(death_animation, blend_time)


func _on_revived() -> void:
	_dead = false
	action = &""
	_play(idle_animation, 1.0)


func _on_animation_finished(clip: StringName) -> void:
	if clip == action and not _dead:
		action = &""


## Plays a looping locomotion clip. Calling it again for the clip that is
## already playing only updates its speed; it does not restart it.
func _play(clip: StringName, speed: float) -> void:
	if animation_player.has_animation(clip):
		animation_player.play(clip, blend_time, speed)
