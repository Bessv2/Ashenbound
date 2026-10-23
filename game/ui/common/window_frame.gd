class_name WindowFrame
extends PanelContainer
## A menu window like the concept sheet's: a dark panel with a thin ember
## border, a title bar with the title on the left and a round close button
## (an X) on the right, and the content below. Emits close_pressed.

signal close_pressed

const BACKGROUND := Color(0.075, 0.07, 0.085, 0.97)
const BORDER := Color(0.55, 0.36, 0.2, 0.9)

var content: VBoxContainer
var title_label: Label
var _header: HBoxContainer


func _init(title: String = "") -> void:
	var frame := UiFx.box(BACKGROUND, 8, BORDER, 2)
	frame.set_content_margin_all(18)
	add_theme_stylebox_override(&"panel", frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	add_child(column)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override(&"separation", 14)
	column.add_child(_header)
	title_label = Label.new()
	title_label.text = title
	title_label.theme_type_variation = &"HeaderLabel"
	title_label.add_theme_font_size_override(&"font_size", 30)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(title_label)
	var close := Button.new()
	close.name = "Close"
	close.text = "X"
	close.add_theme_font_size_override(&"font_size", 28)
	close.custom_minimum_size = Vector2(64, 64)
	close.tooltip_text = "Close"
	close.pressed.connect(close_pressed.emit)
	_header.add_child(close)
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 2
	rule.color = Color(BORDER, 0.45)
	column.add_child(rule)
	content = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 10)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)


## Puts `control` in the title bar, before the close button (gold, tabs).
func add_to_header(control: Control) -> void:
	_header.add_child(control)
	_header.move_child(control, _header.get_child_count() - 2)


## An icon followed by a number: a purse entry (gold, Ash) for headers.
static func purse(icon_key: String, amount: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var icon := TextureRect.new()
	icon.texture = Icons.of(icon_key)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(30, 30)
	icon.modulate = color
	row.add_child(icon)
	var label := Label.new()
	label.name = "Amount"
	label.text = format_amount(amount)
	label.add_theme_font_size_override(&"font_size", 24)
	label.add_theme_color_override(&"font_color", color.lightened(0.35))
	row.add_child(label)
	return row


## 12480 → "12,480".
static func format_amount(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + grouped


## A price as icons and numbers: each entry of `cost` (materials, "gold",
## "ash"), red when `profile` holds too little of it.
static func cost_line(cost: Dictionary, profile: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	for id: String in cost:
		var have: int = profile.gold if id == Materials.GOLD else profile.ash if id == Materials.ASH else profile.material(id)
		var entry := purse(Materials.icon_of(id), int(cost[id]), Materials.color_of(id))
		entry.tooltip_text = Materials.name_of(id)
		var amount := entry.get_node("Amount") as Label
		amount.add_theme_font_size_override(&"font_size", 20)
		if have < int(cost[id]):
			amount.add_theme_color_override(&"font_color", Color("#E0625A"))
		row.add_child(entry)
	return row


## The six materials held, as icons and numbers (window headers).
static func materials_line(profile: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Materials"
	row.add_theme_constant_override(&"separation", 14)
	for id in Materials.ORDER:
		var entry := purse(id, profile.material(id), Materials.color_of(id))
		entry.name = id
		entry.tooltip_text = Materials.name_of(id)
		(entry.get_node("Amount") as Label).add_theme_font_size_override(&"font_size", 20)
		row.add_child(entry)
	return row

