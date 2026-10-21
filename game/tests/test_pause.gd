extends "res://tests/framework/test_case.gd"
## Integration tests for pausing: controls, focus loss and Android Back.

const MainScene := preload("res://scenes/main.tscn")

var main: Node3D
var player: PlayerController
var pause_controller: PauseController
var pause_menu: PauseMenu


func _ready() -> void:
	main = MainScene.instantiate()
	add_child(main)
	player = main.get_node("Player")
	pause_controller = main.get_node("PauseController")
	pause_menu = main.get_node("PauseMenu")


func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


func test_starts_unpaused_with_menu_hidden() -> void:
	check(not get_tree().paused, "game should start unpaused")
	check(not pause_menu.visible, "pause menu should start hidden")


func test_pause_freezes_player_and_shows_menu() -> void:
	await wait_physics_frames(10)
	pause_controller.set_paused(true)
	check(get_tree().paused, "tree should be paused")
	check(pause_menu.visible, "pause menu should be visible")
	var frozen_at := player.global_position
	Input.action_press(MovementInput.RIGHT)
	await wait_physics_frames(30)
	check_vector_near(player.global_position, frozen_at, 0.0001, "player must not move while paused")
	pause_controller.set_paused(false)
	check(not pause_menu.visible, "pause menu should hide on resume")


func test_movement_held_across_pause_is_released() -> void:
	Input.action_press(MovementInput.RIGHT)
	await wait_physics_frames(30)
	pause_controller.set_paused(true)
	check(not Input.is_action_pressed(MovementInput.RIGHT), "pause should release held movement")
	pause_controller.set_paused(false)
	await wait_physics_frames(20)
	check(player.velocity.is_zero_approx(), "player should be stopped after resuming, got %s" % player.velocity)


func test_pause_key_toggles() -> void:
	_press_key(KEY_ESCAPE)
	check(get_tree().paused, "Esc should pause")
	_press_key(KEY_ESCAPE)
	check(not get_tree().paused, "Esc should resume")
	_press_key(KEY_P)
	check(get_tree().paused, "P should pause")


func test_hud_and_menu_buttons() -> void:
	var pause_button: Button = main.get_node("HUD").get_node("%PauseButton")
	var resume_button: Button = pause_menu.get_node("%ResumeButton")
	pause_button.pressed.emit()
	check(get_tree().paused, "HUD pause button should pause")
	resume_button.pressed.emit()
	check(not get_tree().paused, "Resume button should resume")


func test_focus_loss_pauses() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(get_tree().paused, "losing focus should pause")
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(get_tree().paused, "regaining focus should stay paused until the player resumes")


func test_backgrounding_pauses() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	check(get_tree().paused, "going to the background should pause")


func test_back_button_toggles_pause() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(get_tree().paused, "Back should pause")
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not get_tree().paused, "Back should resume")
