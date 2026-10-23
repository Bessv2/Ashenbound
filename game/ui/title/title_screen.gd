class_name TitleScreen
extends Control
## The first screen: the name and tagline over drifting embers, a card per
## class of the roster (the playable ones can be chosen), the profile's level
## and purse, the crypt tier, and the way in. Choices go through Profile, so
## the run that starts reads them as usual. Built in code, touch first.

const MAIN_SCENE := "res://scenes/main.tscn"
const HERO_SCENES: Dictionary = preload("res://scripts/main.gd").HERO_SCENES
const ROLES := {
	"warden": "Iron and ember. Stands and endures.",
	"reaver": "Twin blades. Strikes, marks, vanishes.",
	"hexbinder": "Curses that bloom, then burst.",
	"dreadhunter": "Bolt, snare and raven. Patient death.",
	"reliquary": "Hollow light that heals and judges.",
	"gravecaller": "The dead rise and fight for you.",
}
const ACCENTS := {
	"warden": Color(1.0, 0.55, 0.25),
	"reaver": Color(0.95, 0.2, 0.3),
	"hexbinder": Color(0.7, 0.4, 1.0),
	"dreadhunter": Color(0.75, 0.65, 0.4),
	"reliquary": Color(0.6, 0.8, 1.0),
	"gravecaller": Color(0.35, 0.9, 0.7),
}

## Starts the run (changes scene). Tests disconnect it.
signal enter_requested

var profile: Node

var _cards: Dictionary = {}
var _tier_label: Label
var _summary: Label
var _enter_button: Button
var _dungeon_buttons: Dictionary = {}
var _look_buttons: Dictionary = {}
var _time: float = 0.0
var _purse: HBoxContainer
var _strip: ScrollContainer
var _character: CharacterPanel
var _inventory: InventoryPanel
var _forge: ForgePanel
var _camps: CampsPanel
var _quests: QuestsPanel
var _quests_button: Button


func _ready() -> void:
	if profile == null:
		profile = get_node_or_null(^"/root/Profile")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = load("res://ui/theme/ashen_theme.tres")
	_build()
	enter_requested.connect(_go_to_crypt)
	_character = CharacterPanel.new()
	_character.name = "Character"
	add_child(_character)
	_character.close_requested.connect(_character.close)
	_inventory = InventoryPanel.new()
	_inventory.name = "Inventory"
	add_child(_inventory)
	_inventory.close_requested.connect(_inventory.close)
	_forge = ForgePanel.new()
	_forge.name = "Forge"
	add_child(_forge)
	_forge.close_requested.connect(_forge.close)
	_camps = CampsPanel.new()
	_camps.name = "Camps"
	add_child(_camps)
	_camps.close_requested.connect(_camps.close)
	_quests = QuestsPanel.new()
	_quests.name = "Quests"
	add_child(_quests)
	_quests.close_requested.connect(_quests.close)
	profile.changed.connect(_refresh)
	_refresh()
	_animate_in()
	Audio.play_music(&"music_title")
	Audio.play_ambience(&"")
	# Enter (or a gamepad's accept) starts the run straight away.
	_enter_button.grab_focus()


## Ids of the classes that can be chosen.
func playable_classes() -> Array:
	return HERO_SCENES.keys()


## Chooses `class_id` when it is playable. Returns whether it is now chosen.
func choose(class_id: String) -> bool:
	if not HERO_SCENES.has(class_id):
		return false
	profile.select_class(class_id)
	_refresh()
	return true


## Chooses dungeon `id` when it is open. Returns whether it is now chosen.
func choose_dungeon(id: String) -> bool:
	var chosen: bool = profile.select_dungeon(id)
	_refresh()
	return chosen


## Chooses look `look` (ArtStyle.Look) for the next run and saves it.
func choose_look(look: int) -> void:
	var settings := get_node_or_null(^"/root/Settings")
	if settings == null:
		return
	settings.current.art_style = clampi(look, 0, ArtStyle.Look.size() - 1)
	settings.save_to(settings.SETTINGS_PATH)
	settings.apply()
	_refresh()


## Moves the chosen crypt tier by `step` within the open tiers.
func step_tier(step: int) -> void:
	profile.select_tier(profile.tier + step)
	_refresh()


func enter() -> void:
	enter_requested.emit()


## Opens the Character window for the chosen class, with the gear worn.
func open_character() -> void:
	var class_id: String = profile.hero_class if HERO_SCENES.has(profile.hero_class) else "warden"
	var tree_index := SkillTreePanel.TREE_PATHS.find_custom(func(path: String) -> bool: return (load(path) as SkillTree).class_id == class_id)
	var title: String = (load(SkillTreePanel.TREE_PATHS[tree_index]) as SkillTree).class_title if tree_index >= 0 else class_id
	_character.open(CharacterStats.preview(HERO_SCENES[class_id], class_id, profile), class_id, title,
			ACCENTS.get(class_id, Color.WHITE))


## Opens the bag and the gear.
func open_inventory() -> void:
	_inventory.open()


## Opens the forge (crafting).
func open_forge() -> void:
	_forge.open()


## Opens the gathering camps.
func open_camps() -> void:
	_camps.open()


## Opens the quests, achievements and daily challenges.
func open_quests() -> void:
	_quests.open()


func quests_panel() -> QuestsPanel:
	return _quests


func forge_panel() -> ForgePanel:
	return _forge


func camps_panel() -> CampsPanel:
	return _camps


func character_panel() -> CharacterPanel:
	return _character


func inventory_panel() -> InventoryPanel:
	return _inventory


func _go_to_crypt() -> void:
	Audio.play(&"gate_slam", Vector3.INF, 0.6)
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_SCENE)


func _process(delta: float) -> void:
	_time += delta
	# The chosen card and the way in breathe.
	var pulse := 0.5 + 0.5 * sin(_time * 2.6)
	for id: String in _cards:
		var card: Button = _cards[id]
		if id == profile.hero_class:
			card.self_modulate = Color(1, 1, 1).lerp(Color(1.25, 1.2, 1.15), pulse)
	if _enter_button:
		_enter_button.self_modulate = Color(1, 1, 1).lerp(Color(1.3, 1.15, 1.0), pulse * 0.6)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.material = _backdrop_material()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	add_child(_embers())

	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 40
	page.offset_right = -40
	page.offset_top = 56
	page.offset_bottom = -26
	page.add_theme_constant_override(&"separation", 14)
	add_child(page)

	var logo := Label.new()
	logo.name = "Logo"
	logo.text = "ASHENBOUND"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override(&"font_size", 76)
	logo.add_theme_color_override(&"font_color", Color("#E8B060"))
	logo.add_theme_constant_override(&"outline_size", 22)
	logo.add_theme_color_override(&"font_outline_color", Color(0.12, 0.03, 0.02, 0.95))
	logo.add_theme_color_override(&"font_shadow_color", Color(0.9, 0.3, 0.05, 0.55))
	logo.add_theme_constant_override(&"shadow_outline_size", 30)
	page.add_child(logo)
	var tagline := Label.new()
	tagline.name = "Tagline"
	tagline.text = "SOME BONDS SHOULD NEVER BE BROKEN."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.theme_type_variation = &"DimLabel"
	tagline.add_theme_font_size_override(&"font_size", 22)
	page.add_child(tagline)

	# Top right: the purse, then the look switch (docs/ART_STYLE_TEST.md).
	var corner := HBoxContainer.new()
	corner.name = "Header"
	corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -20
	corner.offset_top = 12
	corner.add_theme_constant_override(&"separation", 18)
	add_child(corner)
	_purse = HBoxContainer.new()
	_purse.add_theme_constant_override(&"separation", 18)
	corner.add_child(_purse)
	var looks := HBoxContainer.new()
	looks.name = "Looks"
	looks.add_theme_constant_override(&"separation", 6)
	corner.add_child(looks)
	for look in ArtStyle.Look.values():
		var look_button := Button.new()
		look_button.name = "Look%d" % look
		look_button.text = ArtStyle.NAMES[look]
		look_button.tooltip_text = ArtStyle.LINES[look]
		look_button.custom_minimum_size = Vector2(96, 52)
		look_button.add_theme_font_size_override(&"font_size", 16)
		look_button.pressed.connect(choose_look.bind(look))
		_look_buttons[look] = look_button
		looks.add_child(look_button)

	var row := HBoxContainer.new()
	row.name = "Cards"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(row)
	for path in SkillTreePanel.TREE_PATHS:
		var tree: SkillTree = load(path)
		var card := _card(tree)
		_cards[tree.class_id] = card
		row.add_child(card)

	# Seven dungeons do not fit across a phone: the row scrolls sideways.
	var strip := ScrollContainer.new()
	_strip = strip
	strip.name = "DungeonStrip"
	strip.custom_minimum_size.y = 104
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	page.add_child(strip)
	var dungeons := HBoxContainer.new()
	dungeons.name = "Dungeons"
	dungeons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dungeons.alignment = BoxContainer.ALIGNMENT_CENTER
	dungeons.add_theme_constant_override(&"separation", 12)
	strip.add_child(dungeons)
	# The concept sheet's Dungeon Selection: a card per dungeon with its
	# icon, name and level range.
	for id in Dungeons.ORDER:
		var button := Button.new()
		button.name = id
		button.custom_minimum_size = Vector2(300, 96)
		button.add_theme_font_size_override(&"font_size", 19)
		button.icon = Icons.of(Dungeons.INFO[id].icon)
		button.expand_icon = true
		button.add_theme_constant_override(&"icon_max_width", 64)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(choose_dungeon.bind(id))
		_dungeon_buttons[id] = button
		dungeons.add_child(button)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override(&"separation", 18)
	page.add_child(bottom)
	for entry in [["CharacterButton", "character", "Character", open_character], ["BagButton", "bag", "Inventory", open_inventory],
			["ForgeButton", "craft", "Forge", open_forge], ["CampsButton", "mine", "Camps", open_camps],
			["QuestsButton", "quests", "Quests", open_quests]]:
		var menu_button := Button.new()
		menu_button.name = entry[0]
		menu_button.icon = Icons.of(entry[1])
		menu_button.tooltip_text = entry[2]
		menu_button.expand_icon = true
		menu_button.custom_minimum_size = Vector2(72, 76)
		menu_button.pressed.connect(entry[3])
		bottom.add_child(menu_button)
		if entry[0] == "QuestsButton":
			_quests_button = menu_button
			# A badge in the corner: rewards waiting to be claimed.
			var badge := Label.new()
			badge.name = "Badge"
			badge.add_theme_font_size_override(&"font_size", 18)
			badge.add_theme_color_override(&"font_color", Color("#E2CBB4"))
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.add_theme_stylebox_override(&"normal", UiFx.box(Color("#3E7A3A"), 12, Color("#7FC97A"), 2))
			badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			badge.offset_left = -20
			badge.offset_top = -8
			badge.offset_right = 8
			badge.offset_bottom = 18
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu_button.add_child(badge)
	_summary = Label.new()
	_summary.theme_type_variation = &"DimLabel"
	_summary.custom_minimum_size.x = 90
	bottom.add_child(_summary)
	var down := Button.new()
	down.text = "<"
	down.custom_minimum_size = Vector2(72, 80)
	down.pressed.connect(step_tier.bind(-1))
	bottom.add_child(down)
	_tier_label = Label.new()
	_tier_label.custom_minimum_size.x = 130
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_tier_label)
	var up := Button.new()
	up.text = ">"
	up.custom_minimum_size = Vector2(72, 80)
	up.pressed.connect(step_tier.bind(1))
	bottom.add_child(up)
	_enter_button = Button.new()
	_enter_button.name = "Enter"
	_enter_button.text = "Enter the crypt"
	_enter_button.custom_minimum_size = Vector2(290, 88)
	_enter_button.add_theme_font_size_override(&"font_size", 32)
	_enter_button.pressed.connect(enter)
	bottom.add_child(_enter_button)


func _card(tree: SkillTree) -> Button:
	var id := tree.class_id
	var playable := HERO_SCENES.has(id)
	var accent: Color = ACCENTS.get(id, Color.WHITE)
	var card := Button.new()
	card.name = tree.class_title
	card.custom_minimum_size = Vector2(178, 200)
	card.clip_text = true
	card.disabled = not playable
	card.pressed.connect(choose.bind(id))
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12
	column.offset_right = -12
	column.offset_top = 16
	column.offset_bottom = -12
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 8)
	card.add_child(column)
	var sigil := ColorRect.new()
	sigil.custom_minimum_size = Vector2(0, 6)
	sigil.color = accent if playable else accent.darkened(0.6)
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(sigil)
	var title := Label.new()
	title.text = tree.class_title.to_upper()
	# Long names (DREADHUNTER) shrink to fit the card.
	title.add_theme_font_size_override(&"font_size", 26 if tree.class_title.length() <= 9 else 21)
	title.add_theme_color_override(&"font_color", accent.lightened(0.2) if playable else Color(0.45, 0.42, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var role := Label.new()
	role.text = ROLES.get(id, "")
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_font_size_override(&"font_size", 18)
	role.add_theme_color_override(&"font_color", Color(0.8, 0.75, 0.68) if playable else Color(0.4, 0.38, 0.36))
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(role)
	var branches := Label.new()
	branches.text = " · ".join(tree.branches)
	branches.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	branches.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	branches.add_theme_font_size_override(&"font_size", 15)
	branches.add_theme_color_override(&"font_color", accent.darkened(0.15) if playable else Color(0.35, 0.33, 0.32))
	branches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(branches)
	return card


func _refresh() -> void:
	for id: String in _cards:
		var card: Button = _cards[id]
		var chosen: bool = id == profile.hero_class
		var accent: Color = ACCENTS.get(id, Color.WHITE)
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			var box := UiFx.box(Color(0.07, 0.05, 0.07, 0.92) if state != &"disabled" else Color(0.05, 0.04, 0.05, 0.7), 10,
					accent if chosen else Color(accent, 0.35) if state != &"disabled" else Color(0.25, 0.22, 0.2, 0.5),
					4 if chosen else 2)
			card.add_theme_stylebox_override(state, box)
		if not chosen:
			card.self_modulate = Color.WHITE
	for id: String in _dungeon_buttons:
		var button: Button = _dungeon_buttons[id]
		var info: Dictionary = Dungeons.INFO[id]
		var open := Dungeons.is_open(id, profile)
		var here: bool = id == profile.dungeon
		button.disabled = not open
		button.text = "%s\n%s" % [info.title, Dungeons.level_range(id) if open else Dungeons.lock_reason(id, profile)]
		if not open:
			button.icon = Icons.of("locked")
		button.tooltip_text = info.line
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			button.add_theme_stylebox_override(state, UiFx.box(Color(0.07, 0.05, 0.07, 0.92), 10,
					info.color if here else Color(info.color, 0.3), 3 if here else 1))
		button.add_theme_color_override(&"font_color", info.color.lightened(0.25) if here else Color(0.75, 0.7, 0.65))
		for state in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_focus_color"]:
			button.add_theme_color_override(state, info.color.lightened(0.2) if here else Color(info.color, 0.7))
	var current_look := ArtStyle.current()
	for look: int in _look_buttons:
		var look_button: Button = _look_buttons[look]
		var accent := Color(0.95, 0.75, 0.4)
		for state in [&"normal", &"hover", &"pressed", &"focus"]:
			look_button.add_theme_stylebox_override(state, UiFx.box(Color(0.07, 0.05, 0.07, 0.92), 10,
					accent if look == current_look else Color(accent, 0.25), 3 if look == current_look else 1))
		look_button.add_theme_color_override(&"font_color", accent.lightened(0.3) if look == current_look else Color(0.7, 0.66, 0.6))
	_enter_button.text = Dungeons.INFO[profile.dungeon].enter
	# Keeps the chosen dungeon's card in view.
	if _dungeon_buttons.has(profile.dungeon):
		_strip.ensure_control_visible.call_deferred(_dungeon_buttons[profile.dungeon])
	_tier_label.text = "Tier %d" % profile.tier
	_summary.text = "Level %d" % profile.level
	# The number of rewards waiting, on the Quests button.
	var waiting: int = profile.claimable_count()
	var badge := _quests_button.get_node("Badge") as Label
	badge.text = str(waiting)
	badge.visible = waiting > 0
	for child in _purse.get_children():
		_purse.remove_child(child)
		child.queue_free()
	_purse.add_child(WindowFrame.purse("gold", profile.gold, Color("#D9A44C")))
	_purse.add_child(WindowFrame.purse("ash", profile.ash, Color("#A77BD6")))


func _animate_in() -> void:
	var logo := find_child("Logo", true, false) as Control
	logo.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(logo, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	var delay := 0.25
	for id: String in _cards:
		var card: Button = _cards[id]
		card.modulate.a = 0.0
		var card_tween := create_tween()
		card_tween.tween_interval(delay)
		card_tween.tween_property(card, "modulate:a", 1.0, 0.35)
		delay += 0.08


func _backdrop_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 p = UV - vec2(0.5, 0.62);
	p.x *= 1.8;
	float glow = exp(-dot(p, p) * 3.2);
	float flicker = 0.9 + 0.1 * sin(TIME * 1.7) * sin(TIME * 2.9);
	vec3 deep = vec3(0.02, 0.012, 0.025);
	vec3 ember = vec3(0.32, 0.07, 0.03);
	COLOR = vec4(mix(deep, ember, glow * flicker), 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _embers() -> CPUParticles2D:
	var embers := CPUParticles2D.new()
	embers.name = "Embers"
	embers.amount = 60
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.position = Vector2(640, 760)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(700, 20)
	embers.direction = Vector2(0, -1)
	embers.spread = 25.0
	embers.gravity = Vector2(8, -6)
	embers.initial_velocity_min = 30.0
	embers.initial_velocity_max = 90.0
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 4.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.6, 0.2, 0.0))
	fade.add_point(0.15, Color(1.0, 0.55, 0.2, 0.9))
	fade.set_color(fade.get_point_count() - 1, Color(0.8, 0.2, 0.05, 0.0))
	embers.color_ramp = fade
	return embers
