class_name TrainingDummy
extends StaticBody3D
## A stationary target for testing attacks. Its HitFeedback child flashes it
## and shows damage numbers; it respawns with full health some time after
## being destroyed.

@export_range(0.0, 30.0, 0.1, "suffix:s") var respawn_delay: float = 2.5

@onready var health: Health = $Health
@onready var _visual: Node3D = $Visual
@onready var _health_label: Label3D = $HealthLabel
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _respawn_left: float = 0.0


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_update_label()


func _physics_process(delta: float) -> void:
	if _respawn_left <= 0.0:
		return
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		_respawn()


func _on_damaged(_amount: int, _remaining: int) -> void:
	_update_label()


func _on_died() -> void:
	_visual.hide()
	_health_label.hide()
	# Collision changes are not allowed while physics queries run.
	_collision.set_deferred("disabled", true)
	_respawn_left = respawn_delay


func _respawn() -> void:
	health.revive()
	_visual.show()
	_health_label.show()
	_collision.set_deferred("disabled", false)
	_update_label()


func _update_label() -> void:
	_health_label.text = "%d / %d" % [health.current, health.max_health]
