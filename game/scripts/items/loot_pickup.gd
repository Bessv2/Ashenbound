class_name LootPickup
extends Node3D
## An item lying on the floor: a beam of light in its rarity colour and its
## name. The hero picks it up by walking within PICKUP_RADIUS; a full bag
## leaves it where it is. Picked up once, then gone.

signal picked_up(item: ItemInstance)

const PICKUP_RADIUS := 1.3
const BEAM_HEIGHTS := [0.8, 1.2, 2.0, 2.8, 3.8, 4.8]

var item: ItemInstance
var inventory: Inventory

var _taken: bool = false
var _bag_full_warned: bool = false


func _ready() -> void:
	var catalog := ItemCatalog.load_default()
	var color := Rarity.color_of(item.rarity)
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	var height: float = BEAM_HEIGHTS[item.rarity]
	mesh.top_radius = 0.06
	mesh.bottom_radius = 0.16
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	beam.mesh = mesh
	beam.position.y = height * 0.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.55)
	beam.material_override = material
	add_child(beam)
	var gem := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.18, 0.35)
	gem.mesh = box
	gem.position.y = 0.12
	var gem_material := StandardMaterial3D.new()
	gem_material.albedo_color = color
	gem_material.emission_enabled = true
	gem_material.emission = color
	gem_material.emission_energy_multiplier = 1.5
	gem.material_override = gem_material
	add_child(gem)
	var label := Label3D.new()
	var base := catalog.base(item.base_id)
	label.text = base.display_name if base else item.base_id
	label.modulate = color
	label.outline_size = 8
	label.font_size = 52
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = 0.7
	add_child(label)


func _physics_process(_delta: float) -> void:
	if _taken or inventory == null:
		return
	var hero := get_tree().get_first_node_in_group(PlayerController.GROUP) as PlayerController
	if hero == null or not hero.is_alive():
		return
	var offset := hero.global_position - global_position
	if Vector2(offset.x, offset.z).length() > PICKUP_RADIUS:
		_bag_full_warned = false
		return
	collect()


## Moves the item into the bag. Returns whether it was taken (false when the
## bag is full or it was already taken).
func collect() -> bool:
	if _taken or inventory == null or not inventory.add(item):
		return false
	_taken = true
	picked_up.emit(item)
	queue_free()
	return true
