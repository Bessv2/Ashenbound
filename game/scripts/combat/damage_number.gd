class_name DamageNumber
extends Label3D
## A short-lived number that floats up from where damage landed.

const RISE := 0.9
const DURATION := 0.6


## Spawns a number above `parent`'s origin at `height` meters.
static func spawn(parent: Node3D, amount: int, height: float) -> DamageNumber:
	var number := DamageNumber.new()
	number.text = str(amount)
	number.position = Vector3(0.0, height, 0.0)
	parent.add_child(number)
	return number


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	font_size = 64
	pixel_size = 0.01
	outline_size = 16
	modulate = Color(1.0, 0.82, 0.55)
	# Runs on the physics clock so physics interpolation smooths it, and
	# pauses with the game.
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(self, "position:y", position.y + RISE, DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, DURATION).set_delay(DURATION * 0.4)
	tween.chain().tween_callback(queue_free)
