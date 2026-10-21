class_name PauseController
extends Node
## Owns the game's paused state.
##
## Keeps processing while the tree is paused so it can resume it. Losing focus,
## being sent to the background on Android, or pressing Back pauses the game;
## the player resumes explicitly.

signal paused_changed(paused: bool)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_pause"):
		toggle()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			set_paused(true)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			toggle()


func is_paused() -> bool:
	return get_tree().paused


func toggle() -> void:
	set_paused(not is_paused())


func set_paused(paused: bool) -> void:
	# Drop held movement on every transition. Input that ends while the game is
	# paused or unfocused (a lifted finger, a released key) is never delivered
	# to gameplay, so anything still held would otherwise stay held.
	MovementInput.release_all()
	if get_tree().paused == paused:
		return
	get_tree().paused = paused
	paused_changed.emit(paused)
