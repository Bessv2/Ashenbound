class_name OfflinePanel
extends CanvasLayer
## "While you were away": the time banked by Profile and what it earns
## (docs/OFFLINE_REWARDS.md), with Collect. Main opens it at the start of a
## run or when the app comes back from the background, and pauses the game
## while it is open. Collecting goes through Profile.claim_offline(), which
## empties the bank, so it pays once.
##
## Built in code from the theme's controls, touch first (88 px targets).

signal close_requested

var profile: Node

var _text: Label
var _collect: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	if profile == null:
		profile = get_node_or_null(^"/root/Profile")
	_build()
	hide()


## Whether there is anything to collect.
func has_rewards() -> bool:
	var reward: Dictionary = profile.offline_preview()
	return reward.xp > 0 or reward.gold > 0 or reward.ash > 0


func open() -> void:
	var reward: Dictionary = profile.offline_preview()
	_text.text = "Your Warden kept the crypt's tier %d clear for %s.\n\n+%d XP    +%d gold    +%d Ash" % [
			profile.tier_cleared, OfflineRewards.describe_time(profile.offline_seconds), reward.xp, reward.gold, reward.ash]
	show()
	UiFx.pop_layer(self)
	_collect.grab_focus()


## Pays the rewards and closes. Returns what was paid.
func collect() -> Dictionary:
	var reward: Dictionary = profile.claim_offline()
	hide()
	close_requested.emit()
	return reward


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.02, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.theme = load("res://ui/theme/ashen_theme.tres")
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var items := VBoxContainer.new()
	items.add_theme_constant_override(&"separation", 20)
	panel.add_child(items)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "While you were away"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items.add_child(title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items.add_child(_text)
	var note := Label.new()
	note.theme_type_variation = &"DimLabel"
	note.text = "At most %d hours count. New tiers and bosses still need you." % (OfflineRewards.CAP_SECONDS / 3600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items.add_child(note)
	_collect = Button.new()
	_collect.text = "Collect"
	_collect.custom_minimum_size = Vector2(300, 88)
	_collect.pressed.connect(collect)
	items.add_child(_collect)
