class_name CharacterPanel
extends CanvasLayer
## The concept sheet's Character window: the hero's portrait, level and XP,
## the gear worn as icons, and the numbers that matter in a fight (health,
## attack, armour, critical chance and damage, speeds). Read only. The rows
## come from CharacterStats.sheet: the hero's own Stats in a run, or
## CharacterStats.preview on the title screen.

signal close_requested

const GOLD := Color("#D9A44C")

var profile: Node

var _window: WindowFrame
var _portrait: HeroPortrait
var _name_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _slots: GridContainer
var _rows: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	if profile == null:
		profile = get_node_or_null(^"/root/Profile")
	_build()
	hide()


## Shows the sheet of the class `class_id` called `title`, from `rows`
## (CharacterStats.sheet), ringed in `accent`.
func open(rows: Array[Dictionary], class_id: String, title: String, accent: Color) -> void:
	_portrait.icon = Icons.for_attack(class_id)
	_portrait.accent = accent
	_portrait.level = profile.level
	_name_label.text = title.to_upper()
	_name_label.add_theme_color_override(&"font_color", accent)
	_level_label.text = "Level %d" % profile.level
	_xp_bar.max_value = profile.xp_to_next(profile.level)
	_xp_bar.value = profile.xp
	_fill_slots()
	_fill_rows(rows)
	show()
	UiFx.pop_layer(self)
	Audio.play(&"ui_open")


func close() -> void:
	if visible:
		Audio.play(&"ui_close")
	hide()


## The value shown in row `key` ("health", "attack", …), for tests.
func value_of(key: String) -> String:
	for row in _rows.get_children():
		if row.name == key:
			return (row.get_node("Value") as Label).text
	return ""


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.02, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.theme = load("res://ui/theme/ashen_theme.tres")
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_window = WindowFrame.new("Character")
	_window.custom_minimum_size = Vector2(900, 560)
	_window.close_pressed.connect(close_requested.emit)
	centre.add_child(_window)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 28)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_window.content.add_child(columns)

	var hero := VBoxContainer.new()
	hero.custom_minimum_size.x = 330
	hero.add_theme_constant_override(&"separation", 8)
	columns.add_child(hero)
	_portrait = HeroPortrait.new()
	_portrait.custom_minimum_size = Vector2(190, 200)
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero.add_child(_portrait)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override(&"font_size", 30)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(_name_label)
	_level_label = Label.new()
	_level_label.theme_type_variation = &"DimLabel"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(_level_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 10)
	_xp_bar.add_theme_stylebox_override(&"background", UiFx.box(Color(0.06, 0.04, 0.03, 0.85), 2, Color(0.35, 0.25, 0.12, 0.8), 1))
	_xp_bar.add_theme_stylebox_override(&"fill", UiFx.box(Hud.XP_FILL, 2))
	hero.add_child(_xp_bar)
	_slots = GridContainer.new()
	_slots.columns = 5
	_slots.add_theme_constant_override(&"h_separation", 6)
	_slots.add_theme_constant_override(&"v_separation", 6)
	_slots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero.add_child(_slots)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_rows)


func _fill_slots() -> void:
	for child in _slots.get_children():
		child.queue_free()
	for slot in Equipment.Slot.values():
		var item: ItemInstance = profile.equipment.item_in(slot)
		var cell := TextureRect.new()
		cell.custom_minimum_size = Vector2(58, 58)
		cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var base: ItemBase = profile.catalog.base(item.base_id) if item else null
		cell.texture = base.icon_texture() if base else Icons.for_slot(Equipment.item_slot_of(slot))
		cell.modulate = Rarity.color_of(item.rarity).lightened(0.3) if item else Color(0.4, 0.37, 0.35, 0.6)
		cell.tooltip_text = Equipment.SLOT_NAMES[slot]
		_slots.add_child(cell)


func _fill_rows(rows: Array[Dictionary]) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for row in rows:
		var line := HBoxContainer.new()
		line.name = row.key
		line.add_theme_constant_override(&"separation", 12)
		var icon := TextureRect.new()
		icon.texture = Icons.of(row.icon)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(30, 30)
		icon.modulate = GOLD
		line.add_child(icon)
		var label := Label.new()
		label.text = row.label
		label.add_theme_font_size_override(&"font_size", 22)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var value := Label.new()
		value.name = "Value"
		value.text = row.value
		value.add_theme_font_size_override(&"font_size", 24)
		value.add_theme_color_override(&"font_color", Color("#E2CBB4"))
		line.add_child(value)
		_rows.add_child(line)
