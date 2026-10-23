class_name CampsPanel
extends CanvasLayer
## The gathering camps (docs/CRAFTING.md): a card per camp with its level,
## what it gathers each hour, what it holds now against its 8-hour store,
## and buttons to collect and to upgrade it. They work while the game is
## closed (device clock, provisional). Changes go through Profile.

signal close_requested

const STORE_FILL := Color("#3C9DBE")

var profile: Node

var _window: WindowFrame
var _materials_slot: HBoxContainer
var _cards: HBoxContainer
var _locked: Label
var _collect_all: Button
var _views: Dictionary[String, Dictionary] = {}
var _wait: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	if profile == null:
		profile = get_node_or_null(^"/root/Profile")
	_build()
	hide()


func open() -> void:
	_refresh()
	show()
	UiFx.pop_layer(self)
	Audio.play(&"ui_open")


func close() -> void:
	if visible:
		Audio.play(&"ui_close")
	hide()


## Collects camp `id`. Returns what was taken.
func press_collect(id: String) -> Dictionary:
	var taken: Dictionary = profile.collect_camp(id)
	Audio.play(&"pickup_gold" if not taken.is_empty() and taken.values().any(func(v: int) -> bool: return v > 0) else &"ui_click")
	_refresh()
	return taken


## Collects every camp. Returns the sum taken.
func press_collect_all() -> Dictionary:
	var taken: Dictionary = profile.collect_all_camps()
	Audio.play(&"pickup_gold")
	_refresh()
	return taken


## Upgrades camp `id`. Returns "" or why not.
func press_upgrade(id: String) -> String:
	var problem: String = profile.upgrade_camp(id)
	Audio.play(&"anvil" if problem == "" else &"ui_error")
	_refresh()
	return problem


func _process(delta: float) -> void:
	if not visible:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = 1.0
		_refresh()


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
	_window = WindowFrame.new("Camps")
	_window.close_pressed.connect(close_requested.emit)
	root.add_child(_window)
	_materials_slot = HBoxContainer.new()
	_window.add_to_header(_materials_slot)
	var line := Label.new()
	line.text = "Your camps gather while you are away, up to %d hours of work. Collect, then upgrade them to gather faster." % int(Camps.CAP_HOURS)
	line.theme_type_variation = &"DimLabel"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_window.content.add_child(line)
	_locked = Label.new()
	_locked.text = "The camps open once the Ashen Crypt is cleared."
	_locked.add_theme_font_size_override(&"font_size", 26)
	_locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_window.content.add_child(_locked)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override(&"separation", 14)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_window.content.add_child(_cards)
	for id in Camps.ORDER:
		_cards.add_child(_card(id))
	_collect_all = Button.new()
	_collect_all.name = "CollectAll"
	_collect_all.text = "Collect all"
	_collect_all.custom_minimum_size = Vector2(320, 76)
	_collect_all.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_collect_all.add_theme_font_size_override(&"font_size", 24)
	_collect_all.pressed.connect(press_collect_all)
	_window.content.add_child(_collect_all)


func _card(id: String) -> PanelContainer:
	var info: Dictionary = Camps.INFO[id]
	var card := PanelContainer.new()
	card.name = id
	card.custom_minimum_size = Vector2(280, 0)
	var frame := UiFx.box(Color(0.05, 0.045, 0.055, 0.95), 8, Color(0.4, 0.3, 0.2), 2)
	frame.set_content_margin_all(12)
	card.add_theme_stylebox_override(&"panel", frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	card.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override(&"separation", 10)
	column.add_child(heading)
	var icon := TextureRect.new()
	icon.texture = Icons.of(info.icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(56, 56)
	icon.modulate = Color("#D9A44C")
	heading.add_child(icon)
	var names := VBoxContainer.new()
	heading.add_child(names)
	var title := Label.new()
	title.text = info.name
	title.add_theme_font_size_override(&"font_size", 22)
	names.add_child(title)
	var level := Label.new()
	level.theme_type_variation = &"DimLabel"
	names.add_child(level)
	var rate := Label.new()
	rate.add_theme_font_size_override(&"font_size", 17)
	rate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(rate)
	var stock := HBoxContainer.new()
	column.add_child(stock)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override(&"background", UiFx.box(Color(0.06, 0.04, 0.03, 0.85), 3, Color(0.35, 0.25, 0.12, 0.8), 1))
	bar.add_theme_stylebox_override(&"fill", UiFx.box(STORE_FILL, 3))
	column.add_child(bar)
	var collect := Button.new()
	collect.name = "Collect"
	collect.text = "Collect"
	collect.custom_minimum_size = Vector2(0, 64)
	collect.pressed.connect(press_collect.bind(id))
	column.add_child(collect)
	var upgrade := Button.new()
	upgrade.name = "Upgrade"
	upgrade.custom_minimum_size = Vector2(0, 64)
	upgrade.pressed.connect(press_upgrade.bind(id))
	column.add_child(upgrade)
	var cost := VBoxContainer.new()
	column.add_child(cost)
	_views[id] = {"level": level, "rate": rate, "stock": stock, "bar": bar, "collect": collect,
			"upgrade": upgrade, "cost": cost}
	return card


func _refresh() -> void:
	for child in _materials_slot.get_children():
		_materials_slot.remove_child(child)
		child.queue_free()
	_materials_slot.add_child(WindowFrame.materials_line(profile))
	_materials_slot.add_child(WindowFrame.purse("gold", profile.gold, Color("#D9A44C")))
	var open: bool = profile.camps_open()
	_locked.visible = not open
	_cards.visible = open
	_collect_all.visible = open
	if not open:
		return
	for id in Camps.ORDER:
		var view := _views[id]
		var level: int = profile.camp_level(id)
		(view.level as Label).text = "Level %d / %d" % [level, Camps.MAX_LEVEL]
		var parts: PackedStringArray = []
		var hourly := Camps.hourly(id, level)
		for material_id: String in hourly:
			parts.append("%s %s / h" % [String.num(hourly[material_id], 1).trim_suffix(".0"), Materials.name_of(material_id)])
		(view.rate as Label).text = ", ".join(parts)
		var stock_row := view.stock as HBoxContainer
		for child in stock_row.get_children():
			stock_row.remove_child(child)
			child.queue_free()
		var held: Dictionary = profile.camp_stock(id)
		for material_id: String in held:
			var entry := WindowFrame.purse(material_id, held[material_id], Materials.color_of(material_id))
			entry.name = material_id
			stock_row.add_child(entry)
		var main_material: String = hourly.keys()[0]
		var cap: float = hourly[main_material] * Camps.CAP_HOURS
		(view.bar as ProgressBar).max_value = cap
		(view.bar as ProgressBar).value = held.get(main_material, 0)
		(view.upgrade as Button).text = "Fully built" if level >= Camps.MAX_LEVEL else "Upgrade to %d" % (level + 1)
		var cost_box := view.cost as VBoxContainer
		for child in cost_box.get_children():
			cost_box.remove_child(child)
			child.queue_free()
		if level < Camps.MAX_LEVEL:
			var cost := Camps.upgrade_cost(id, level)
			cost_box.add_child(WindowFrame.cost_line(cost, profile))
			(view.upgrade as Button).disabled = profile.missing_for(cost) != ""
		else:
			(view.upgrade as Button).disabled = true
