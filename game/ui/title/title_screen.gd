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
	"reliquary": "Hollow light. Coming later.",
	"gravecaller": "The unburied answer. Coming later.",
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
var _time: float = 0.0


func _ready() -> void:
	if profile == null:
		profile = get_node_or_null(^"/root/Profile")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = load("res://ui/theme/ashen_theme.tres")
	_build()
	enter_requested.connect(_go_to_crypt)
	_refresh()
	_animate_in()
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


## Moves the chosen crypt tier by `step` within the open tiers.
func step_tier(step: int) -> void:
	profile.select_tier(profile.tier + step)
	_refresh()


func enter() -> void:
	enter_requested.emit()


func _go_to_crypt() -> void:
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
	page.offset_top = 30
	page.offset_bottom = -26
	page.add_theme_constant_override(&"separation", 14)
	add_child(page)

	var logo := Label.new()
	logo.name = "Logo"
	logo.text = "ASHENBOUND"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override(&"font_size", 96)
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

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	page.add_child(spacer)

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

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override(&"separation", 18)
	page.add_child(bottom)
	_summary = Label.new()
	_summary.theme_type_variation = &"DimLabel"
	_summary.custom_minimum_size.x = 300
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
	_enter_button.custom_minimum_size = Vector2(330, 88)
	_enter_button.add_theme_font_size_override(&"font_size", 32)
	_enter_button.pressed.connect(enter)
	bottom.add_child(_enter_button)


func _card(tree: SkillTree) -> Button:
	var id := tree.class_id
	var playable := HERO_SCENES.has(id)
	var accent: Color = ACCENTS.get(id, Color.WHITE)
	var card := Button.new()
	card.name = tree.class_title
	card.custom_minimum_size = Vector2(178, 230)
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
	_tier_label.text = "Tier %d" % profile.tier
	_summary.text = "Level %d    Ash %d    Gold %d" % [profile.level, profile.ash, profile.gold]


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
