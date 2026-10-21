class_name EliteBar
extends Node3D
## A name and a health bar floating above an elite enemy, so the player can
## tell the fight is different. The node turns to face the camera every frame
## (so the bar's left edge stays put as it empties) and is drawn over the
## scene. Hidden once it is dead. Visual only.

const WIDTH := 1.6
const HEIGHT := 0.14

@export var health: Health
@export var title: String = ""

var _fill: Sprite3D
var _back: Sprite3D
var _label: Label3D


func _ready() -> void:
	var image := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var white := ImageTexture.create_from_image(image)
	_back = _sprite(white, Color(0.05, 0.03, 0.03, 0.85), 0)
	_fill = _sprite(white, Color(0.85, 0.18, 0.1), 1)
	_label = Label3D.new()
	_label.text = title
	_label.no_depth_test = true
	_label.render_priority = 2
	_label.pixel_size = 0.006
	_label.font_size = 48
	_label.outline_size = 10
	_label.modulate = Color(0.95, 0.85, 0.7)
	_label.position = Vector3(0, 0.34, 0)
	add_child(_label)
	if health:
		health.damaged.connect(_update.unbind(2))
		health.healed.connect(_update.unbind(2))
		health.died.connect(_update)
	_update()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_basis = camera.global_basis


## The share of health the bar shows, 0 to 1.
func fraction() -> float:
	return float(health.current) / health.max_health if health and health.max_health > 0 else 0.0


func _update() -> void:
	visible = health != null and not health.is_dead()
	_fill.scale.x = maxf(fraction(), 0.0)


func _sprite(texture: Texture2D, color: Color, priority: int) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.modulate = color
	sprite.centered = false
	sprite.offset = Vector2(0, -0.5)
	sprite.pixel_size = 1.0
	# 1×1 texture: the sprite's scale is its size in metres.
	sprite.scale = Vector3(WIDTH, HEIGHT, 1.0)
	sprite.position = Vector3(-WIDTH * 0.5, 0, 0)
	sprite.no_depth_test = true
	sprite.render_priority = priority
	sprite.shaded = false
	add_child(sprite)
	return sprite
