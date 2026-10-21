class_name TrainingDummy
extends StaticBody3D
## A stationary target for testing attacks. Flashes and shows damage numbers
## when hit, and respawns with full health some time after being destroyed.

@export_range(0.0, 30.0, 0.1, "suffix:s") var respawn_delay: float = 2.5
@export var hit_flash: Material

@onready var health: Health = $Health
@onready var _visual: Node3D = $Visual
@onready var _health_label: Label3D = $HealthLabel
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _respawn_left: float = 0.0
var _flash_tween: Tween


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


func _on_damaged(amount: int, _remaining: int) -> void:
	_update_label()
	DamageNumber.spawn(self, amount, 2.6)
	_set_flash(hit_flash)
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_flash_tween.tween_interval(0.08)
	_flash_tween.tween_callback(_set_flash.bind(null))


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


func _set_flash(material: Material) -> void:
	for mesh in _visual.get_children():
		if mesh is GeometryInstance3D:
			mesh.material_overlay = material


func _update_label() -> void:
	_health_label.text = "%d / %d" % [health.current, health.max_health]
