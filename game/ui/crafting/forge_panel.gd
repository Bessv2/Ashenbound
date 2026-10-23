class_name ForgePanel
extends CanvasLayer
## The concept sheet's Resources & Crafting panel: the six materials held,
## the chain Upgrade → Enchant → Craft → Legendary, and crafting itself:
## pick a kind of item, see its price in materials and gold, and craft it
## into the bag at the hero's level (docs/CRAFTING.md). Upgrade, Enchant and
## Ascend (Legendary) are done on an item's card in the bag. Crafting goes
## through Profile, which pays once and never loses the item.

signal close_requested

const CHAIN := [
	["upgrade", "Upgrade", "+1 rank to every stat"],
	["enchant", "Enchant", "Reroll one affix"],
	["craft", "Craft", "Make the item you want"],
	["legendary", "Legendary", "Ascend a rarity"],
]

var profile: Node

var _window: WindowFrame
var _materials_slot: HBoxContainer
var _bases: GridContainer
var _base_buttons: Dictionary[String, Button] = {}
var _selected: String = ""
var _name_label: Label
var _info_label: Label
var _cost_slot: VBoxContainer
var _craft_button: Button
var _message: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	if profile == null:
		profile = get_node_or_null(^"/root/Profile")
	_build()
	hide()


func open() -> void:
	_message.text = ""
	if _selected == "" and not profile.catalog.bases.is_empty():
		_selected = profile.catalog.bases[0].id
	_refresh()
	show()
	UiFx.pop_layer(self)
	Audio.play(&"ui_open")


func close() -> void:
	if visible:
		Audio.play(&"ui_close")
	hide()


## Shows base `base_id` and its price.
func select_base(base_id: String) -> void:
	_selected = base_id
	_message.text = ""
	_refresh()


## Crafts the shown kind of item. Returns the item, or null.
func press_craft() -> ItemInstance:
	var item: ItemInstance = profile.craft_item(_selected)
	if item:
		Audio.play(&"anvil")
		var base: ItemBase = profile.catalog.base(item.base_id)
		_message.text = "Crafted: %s %s" % [Rarity.name_of(item.rarity), base.display_name]
		_message.add_theme_color_override(&"font_color", Rarity.color_of(item.rarity).lightened(0.3))
	else:
		Audio.play(&"ui_error")
		_message.text = profile.craft_problem(_selected)
		_message.add_theme_color_override(&"font_color", Color("#E0625A"))
	_refresh()
	return item


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.02, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := MarginContainer.new()
	root.theme = load("res://ui/theme/ashen_theme.tres")
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 20)
	add_child(root)
	_window = WindowFrame.new("Forge")
	_window.close_pressed.connect(close_requested.emit)
	root.add_child(_window)
	_materials_slot = HBoxContainer.new()
	_window.add_to_header(_materials_slot)

	var chain := HBoxContainer.new()
	chain.add_theme_constant_override(&"separation", 8)
	chain.alignment = BoxContainer.ALIGNMENT_CENTER
	_window.content.add_child(chain)
	for i in CHAIN.size():
		if i > 0:
			var arrow := Label.new()
			arrow.text = "->"
			arrow.add_theme_font_size_override(&"font_size", 26)
			arrow.add_theme_color_override(&"font_color", Color(0.75, 0.5, 0.3))
			chain.add_child(arrow)
		var step := HBoxContainer.new()
		step.add_theme_constant_override(&"separation", 8)
		var icon := TextureRect.new()
		icon.texture = Icons.of(CHAIN[i][0])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(44, 44)
		icon.modulate = Color("#D9A44C") if i < 3 else Rarity.color_of(Rarity.Tier.LEGENDARY)
		step.add_child(icon)
		var words := VBoxContainer.new()
		words.add_theme_constant_override(&"separation", 0)
		var title := Label.new()
		title.text = CHAIN[i][1]
		title.add_theme_font_size_override(&"font_size", 20)
		words.add_child(title)
		var line := Label.new()
		line.text = CHAIN[i][2]
		line.theme_type_variation = &"DimLabel"
		line.add_theme_font_size_override(&"font_size", 14)
		words.add_child(line)
		step.add_child(words)
		chain.add_child(step)
	var hint := Label.new()
	hint.text = "Upgrade, Enchant and Ascend an item from its card in the bag. Craft here."
	hint.theme_type_variation = &"DimLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_window.content.add_child(hint)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_window.content.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	_bases = GridContainer.new()
	_bases.columns = 3
	_bases.add_theme_constant_override(&"h_separation", 8)
	_bases.add_theme_constant_override(&"v_separation", 8)
	scroll.add_child(_bases)
	for base: ItemBase in profile.catalog.bases:
		var button := Button.new()
		button.name = base.id
		button.text = base.display_name
		button.icon = base.icon_texture()
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override(&"icon_max_width", 44)
		button.add_theme_font_size_override(&"font_size", 15)
		button.custom_minimum_size = Vector2(178, 64)
		button.clip_text = true
		button.pressed.connect(select_base.bind(base.id))
		_bases.add_child(button)
		_base_buttons[base.id] = button

	var detail := VBoxContainer.new()
	detail.add_theme_constant_override(&"separation", 10)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(detail)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override(&"font_size", 28)
	detail.add_child(_name_label)
	_info_label = Label.new()
	_info_label.theme_type_variation = &"DimLabel"
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_info_label)
	_cost_slot = VBoxContainer.new()
	detail.add_child(_cost_slot)
	_craft_button = Button.new()
	_craft_button.name = "Craft"
	_craft_button.text = "Craft"
	_craft_button.icon = Icons.of("craft")
	_craft_button.expand_icon = true
	_craft_button.add_theme_constant_override(&"icon_max_width", 40)
	_craft_button.custom_minimum_size = Vector2(0, 84)
	_craft_button.add_theme_font_size_override(&"font_size", 26)
	_craft_button.pressed.connect(press_craft)
	detail.add_child(_craft_button)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_message)


func _refresh() -> void:
	for child in _materials_slot.get_children():
		_materials_slot.remove_child(child)
		child.queue_free()
	_materials_slot.add_child(WindowFrame.materials_line(profile))
	_materials_slot.add_child(WindowFrame.purse("gold", profile.gold, Color("#D9A44C")))
	var base: ItemBase = profile.catalog.base(_selected)
	for id: String in _base_buttons:
		var button := _base_buttons[id]
		var chosen := id == _selected
		for state in [&"normal", &"hover", &"pressed", &"focus"]:
			button.add_theme_stylebox_override(state, UiFx.box(Color(0.07, 0.05, 0.07, 0.92), 6,
					Color("#DB6028") if chosen else Color(0.4, 0.3, 0.22, 0.6), 3 if chosen else 1))
	for child in _cost_slot.get_children():
		_cost_slot.remove_child(child)
		child.queue_free()
	if base == null:
		_name_label.text = "Choose an item"
		_info_label.text = ""
		_craft_button.disabled = true
		return
	var item_level := Crafting.craft_level(profile.level)
	_name_label.text = base.display_name
	_info_label.text = "%s · item level %d · Uncommon or better" % [ItemBase.SLOT_NAMES[base.slot], item_level]
	_cost_slot.add_child(WindowFrame.cost_line(Crafting.craft_cost(base, item_level), profile))
	_craft_button.disabled = profile.craft_problem(_selected) != ""
