class_name CryptGate
extends Node3D
## A doorway with a door that seals a room. Fills the 4 m gap a CryptRoom
## leaves in a wall: stone frame posts on either side and a 2 m door between.
##
## A closed door blocks bodies (it is on the world physics layer) and the
## navigation mesh: changing the door asks the enclosing BakedNavigationRegion
## to bake again, so paths never lead through a closed door. The door swings
## open as a visual only; whether it blocks is decided the moment it changes.

signal changed(open: bool)

const SWING_SECONDS := 0.5
## How far the open door turns, away from the side it is seen from.
const OPEN_ANGLE := deg_to_rad(100.0)
const WORLD_LAYER := 1

@export var open: bool = false:
	set = set_open

@onready var _door_body: StaticBody3D = $DoorBody
@onready var _door_visual: Node3D = $Model/wall_doorway/wall_doorway_door

var _swing: Tween


func _ready() -> void:
	_apply(false)


func set_open(value: bool) -> void:
	if value == open:
		return
	open = value
	if is_node_ready():
		_apply(true)
		changed.emit(open)


func _apply(animate: bool) -> void:
	_door_body.collision_layer = 0 if open else WORLD_LAYER
	var angle := OPEN_ANGLE if open else 0.0
	if _swing:
		_swing.kill()
	if animate:
		_swing = create_tween()
		_swing.tween_property(_door_visual, "rotation:y", angle, SWING_SECONDS) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_door_visual.rotation.y = angle
	var region := _navigation_region()
	if region and region.is_node_ready():
		region.request_rebake()


func _navigation_region() -> BakedNavigationRegion:
	var node := get_parent()
	while node and not node is BakedNavigationRegion:
		node = node.get_parent()
	return node as BakedNavigationRegion
