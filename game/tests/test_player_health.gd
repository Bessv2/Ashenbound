extends "res://tests/framework/test_case.gd"
## Integration tests: player health, the HUD health bar, death and the death
## screen, in the real main scene.

var main: Node3D
var player: PlayerController
var health_bar: ProgressBar
var health_text: Label
var death_screen: DeathScreen


func _ready() -> void:
	main = instantiate_main()
	add_child(main)
	player = main.get_node("Player")
	health_bar = main.get_node("HUD").get_node("%HealthBar")
	health_text = main.get_node("HUD").get_node("%HealthText")
	death_screen = main.get_node("DeathScreen")


func test_player_starts_alive_at_full_health() -> void:
	check(player.is_alive() and player.health.current == 100, "player starts at 100 HP")
	check(player.is_in_group(PlayerController.GROUP), "player is in the player group")
	check(health_bar.value == 100.0 and health_text.text == "100 / 100", "HUD shows full health")
	check(not death_screen.visible, "death screen starts hidden")


func test_hud_follows_damage() -> void:
	player.health.apply_damage(30)
	check(health_bar.value == 70.0 and health_bar.max_value == 100.0, "bar at 70 of 100")
	check(health_text.text == "70 / 100", "text shows 70 / 100, got %s" % health_text.text)


func test_death_stops_the_player_and_opens_the_death_screen() -> void:
	await wait_physics_frames(5)
	player.health.apply_damage(player.health.max_health)
	check(not player.is_alive(), "player is dead")
	check(death_screen.visible, "death screen opens")
	var restart: Button = death_screen.get_node("%RestartButton")
	check(restart.disabled, "restart is disabled while the fall plays")

	var at := player.global_position
	Input.action_press(MovementInput.RIGHT)
	Input.action_press(GameplayActions.ATTACK)
	await wait_physics_frames(30)
	check_vector_near(player.global_position, at, 0.01, "a dead player does not move")
	check(not (player.get_node("MeleeAttack") as MeleeAttack).is_busy(), "a dead player does not attack")

	await wait_process_frames(90)  # Past the 0.8 s delay and 0.5 s fade.
	check(not restart.disabled, "restart is enabled once the screen has faded in")
	var visual: Node3D = player.get_node("Visual")
	check_near(visual.rotation.x, -PI * 0.5, 0.01, "the player has toppled over")


func test_death_releases_held_input() -> void:
	Input.action_press(MovementInput.LEFT)
	player.health.apply_damage(player.health.max_health)
	check(not Input.is_action_pressed(MovementInput.LEFT), "held input is released on death")


func test_restart_button_requests_a_restart() -> void:
	var screen: DeathScreen = preload("res://ui/death_screen/death_screen.tscn").instantiate()
	screen.fade_delay = 0.0
	screen.fade_duration = 0.0
	add_child(screen)
	var requests := [0]
	screen.restart_requested.connect(func() -> void: requests[0] += 1)
	screen.open()
	await wait_process_frames(3)
	var restart: Button = screen.get_node("%RestartButton")
	restart.pressed.emit()
	check(requests[0] == 1, "pressing Rise again requests a restart")
