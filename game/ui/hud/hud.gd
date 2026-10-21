class_name Hud
extends CanvasLayer
## In-game overlay: title, player health, gold, a feed of picked-up items,
## pause button, touch controls and a debug readout. Emits requests; it does
## not change game state itself.

signal pause_requested

## Picked-up items stay listed this long, then fade out.
const FEED_ENTRY_TIME := 3.0
const FEED_MAX_ENTRIES := 5

@onready var _root: Control = $Root
@onready var _pause_button: Button = %PauseButton
@onready var _joystick: TouchJoystick = %TouchJoystick
@onready var _debug_label: Label = %DebugLabel
@onready var _controls_hint: Label = %ControlsHint
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_text: Label = %HealthText
@onready var _dodge_button: TouchActionButton = %DodgeButton
@onready var _gold_label: Label = %GoldLabel
@onready var _loot_feed: VBoxContainer = %LootFeed

var _health: Health


func _ready() -> void:
	_pause_button.pressed.connect(pause_requested.emit)
	_debug_label.visible = OS.is_debug_build()
	# Not DisplayServer.is_touchscreen_available(): mouse-to-touch emulation
	# (used to test the joystick on desktop) makes that true everywhere.
	_controls_hint.visible = not OS.has_feature("mobile")
	Settings.changed.connect(_apply_settings)
	_apply_settings(Settings.current)
	get_viewport().size_changed.connect(_fit_to_safe_area)
	_fit_to_safe_area()


## Shows `health` in the health bar and keeps it up to date.
func track_health(health: Health) -> void:
	_health = health
	health.damaged.connect(_update_health.unbind(2))
	health.revived.connect(_update_health)
	_update_health()


## Shows `dodge`'s cooldown on the dodge button.
func track_dodge(dodge: Dodge) -> void:
	_dodge_button.cooldown = dodge.cooldown_fraction


## Shows `inventory`'s gold, and lists the items it picks up.
func track_inventory(inventory: Inventory) -> void:
	inventory.gold_changed.connect(_show_gold)
	inventory.item_added.connect(_add_feed_entry)
	_show_gold(inventory.gold)


func _show_gold(total: int) -> void:
	_gold_label.text = "%d gold" % total


func _add_feed_entry(item: Item) -> void:
	var entry := Label.new()
	entry.text = item.describe()
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry.add_theme_color_override("font_color", Rarity.text_color_of(item.rarity))
	entry.add_theme_color_override("font_outline_color", Color.BLACK)
	entry.add_theme_constant_override("outline_size", 6)
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loot_feed.add_child(entry)
	while _loot_feed.get_child_count() > FEED_MAX_ENTRIES:
		var oldest := _loot_feed.get_child(0)
		_loot_feed.remove_child(oldest)
		oldest.queue_free()
	var tween := entry.create_tween()
	tween.tween_interval(FEED_ENTRY_TIME)
	tween.tween_property(entry, "modulate:a", 0.0, 0.5)
	tween.tween_callback(entry.queue_free)


func _update_health() -> void:
	_health_bar.max_value = _health.max_health
	_health_bar.value = _health.current
	_health_text.text = "%d / %d" % [_health.current, _health.max_health]


func _process(_delta: float) -> void:
	if _debug_label.visible:
		var intent := MovementInput.get_vector()
		_debug_label.text = "FPS %d   move (%.2f, %.2f)" % [Engine.get_frames_per_second(), intent.x, intent.y]


## Insets in canvas units, as (left, top, right, bottom), that keep content
## inside the display's safe area: clear of camera cutouts and rounded corners.
## safe_area and window_rect are in screen pixels. Returns zero insets when the
## safe area does not overlap the window, which happens on multi-monitor
## desktops where the reported safe area belongs to another screen.
static func safe_area_insets(safe_area: Rect2, window_rect: Rect2, canvas_size: Vector2) -> Vector4:
	if not window_rect.has_area() or not safe_area.intersects(window_rect):
		return Vector4.ZERO
	var scale := canvas_size / window_rect.size
	return Vector4(
			maxf(safe_area.position.x - window_rect.position.x, 0.0) * scale.x,
			maxf(safe_area.position.y - window_rect.position.y, 0.0) * scale.y,
			maxf(window_rect.end.x - safe_area.end.x, 0.0) * scale.x,
			maxf(window_rect.end.y - safe_area.end.y, 0.0) * scale.y)


func _fit_to_safe_area() -> void:
	# Cutouts only exist on phones. On desktop the "safe area" is the usable
	# screen area, which says nothing about where the HUD may draw.
	var insets := Vector4.ZERO
	if OS.has_feature("mobile"):
		var window := get_window()
		insets = safe_area_insets(Rect2(DisplayServer.get_display_safe_area()),
				Rect2(window.position, window.size), get_viewport().get_visible_rect().size)
	_root.offset_left = insets.x
	_root.offset_top = insets.y
	_root.offset_right = -insets.z
	_root.offset_bottom = -insets.w


func _apply_settings(settings: GameSettings) -> void:
	_joystick.dead_zone = settings.joystick_dead_zone
	_joystick.sensitivity = settings.joystick_sensitivity
