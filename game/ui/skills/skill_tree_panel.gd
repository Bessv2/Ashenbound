class_name SkillTreePanel
extends CanvasLayer
## The skill trees (docs/SKILL_TREES.md): a tab per class, the three branches
## as columns of nodes by tier, and the selected node's card with Learn.
## Points left and Reset at the top. Classes that are not playable yet are
## shown read-only. Learning and resetting go through Profile.
##
## Built in code from the theme's controls, touch first (88 px targets).
## Processes while the game is paused (Main pauses it).

signal close_requested

const TREE_PATHS := [
	"res://resources/skills/warden_tree.tres",
	"res://resources/skills/reaver_tree.tres",
	"res://resources/skills/hexbinder_tree.tres",
	"res://resources/skills/dreadhunter_tree.tres",
	"res://resources/skills/reliquary_tree.tres",
	"res://resources/skills/gravecaller_tree.tres",
]
const NODE_SIZE := Vector2(190, 84)
const LEARNED := Color("#D9A44C")
const OPEN := Color("#9a8f86")
const LOCKED := Color("#4a4440")

var profile: Node
var trees: Array[SkillTree] = []

var _tree_index: int = 0
var _selected: String = ""
var _tabs: HBoxContainer
var _points: Label
var _columns: HBoxContainer
var _card_title: Label
var _card_text: Label
var _learn_button: Button
var _reset_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	if profile == null:
		profile = get_node_or_null(^"/root/Profile")
	for path in TREE_PATHS:
		trees.append(load(path))
	_build()
	hide()
	profile.changed.connect(_refresh)


func open() -> void:
	_tree_index = 0
	_selected = ""
	_refresh()
	show()


func close() -> void:
	hide()


func current_tree() -> SkillTree:
	return trees[_tree_index]


func show_tree(index: int) -> void:
	_tree_index = clampi(index, 0, trees.size() - 1)
	_selected = ""
	_refresh()


func select(node_id: String) -> void:
	_selected = node_id
	_refresh()


## Learns a rank of the selected node. Returns "" or why it could not.
func learn_selected() -> String:
	var problem: String = profile.learn(current_tree(), _selected)
	_refresh()
	return problem


func reset_tree() -> void:
	profile.reset_skills(current_tree().class_id)
	_refresh()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.02, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := MarginContainer.new()
	root.theme = load("res://ui/theme/ashen_theme.tres")
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 28)
	add_child(root)
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 14)
	root.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 10)
	page.add_child(header)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override(&"separation", 8)
	header.add_child(_tabs)
	for i in trees.size():
		var tab := Button.new()
		tab.text = trees[i].class_title
		tab.custom_minimum_size = Vector2(118, 72)
		tab.add_theme_font_size_override(&"font_size", 18)
		tab.pressed.connect(show_tree.bind(i))
		_tabs.add_child(tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_points = Label.new()
	_points.theme_type_variation = &"HeaderLabel"
	header.add_child(_points)
	_reset_button = Button.new()
	_reset_button.text = "Reset"
	_reset_button.custom_minimum_size = Vector2(130, 72)
	_reset_button.pressed.connect(reset_tree)
	header.add_child(_reset_button)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(130, 72)
	close_button.pressed.connect(close_requested.emit)
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 20)
	page.add_child(body)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override(&"separation", 14)
	body.add_child(_columns)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(card)
	var card_items := VBoxContainer.new()
	card_items.add_theme_constant_override(&"separation", 12)
	card.add_child(card_items)
	_card_title = Label.new()
	_card_title.theme_type_variation = &"HeaderLabel"
	_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_items.add_child(_card_title)
	_card_text = Label.new()
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_items.add_child(_card_text)
	_learn_button = Button.new()
	_learn_button.text = "Learn"
	_learn_button.custom_minimum_size = Vector2(0, 88)
	_learn_button.pressed.connect(learn_selected)
	card_items.add_child(_learn_button)


func _refresh() -> void:
	if _columns == null:
		return
	var tree := current_tree()
	var held: Dictionary = profile.ranks(tree.class_id)
	var points: int = profile.points_available(tree.class_id)
	for i in _tabs.get_child_count():
		(_tabs.get_child(i) as Button).modulate = Color.WHITE if i == _tree_index else Color(1, 1, 1, 0.55)
	_points.text = ("%d points" % points) if tree.playable else "Preview"
	_reset_button.visible = tree.playable
	for child in _columns.get_children():
		child.queue_free()
	for branch in tree.branches.size():
		var column := VBoxContainer.new()
		column.add_theme_constant_override(&"separation", 10)
		_columns.add_child(column)
		var title := Label.new()
		title.text = tree.branches[branch]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_color_override(&"font_color", LEARNED)
		column.add_child(title)
		var in_branch := tree.nodes.filter(func(n: SkillNode) -> bool: return n.branch == branch)
		in_branch.sort_custom(func(a: SkillNode, b: SkillNode) -> bool: return a.tier < b.tier)
		for skill: SkillNode in in_branch:
			column.add_child(_node_button(tree, skill, held, points))
	_show_card(tree, held, points)


func _node_button(tree: SkillTree, skill: SkillNode, held: Dictionary, points: int) -> Button:
	var rank := int(held.get(skill.id, 0))
	var button := Button.new()
	button.custom_minimum_size = NODE_SIZE
	button.add_theme_font_size_override(&"font_size", 17)
	button.text = "%s\n%d / %d" % [skill.display_name, rank, skill.max_rank]
	button.pressed.connect(select.bind(skill.id))
	var color := LEARNED if rank > 0 else (OPEN if tree.learn_problem(held, skill.id, maxi(points, 1)) == "" else LOCKED)
	for state in [&"normal", &"hover", &"pressed", &"focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color.darkened(0.8)
		box.border_color = Color.WHITE if skill.id == _selected else color
		box.set_border_width_all(3)
		box.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override(&"font_color", color.lightened(0.3))
	return button


func _show_card(tree: SkillTree, held: Dictionary, points: int) -> void:
	var skill := tree.node(_selected)
	if skill == null:
		_card_title.text = tree.class_title
		_card_text.text = "Tap a skill to see what it does." if tree.playable \
				else "%s's tree, shown ahead of the class. Its skills can be learned once the %s is playable." % [tree.class_title, tree.class_title]
		_learn_button.visible = false
		return
	var rank := int(held.get(skill.id, 0))
	_card_title.text = skill.display_name
	var text := "%s\n\nRank %d of %d" % [skill.description, rank, skill.max_rank]
	if skill.requires != "":
		var needed := tree.node(skill.requires)
		text += "\nRequires %s" % (needed.display_name if needed else skill.requires)
	var problem := tree.learn_problem(held, skill.id, points)
	if problem != "" and rank < skill.max_rank:
		text += "\n\n" + problem
	_card_text.text = text
	_learn_button.visible = tree.playable
	_learn_button.disabled = problem != ""
