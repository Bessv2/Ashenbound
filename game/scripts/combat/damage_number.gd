class_name DamageNumber
extends Label3D
## A short-lived number that floats up from where damage landed.

const RISE := 0.9
const DURATION := 0.75
const DEFAULT_COLOR := Color(1.0, 0.82, 0.55)


## Spawns a number above `parent`'s origin at `height` meters.
static func spawn(parent: Node3D, amount: int, height: float,
		color: Color = DEFAULT_COLOR) -> DamageNumber:
	var number := DamageNumber.new()
	number.text = str(amount)
	# A little to the side, so numbers in quick succession do not stack.
	number.position = Vector3(randf_range(-0.35, 0.35), height, randf_range(-0.2, 0.2))
	number.modulate = color
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test = true
	# Bigger hits read bigger.
	number.font_size = 56 + mini(amount, 60)
	number.pixel_size = 0.01
	number.outline_size = 18
	number.outline_modulate = Color(0.05, 0.02, 0.02, 0.9)
	parent.add_child(number)
	return number


func _ready() -> void:
	# Runs on the physics clock so physics interpolation smooths it, and
	# pauses with the game. Pops in, floats up and drifts, then fades.
	scale = Vector3.ONE * 0.35
	var drift := position.x * 0.8
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(self, "scale", Vector3.ONE * 1.25, DURATION * 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, DURATION * 0.25).set_delay(DURATION * 0.18)
	tween.tween_property(self, "position:y", position.y + RISE, DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", position.x + drift, DURATION)
	# Fade over the last 60%, so the whole animation lasts DURATION.
	tween.tween_property(self, "modulate:a", 0.0, DURATION * 0.6).set_delay(DURATION * 0.4)
	tween.chain().tween_callback(queue_free)
