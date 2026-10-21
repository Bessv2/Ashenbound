extends "res://tests/framework/test_case.gd"
## Tests for the HUD's safe-area fitting.

const WINDOW := Rect2(0, 0, 2400, 1080)
const CANVAS := Vector2(1600, 720)  # 1.5 screen pixels per canvas unit.


func test_full_safe_area_has_no_insets() -> void:
	check(Hud.safe_area_insets(WINDOW, WINDOW, CANVAS) == Vector4.ZERO, "no cutout, no insets")


func test_cutout_on_the_left_is_converted_to_canvas_units() -> void:
	# A landscape phone with its camera cutout on the left: 120 px are unsafe.
	var safe := Rect2(120, 0, 2280, 1080)
	var insets := Hud.safe_area_insets(safe, WINDOW, CANVAS)
	check_near(insets.x, 80.0, 0.001, "left inset")
	check_near(insets.y + insets.z + insets.w, 0.0, 0.001, "other insets")


func test_insets_on_every_side() -> void:
	var safe := Rect2(30, 15, 2400 - 30 - 60, 1080 - 15 - 45)
	var insets := Hud.safe_area_insets(safe, WINDOW, CANVAS)
	check_vector_near(Vector2(insets.x, insets.y), Vector2(20, 10), 0.001, "left, top")
	check_vector_near(Vector2(insets.z, insets.w), Vector2(40, 30), 0.001, "right, bottom")


func test_safe_area_on_another_screen_is_ignored() -> void:
	var other_screen := Rect2(2400, 0, 1920, 1080)
	check(Hud.safe_area_insets(other_screen, WINDOW, CANVAS) == Vector4.ZERO,
			"a safe area that does not overlap the window must not shrink the HUD")


func test_hud_fills_the_screen_on_desktop() -> void:
	var hud: Hud = preload("res://ui/hud/hud.tscn").instantiate()
	add_child(hud)
	var root: Control = hud.get_node("Root")
	check(root.offset_left == 0.0 and root.offset_top == 0.0 and root.offset_right == 0.0
			and root.offset_bottom == 0.0, "desktop HUD should not be inset")
