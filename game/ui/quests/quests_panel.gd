class_name QuestsPanel
extends CanvasLayer
## The concept sheet's Quest / Mission window (docs/QUESTS.md), with three
## pages: the story quest of each open dungeon (its objectives ticked off and
## its reward), today's three daily challenges, and the achievements. Each
## finished goal has a Claim button; paying goes through Profile, once.

signal close_requested

enum Page { STORY, DAILY, ACHIEVEMENTS }
const PAGE_NAMES := ["Story", "Daily", "Achievements"]
const GOLD := Color("#D9A44C")
const DONE := Color("#7FC97A")

var profile: Node

var _page: Page = Page.STORY
var _tabs: Dictionary[int, Button] = {}
var _list: VBoxContainer
var _message: Label
var _wait: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	if profile == null:
		profile = get_node_or_null(^"/root/Profile")
	_build()
	hide()


func open(page: Page = Page.STORY) -> void:
	_page = page
	_message.text = ""
	_refresh()
	show()
	UiFx.pop_layer(self)
	Audio.play(&"ui_open")


func close() -> void:
	if visible:
		Audio.play(&"ui_close")
	hide()


func show_page(page: Page) -> void:
	_page = page
	_message.text = ""
	_refresh()


## Claims story quest `dungeon_id`, achievement or daily `id` (by page).
## Returns "" or why not.
func press_claim(kind: String, id: String) -> String:
	var problem: String
	match kind:
		"story":
			problem = profile.claim_quest(id)
		"daily":
			problem = profile.claim_daily(id)
		_:
			problem = profile.claim_achievement(id)
	Audio.play(&"pickup_gold" if problem == "" else &"ui_error")
	_message.text = "Claimed." if problem == "" else problem
	_message.add_theme_color_override(&"font_color", DONE if problem == "" else Color("#E0625A"))
	_refresh()
	return problem


func _process(delta: float) -> void:
	if not visible or _page != Page.DAILY:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = 30.0
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
	var window := WindowFrame.new("Quests")
	window.close_pressed.connect(close_requested.emit)
	root.add_child(window)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 8)
	window.add_to_header(tabs)
	for page in Page.values():
		var tab := Button.new()
		tab.name = PAGE_NAMES[page]
		tab.text = PAGE_NAMES[page]
		tab.custom_minimum_size = Vector2(150, 60)
		tab.add_theme_font_size_override(&"font_size", 20)
		tab.pressed.connect(show_page.bind(page))
		tabs.add_child(tab)
		_tabs[page] = tab
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window.content.add_child(_message)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	window.content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 10)
	scroll.add_child(_list)


func _refresh() -> void:
	for page: int in _tabs:
		var chosen := page == _page
		for state in [&"normal", &"hover", &"pressed", &"focus"]:
			_tabs[page].add_theme_stylebox_override(state, UiFx.box(Color(0.07, 0.05, 0.07, 0.92), 6,
					Color("#DB6028") if chosen else Color(0.4, 0.3, 0.22, 0.6), 3 if chosen else 1))
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	match _page:
		Page.STORY:
			_fill_story()
		Page.DAILY:
			_fill_daily()
		_:
			_fill_achievements()


func _card(frame_color: Color = Color(0.4, 0.3, 0.2)) -> VBoxContainer:
	var card := PanelContainer.new()
	var frame := UiFx.box(Color(0.05, 0.045, 0.055, 0.95), 8, frame_color, 2)
	frame.set_content_margin_all(14)
	card.add_theme_stylebox_override(&"panel", frame)
	_list.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	card.add_child(column)
	return column


## A heading row: the title, then on the right the reward and a Claim button
## (shown when `claimable` or `claimed`).
func _heading(column: VBoxContainer, title: String, reward: Dictionary, claimable: bool, claimed: bool,
		kind: String, id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	column.add_child(row)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override(&"font_size", 23)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	row.add_child(_reward_line(reward))
	var claim := Button.new()
	claim.name = "Claim"
	claim.text = "Claimed" if claimed else "Claim"
	claim.disabled = claimed or not claimable
	claim.custom_minimum_size = Vector2(130, 56)
	claim.pressed.connect(press_claim.bind(kind, id))
	row.add_child(claim)


func _reward_line(reward: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	for id: String in reward:
		var entry := WindowFrame.purse(Materials.icon_of(id), int(reward[id]), Materials.color_of(id))
		entry.tooltip_text = Materials.name_of(id)
		(entry.get_node("Amount") as Label).add_theme_font_size_override(&"font_size", 19)
		row.add_child(entry)
	return row


func _bar(column: VBoxContainer, progress: int, goal: int, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	column.add_child(row)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"DimLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(260, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = goal
	bar.value = progress
	bar.add_theme_stylebox_override(&"background", UiFx.box(Color(0.06, 0.04, 0.03, 0.85), 3, Color(0.35, 0.25, 0.12, 0.8), 1))
	bar.add_theme_stylebox_override(&"fill", UiFx.box(DONE if progress >= goal else Hud.XP_FILL, 3))
	row.add_child(bar)
	var count := Label.new()
	count.text = "%d / %d" % [progress, goal]
	count.custom_minimum_size.x = 110
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(count)


func _fill_story() -> void:
	for id in Dungeons.ORDER:
		if not Quests.STORY.has(id):
			continue
		var quest: Dictionary = Quests.STORY[id]
		var open := Dungeons.is_open(id, profile)
		var claimed: bool = profile.quests_claimed.has(id)
		var complete: bool = profile.quest_complete(id)
		var column := _card(DONE if complete and not claimed else Color(0.4, 0.3, 0.2))
		column.get_parent().name = id
		_heading(column, quest.title if open else "%s (locked)" % quest.title, quest.reward, complete, claimed, "story", id)
		var line := Label.new()
		line.text = quest.line if open else Dungeons.lock_reason(id, profile)
		line.theme_type_variation = &"DimLabel"
		column.add_child(line)
		if not open:
			continue
		for i in quest.objectives.size():
			var done: bool = profile.objective_done(id, i)
			var objective := HBoxContainer.new()
			objective.add_theme_constant_override(&"separation", 10)
			var tick := TextureRect.new()
			tick.texture = Icons.of("check")
			tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tick.custom_minimum_size = Vector2(26, 26)
			tick.modulate = DONE if done else Color(0.35, 0.32, 0.3, 0.6)
			objective.add_child(tick)
			var text := Label.new()
			text.text = quest.texts[i]
			text.add_theme_color_override(&"font_color", DONE if done else Color(0.8, 0.75, 0.68))
			objective.add_child(text)
			column.add_child(objective)
		var item := Label.new()
		item.text = "And a %s item or better" % Rarity.name_of(quest.item_rarity)
		item.add_theme_color_override(&"font_color", Rarity.color_of(quest.item_rarity).lightened(0.25))
		column.add_child(item)


func _fill_daily() -> void:
	var left := 86400 - posmod(int(profile.clock.call()), 86400)
	var note := Label.new()
	note.text = "Three new challenges every day; new ones in %s. Nothing is lost if you skip a day." % OfflineRewards.describe_time(left)
	note.theme_type_variation = &"DimLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(note)
	for challenge: Dictionary in profile.dailies():
		var complete: bool = challenge.progress >= challenge.goal
		var column := _card(DONE if complete and not challenge.claimed else Color(0.4, 0.3, 0.2))
		column.get_parent().name = challenge.id
		_heading(column, challenge.text, challenge.reward, complete, challenge.claimed, "daily", challenge.id)
		_bar(column, challenge.progress, challenge.goal, "Today")


func _fill_achievements() -> void:
	for entry: Array in Quests.ACHIEVEMENTS:
		var id: String = entry[0]
		var progress: Vector2i = profile.achievement_progress(id)
		var claimed: bool = profile.achievements_claimed.has(id)
		var column := _card(DONE if progress.x >= progress.y and not claimed else Color(0.4, 0.3, 0.2))
		column.get_parent().name = id
		_heading(column, entry[1], entry[4], progress.x >= progress.y, claimed, "achievement", id)
		_bar(column, progress.x, progress.y, Quests.describe(entry[2], entry[3]))
