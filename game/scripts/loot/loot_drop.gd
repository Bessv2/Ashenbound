class_name LootDrop
extends Area3D
## Gold or an item lying on the ground. It pops out from where it dropped,
## lands, and is then picked up by any body with an Inventory standing on it.
## An item stays on the ground while that inventory is full. Unclaimed drops
## disappear after `lifetime`.
##
## Built in code with placeholder visuals: a gold disc, or a gem in the item's
## rarity color with a light beam above Uncommon and better, and a name label.

signal picked_up(by: Inventory)

## How long the pop from the body to the landing spot takes. Drops cannot be
## picked up before they land.
const POP_TIME := 0.35
const POP_HEIGHT := 1.2
const PICKUP_RADIUS := 0.9
const GOLD_COLOR := Color(0.95, 0.75, 0.3)

@export var lifetime: float = 60.0

## Gold carried by this drop; 0 for an item drop.
var gold: int = 0
## The item carried by this drop; null for a gold drop.
var item: Item

var _age: float = 0.0
var _visual: Node3D


## Spawns a gold drop under `parent`, popping from `from` to `landing`.
static func spawn_gold(parent: Node, from: Vector3, landing: Vector3, amount: int) -> LootDrop:
	var drop := LootDrop.new()
	drop.gold = amount
	return drop._spawn(parent, from, landing)


## Spawns an item drop under `parent`, popping from `from` to `landing`.
static func spawn_item(parent: Node, from: Vector3, landing: Vector3, dropped: Item) -> LootDrop:
	var drop := LootDrop.new()
	drop.item = dropped
	return drop._spawn(parent, from, landing)


func is_landed() -> bool:
	return _age >= POP_TIME


func _spawn(parent: Node, from: Vector3, landing: Vector3) -> LootDrop:
	name = "Gold" if item == null else "Item"
	collision_layer = 0
	collision_mask = 2  # The player.
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	shape.shape = sphere
	add_child(shape)
	_visual = _build_visual()
	add_child(_visual)
	parent.add_child(self)
	global_position = from
	reset_physics_interpolation()
	# Physics clock: the drop is interpolated and pauses with the game. The
	# horizontal move and the rise-and-fall both take exactly POP_TIME.
	var across := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	across.tween_property(self, "global_position:x", landing.x, POP_TIME)
	across.tween_property(self, "global_position:z", landing.z, POP_TIME)
	var arc := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	arc.tween_property(self, "global_position:y", landing.y + POP_HEIGHT, POP_TIME * 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(self, "global_position:y", landing.y, POP_TIME * 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var spin := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_loops()
	spin.tween_property(_visual, "rotation:y", TAU, 2.5).from(0.0)
	return self


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if not is_landed() or is_queued_for_deletion():
		return
	for body in get_overlapping_bodies():
		var inventory := Inventory.of(body)
		if inventory and _give_to(inventory):
			picked_up.emit(inventory)
			queue_free()
			return


func _give_to(inventory: Inventory) -> bool:
	if item:
		return inventory.add_item(item)
	inventory.add_gold(gold)
	return true


func _build_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var color := GOLD_COLOR if item == null else Rarity.color_of(item.rarity)
	var piece := MeshInstance3D.new()
	if item == null:
		var disc := CylinderMesh.new()
		disc.top_radius = 0.18
		disc.bottom_radius = 0.18
		disc.height = 0.06
		disc.radial_segments = 16
		disc.rings = 1
		piece.mesh = disc
		piece.position.y = 0.15
		piece.rotation.x = deg_to_rad(70.0)
	else:
		var gem := BoxMesh.new()
		gem.size = Vector3(0.26, 0.26, 0.26)
		piece.mesh = gem
		piece.position.y = 0.4
		piece.rotation = Vector3(deg_to_rad(45.0), 0.0, deg_to_rad(45.0))
	piece.material_override = _glow_material(color, 1.4)
	root.add_child(piece)
	if item and item.rarity >= Rarity.Tier.UNCOMMON:
		var beam := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.03
		cylinder.bottom_radius = 0.07
		cylinder.height = 2.4
		cylinder.radial_segments = 8
		cylinder.rings = 1
		beam.mesh = cylinder
		beam.position.y = 1.2
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.material_override = _beam_material(color)
		root.add_child(beam)
	if item:
		var label := Label3D.new()
		label.text = item.data.display_name
		label.modulate = Rarity.text_color_of(item.rarity)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 40
		label.pixel_size = 0.01
		label.outline_size = 12
		label.position.y = 0.95
		add_child(label)  # Not under the spinning visual.
	return root


static func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func _beam_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color, 0.45)
	return material
