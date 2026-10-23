class_name InventoryPanel
extends CanvasLayer
## The bag and the equipment: nine slots on the left, the bag grid in the
## middle, and the card of the selected item on the right with its stats
## compared, stat by stat, against what it would replace (docs/LOOT.md, UI).
## Equip, unequip, upgrade and salvage go through Profile, which never loses
## or duplicates an item. Salvage asks for a second tap.
##
## Built in code from the theme's controls. Touch first: every target is at
## least 88 px. Processes while the game is paused (Main pauses it).

signal close_requested

const SLOT_SIZE := Vector2(140, 88)
const CELL_SIZE := Vector2(84, 88)
const BAG_COLUMNS := 6
const BETTER := Color("#7FC97A")
const WORSE := Color("#E0625A")

var profile: Node

var _selected_uid: String = ""
var _selected_slot: int = -1
var _slot_buttons: Dictionary[int, Button] = {}
var _bag_grid: GridContainer
var _card_title: Label
var _card_info: Label
var _card_stats: RichTextLabel
var _action_button: Button
var _upgrade_button: Button
var _salvage_button: Button
## The bag item whose Salvage was tapped once; a second tap salvages it.
var _salvage_armed: String = ""
var _summary: Label
var _bag_title: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	if profile == null:
		profile = get_node_or_null(^"/root/Profile")
	_build()
	hide()
	profile.inventory.changed.connect(_refresh)
	profile.equipment.changed.connect(_refresh)


func open() -> void:
	_selected_uid = ""
	_selected_slot = -1
	_refresh()
	show()
	UiFx.pop_layer(self)
	Audio.play(&"ui_open")


func close() -> void:
	if visible:
		Audio.play(&"ui_close")
	hide()


## The item currently shown on the card, or null.
func selected_item() -> ItemInstance:
	if _selected_uid != "":
		for item in profile.inventory.items:
			if item.uid == _selected_uid:
				return item
	if _selected_slot >= 0:
		return profile.equipment.item_in(_selected_slot)
	return null


## Selects the bag item `uid` (for tests and taps).
func select_bag_item(uid: String) -> void:
	_selected_uid = uid
	_selected_slot = -1
	_refresh()


## Selects equipment `slot`.
func select_slot(slot: int) -> void:
	_selected_uid = ""
	_selected_slot = slot
	_refresh()


## Upgrades the selected item one rank. Returns "" or why it could not.
func press_upgrade() -> String:
	var problem: String = profile.upgrade_item(selected_item())
	Audio.play(&"anvil" if problem == "" else &"ui_error")
	_refresh()
	return problem


## Salvages the selected bag item on the second tap. Returns the gold gained
## (0 on the first tap, which only asks for confirmation).
func press_salvage() -> int:
	if _selected_uid == "":
		return 0
	if _salvage_armed != _selected_uid:
		_salvage_armed = _selected_uid
		_refresh()
		return 0
	var gained: int = profile.salvage(_selected_uid)
	if gained > 0:
		Audio.play(&"salvage")
		Audio.play(&"pickup_gold")
	_salvage_armed = ""
	_selected_uid = ""
	_refresh()
	return gained


## Equips the selected bag item, or unequips the selected slot.
func press_action() -> void:
	if _selected_uid != "":
		var item := selected_item()
		if profile.equip_from_bag(_selected_uid) and item:
			Audio.play(&"pickup_gear")
			_selected_slot = _slot_holding(item)
			_selected_uid = ""
	elif _selected_slot >= 0:
		var item: ItemInstance = profile.equipment.item_in(_selected_slot)
		if profile.unequip_to_bag(_selected_slot) and item:
			_selected_uid = item.uid
			_selected_slot = -1
	_refresh()


## Lines comparing `item` with what it would replace: "+4 Armour" in green,
## "-2% Damage" in red. Stats the old item had and this one lacks count as
## losses.
func comparison(item: ItemInstance) -> Array[Dictionary]:
	var current := _replaced_by(item)
	var new_stats := item.total_stats()
	var old_stats: Dictionary[String, int] = {}
	if current:
		old_stats = current.total_stats()
	var keys: Array[String] = []
	for stat in ItemStats.INFO:
		if new_stats.has(stat) or old_stats.has(stat):
			keys.append(stat)
	var lines: Array[Dictionary] = []
	for stat in keys:
		var delta: int = new_stats.get(stat, 0) - old_stats.get(stat, 0)
		if delta != 0:
			lines.append({"stat": stat, "delta": delta})
	return lines


func _replaced_by(item: ItemInstance) -> ItemInstance:
	var slot: int = profile.equipment.slot_for(item, profile.catalog)
	return profile.equipment.item_in(slot) if slot >= 0 else null


func _slot_holding(item: ItemInstance) -> int:
	for slot in Equipment.Slot.values():
		if profile.equipment.item_in(slot) == item:
			return slot
	return -1


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.02, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := MarginContainer.new()
	root.theme = load("res://ui/theme/ashen_theme.tres")
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 32)
	add_child(root)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 24)
	root.add_child(columns)

	var gear := VBoxContainer.new()
	gear.add_theme_constant_override(&"separation", 6)
	columns.add_child(gear)
	var gear_title := Label.new()
	gear_title.text = "Equipped"
	gear_title.theme_type_variation = &"HeaderLabel"
	gear.add_child(gear_title)
	var slot_grid := GridContainer.new()
	slot_grid.columns = 2
	slot_grid.add_theme_constant_override(&"h_separation", 6)
	slot_grid.add_theme_constant_override(&"v_separation", 6)
	gear.add_child(slot_grid)
	for slot in Equipment.Slot.values():
		var button := Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.add_theme_font_size_override(&"font_size", 15)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = true
		button.pressed.connect(select_slot.bind(slot))
		slot_grid.add_child(button)
		_slot_buttons[slot] = button
	_summary = Label.new()
	_summary.theme_type_variation = &"DimLabel"
	gear.add_child(_summary)

	var bag := VBoxContainer.new()
	bag.add_theme_constant_override(&"separation", 6)
	columns.add_child(bag)
	_bag_title = Label.new()
	_bag_title.theme_type_variation = &"HeaderLabel"
	bag.add_child(_bag_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2((CELL_SIZE.x + 6) * BAG_COLUMNS + 12, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag.add_child(scroll)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = BAG_COLUMNS
	_bag_grid.add_theme_constant_override(&"h_separation", 6)
	_bag_grid.add_theme_constant_override(&"v_separation", 6)
	scroll.add_child(_bag_grid)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(300, 0)
	columns.add_child(card)
	var card_items := VBoxContainer.new()
	card_items.add_theme_constant_override(&"separation", 10)
	card.add_child(card_items)
	_card_title = Label.new()
	_card_title.theme_type_variation = &"HeaderLabel"
	_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_items.add_child(_card_title)
	_card_info = Label.new()
	_card_info.theme_type_variation = &"DimLabel"
	card_items.add_child(_card_info)
	# The stats scroll; the buttons below always stay on screen.
	_card_stats = RichTextLabel.new()
	_card_stats.bbcode_enabled = true
	_card_stats.scroll_active = true
	_card_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_stats.add_theme_font_size_override(&"normal_font_size", 20)
	card_items.add_child(_card_stats)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	card_items.add_child(buttons)
	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(0, 88)
	_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_button.pressed.connect(press_action)
	buttons.add_child(_action_button)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(0, 88)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(close_requested.emit)
	buttons.add_child(close_button)
	var forge_buttons := HBoxContainer.new()
	forge_buttons.add_theme_constant_override(&"separation", 10)
	card_items.add_child(forge_buttons)
	_upgrade_button = Button.new()
	_upgrade_button.custom_minimum_size = Vector2(0, 88)
	_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_button.clip_text = true
	_upgrade_button.add_theme_font_size_override(&"font_size", 18)
	_upgrade_button.pressed.connect(press_upgrade)
	forge_buttons.add_child(_upgrade_button)
	_salvage_button = Button.new()
	_salvage_button.custom_minimum_size = Vector2(0, 88)
	_salvage_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_salvage_button.clip_text = true
	_salvage_button.add_theme_font_size_override(&"font_size", 18)
	_salvage_button.pressed.connect(press_salvage)
	forge_buttons.add_child(_salvage_button)


func _refresh() -> void:
	if _bag_grid == null:
		return
	var catalog: ItemCatalog = profile.catalog
	for slot in _slot_buttons:
		var item: ItemInstance = profile.equipment.item_in(slot)
		var button := _slot_buttons[slot]
		button.text = Equipment.SLOT_NAMES[slot] + "\n" + (_name_of(item) if item else "-")
		_frame(button, item)
	for child in _bag_grid.get_children():
		child.queue_free()
	for item in profile.inventory.items:
		var cell := Button.new()
		cell.custom_minimum_size = CELL_SIZE
		cell.add_theme_font_size_override(&"font_size", 15)
		cell.clip_text = true
		var base := catalog.base(item.base_id)
		cell.text = ItemBase.SLOT_NAMES[base.slot] if base else "?"
		_frame(cell, item)
		if item.uid == _selected_uid:
			cell.add_theme_color_override(&"font_color", Color.WHITE)
		cell.pressed.connect(select_bag_item.bind(item.uid))
		_bag_grid.add_child(cell)
	_bag_title.text = "Bag %d / %d" % [profile.inventory.items.size(), profile.inventory.capacity]
	_summary.text = "Ash %d    Gold %d" % [profile.ash, profile.gold]
	if _salvage_armed != _selected_uid:
		_salvage_armed = ""
	_show_card(selected_item())


func _show_card(item: ItemInstance) -> void:
	if item == null:
		_card_title.text = "Select an item"
		_card_title.modulate = Color.WHITE
		_card_info.text = ""
		_card_stats.text = ""
		_action_button.visible = false
		_upgrade_button.visible = false
		_salvage_button.visible = false
		return
	_card_title.text = _name_of(item)
	_card_title.modulate = Rarity.color_of(item.rarity).lightened(0.25)
	_card_info.text = "%s · item level %d" % [Rarity.name_of(item.rarity), item.item_level]
	if item.upgrade > 0:
		_card_info.text += " · upgraded +%d" % item.upgrade
	var text := ""
	for stat in item.base_stats:
		text += ItemStats.describe(stat, item.stat_value(item.base_stats[stat])) + "\n"
	for affix in item.affixes:
		text += "[color=#9fb6d9]%s[/color]\n" % ItemStats.describe(affix.stat, item.stat_value(int(affix.value)))
	var equipped := _selected_slot >= 0
	text += "\n[color=#D9A44C]%s[/color]\n" % _forge_line(item, equipped)
	if not equipped:
		var lines := comparison(item)
		if not lines.is_empty():
			text += "\n[color=#a49a90]Compared with what you wear:[/color]\n"
			for line in lines:
				var color := BETTER if line.delta > 0 else WORSE
				text += "[color=#%s]%s[/color]\n" % [color.to_html(false), ItemStats.describe(line.stat, line.delta)]
	_card_stats.text = text
	_action_button.visible = true
	_action_button.text = "Unequip" if equipped else "Equip"
	_action_button.disabled = equipped and profile.inventory.is_full()
	_upgrade_button.visible = true
	_upgrade_button.text = "Max +%d" % Forge.MAX_UPGRADE if item.upgrade >= Forge.MAX_UPGRADE else "Upgrade"
	_upgrade_button.disabled = profile.upgrade_problem(item) != ""
	_salvage_button.visible = not equipped
	_salvage_button.text = "Confirm" if _salvage_armed == item.uid else "Salvage"


## The prices on the card: the next upgrade, and what salvage gives.
func _forge_line(item: ItemInstance, equipped: bool) -> String:
	var line := "Fully upgraded" if item.upgrade >= Forge.MAX_UPGRADE \
			else "Upgrade to +%d: %d gold, %d Ash" % [item.upgrade + 1, Forge.upgrade_gold(item), Forge.upgrade_ash(item)]
	if not equipped:
		line += "\nSalvage: %d gold" % Forge.salvage_gold(item)
		if _salvage_armed == item.uid:
			line += " (tap Confirm)"
	return line


## Gives `button` a frame in the rarity colour of `item` (plain when empty).
func _frame(button: Button, item: ItemInstance) -> void:
	var color := Rarity.color_of(item.rarity) if item else Color(0.35, 0.3, 0.28)
	for state in [&"normal", &"hover", &"pressed", &"focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(color.darkened(0.82), 0.95) if state != &"pressed" else color.darkened(0.6)
		box.border_color = color.lightened(0.15) if state != &"normal" else color
		box.set_border_width_all(3 if item else 1)
		box.set_corner_radius_all(6)
		box.set_content_margin_all(4)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override(&"font_color", color.lightened(0.45) if item else Color(0.6, 0.56, 0.52))


func _name_of(item: ItemInstance) -> String:
	var base: ItemBase = profile.catalog.base(item.base_id)
	var item_name := base.display_name if base else item.base_id
	return item_name + (" +%d" % item.upgrade if item.upgrade > 0 else "")
