class_name Hud
extends CanvasLayer
## In-game overlay: the hero's name, health and XP, the menu buttons, touch
## controls, banners (rooms, bosses, level-ups), messages and a debug readout.
## Emits requests; it does not change game state itself.
##
## The bars move rather than jump: health drops at once and a pale trail
## follows it down a moment later, so a hit's size reads at a glance; XP
## fills smoothly.

signal pause_requested
signal inventory_requested
signal skills_requested

@onready var _root: Control = $Root
@onready var _pause_button: Button = %PauseButton
@onready var _joystick: TouchJoystick = %TouchJoystick
@onready var _debug_label: Label = %DebugLabel
@onready var _controls_hint: Label = %ControlsHint
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_text: Label = %HealthText
@onready var _dodge_button: TouchActionButton = %DodgeButton

const HEALTH_FILL := Color("#B3261E")
const HEALTH_TRAIL := Color("#F2C9A0")
const XP_FILL := Color("#D9A44C")

var _health: Health
var _toasts: VBoxContainer
var _banner: Banner
var _health_trail: ProgressBar
var _health_tween: Tween
var _trail_tween: Tween
var _xp_tween: Tween
var _shown_level: int = 0


func _ready() -> void:
	_toasts = VBoxContainer.new()
	_toasts.name = "Toasts"
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_top = 120.0
	_toasts.offset_left = -300.0
	_toasts.offset_right = 300.0
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.add_child(_toasts)
	_banner = Banner.new()
	_banner.name = "Banner"
	_root.add_child(_banner)
	_style_bars()
	_pause_button.pressed.connect(pause_requested.emit)
	(%BagButton as Button).pressed.connect(inventory_requested.emit)
	(%SkillsButton as Button).pressed.connect(skills_requested.emit)
	var profile := get_node_or_null(^"/root/Profile")
	if profile:
		profile.changed.connect(_update_level.bind(profile))
		_update_level(profile)
	_debug_label.visible = OS.is_debug_build()
	# Not DisplayServer.is_touchscreen_available(): mouse-to-touch emulation
	# (used to test the joystick on desktop) makes that true everywhere.
	_controls_hint.visible = not OS.has_feature("mobile")
	Settings.changed.connect(_apply_settings)
	_apply_settings(Settings.current)
	get_viewport().size_changed.connect(_fit_to_safe_area)
	_fit_to_safe_area()


## Shows the hero's class name in its colour where the game's title was.
func set_hero(title: String, color: Color) -> void:
	var label := $Root/TopBar/Row/TitleBlock/Title as Label
	label.text = title.to_upper()
	label.modulate = color


## Shows a big title (a room, a boss, a level gained) for a moment.
func show_banner(title: String, subtitle: String = "", color: Color = Color("#E8D9C0")) -> void:
	_banner.show_banner(title, subtitle, color)


func banner() -> Banner:
	return _banner


func _style_bars() -> void:
	var health := _health_bar
	health.add_theme_stylebox_override(&"background", StyleBoxEmpty.new())
	health.add_theme_stylebox_override(&"fill", UiFx.box(HEALTH_FILL, 3))
	# The trail sits behind the bar: the bar's own background is empty, so
	# the trail's background is the frame and its fill shows where health
	# was a moment ago.
	_health_trail = ProgressBar.new()
	_health_trail.name = "Trail"
	_health_trail.show_percentage = false
	_health_trail.show_behind_parent = true
	_health_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_health_trail.add_theme_stylebox_override(&"background", UiFx.box(Color(0.06, 0.03, 0.04, 0.85), 3, Color(0.45, 0.22, 0.12, 0.9), 1))
	_health_trail.add_theme_stylebox_override(&"fill", UiFx.box(HEALTH_TRAIL, 3))
	health.add_child(_health_trail)
	var xp := %XpBar as ProgressBar
	xp.add_theme_stylebox_override(&"background", UiFx.box(Color(0.06, 0.04, 0.03, 0.85), 2, Color(0.35, 0.25, 0.12, 0.8), 1))
	xp.add_theme_stylebox_override(&"fill", UiFx.box(XP_FILL, 2))


## Where the trail behind the health bar is (for tests).
func health_trail_value() -> float:
	return _health_trail.value


func _update_level(profile: Node) -> void:
	var bar := %XpBar as ProgressBar
	var levelled: bool = _shown_level != 0 and profile.level > _shown_level
	_shown_level = profile.level
	bar.max_value = profile.xp_to_next(profile.level)
	if _xp_tween:
		_xp_tween.kill()
	if levelled or not is_node_ready():
		bar.value = profile.xp
	else:
		_xp_tween = create_tween()
		_xp_tween.tween_property(bar, "value", float(profile.xp), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var points: int = profile.points_available(profile.hero_class)
	(%LevelText as Label).text = "Level %d" % profile.level + ("  ·  %d to spend" % points if points > 0 else "")


## Shows `text` for a moment above the controls (loot picked up). New
## messages stack below older ones.
func show_toast(text: String, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override(&"font_size", 30)
	label.add_theme_constant_override(&"outline_size", 8)
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(label)
	# Slides in from the side and settles.
	label.position.x = 60.0
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.set_parallel()
	tween.tween_property(label, "modulate:a", color.a, 0.18)
	tween.tween_property(label, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


## Messages shown now.
func toasts() -> Array[Label]:
	var list: Array[Label] = []
	for child in _toasts.get_children():
		list.append(child)
	return list


## Shows `health` in the health bar and keeps it up to date.
func track_health(health: Health) -> void:
	_health = health
	health.damaged.connect(_on_health_damaged.unbind(2))
	health.healed.connect(_update_health.unbind(2))
	health.revived.connect(_update_health)
	_update_health()
	_health_trail.value = health.current


func _on_health_damaged() -> void:
	_update_health()
	UiFx.flash(_health_bar, Color(2.2, 1.6, 1.6), 0.3)


## Shows `dodge`'s cooldown on the dodge button.
func track_dodge(dodge: Dodge) -> void:
	_dodge_button.cooldown = dodge.cooldown_fraction


## Labels each ability button after the ability on its action and shows that
## ability's cooldown. Buttons whose action has no ability are hidden.
func track_abilities(abilities: Array[Ability]) -> void:
	for button: TouchActionButton in [%CleaveButton, %GuardButton, %BrandButton]:
		var match_index := abilities.find_custom(func(a: Ability) -> bool: return a.action == button.action)
		button.visible = match_index >= 0
		if match_index >= 0:
			var ability := abilities[match_index]
			button.label = ability.display_name
			button.cooldown = ability.cooldown_fraction
			button.set_accent(ability.hud_color)
			button.queue_redraw()


func _update_health() -> void:
	_health_bar.max_value = _health.max_health
	_health_trail.max_value = _health.max_health
	_health_text.text = "%d / %d" % [_health.current, _health.max_health]
	var target := float(_health.current)
	if _health_tween:
		_health_tween.kill()
	if _trail_tween:
		_trail_tween.kill()
	if target < _health_bar.value:
		# Down at once; the trail follows after a beat.
		_health_bar.value = target
		_trail_tween = create_tween()
		_trail_tween.tween_interval(0.35)
		_trail_tween.tween_property(_health_trail, "value", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		# Healing fills smoothly, trail and all.
		_health_trail.value = maxf(_health_trail.value, target)
		_health_tween = create_tween().set_parallel()
		_health_tween.tween_property(_health_bar, "value", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_health_tween.tween_property(_health_trail, "value", target, 0.3)


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
