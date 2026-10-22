class_name UiFx
extends RefCounted
## Small UI motions shared by the screens: pop a panel in, flash a control.
## Tweens run while the game is paused (menus open over a paused game).


## Fades `item` in from slightly smaller, with a small overshoot.
static func pop_in(item: CanvasItem, seconds: float = 0.22) -> void:
	if item is Control:
		var control := item as Control
		control.pivot_offset = control.size * 0.5
		control.scale = Vector2.ONE * 0.94
	item.modulate.a = 0.0
	var tween := item.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	tween.tween_property(item, "modulate:a", 1.0, seconds * 0.8)
	if item is Control:
		tween.tween_property(item, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pops in each part of a screen built on a CanvasLayer: full-screen
## backdrops fade, panels pop.
static func pop_layer(layer: CanvasLayer) -> void:
	for child in layer.get_children():
		if child is ColorRect:
			var dim := child as ColorRect
			dim.modulate.a = 0.0
			dim.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(dim, "modulate:a", 1.0, 0.18)
		elif child is Control:
			pop_in(child as Control)


## Flashes `item` towards `color` and back.
static func flash(item: CanvasItem, color: Color = Color(2.0, 2.0, 2.0), seconds: float = 0.25) -> void:
	var tween := item.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(item, "self_modulate", color, seconds * 0.25)
	tween.tween_property(item, "self_modulate", Color.WHITE, seconds * 0.75)


## A flat box with rounded corners, for bars and badges.
static func box(color: Color, radius: int = 4, border: Color = Color(0, 0, 0, 0), border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.anti_aliasing = true
	return style
