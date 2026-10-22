extends Node3D
## Entry point of the game scene. Builds the run around a level, and connects
## the UI to game state; the UI only emits requests and never pauses the tree
## or restarts the game itself.

## The level played, instanced as the child "Level" when the scene starts.
@export var level_scene: PackedScene
## When false, no encounter starts by itself: a quiet level for practice and
## for tests. Encounters started by room triggers still start.
@export var encounters_start_by_themselves: bool = true

var level: Level

@onready var _pause_controller: PauseController = $PauseController
@onready var _player: PlayerController = $Player
@onready var _camera_rig: IsometricCameraRig = $CameraRig
@onready var _hud: Hud = $HUD
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _death_screen: DeathScreen = $DeathScreen
@onready var _run: RunController = $Run
@onready var _loot: LootDropper = $Loot
@onready var _inventory: InventoryPanel = $Inventory
@onready var _skills: SkillTreePanel = $Skills

## Items picked up this run.
var _loot_found: int = 0


func _ready() -> void:
	_load_level()
	_hud.pause_requested.connect(_pause_controller.set_paused.bind(true))
	_pause_menu.resume_requested.connect(_pause_controller.set_paused.bind(false))
	_pause_controller.paused_changed.connect(_on_paused_changed)
	_pause_menu.set_open(_pause_controller.is_paused())
	_hud.inventory_requested.connect(open_inventory)
	_inventory.close_requested.connect(_pause_controller.set_paused.bind(false))
	_hud.skills_requested.connect(open_skills)
	_skills.close_requested.connect(_pause_controller.set_paused.bind(false))
	_hud.track_health(_player.health)
	_hud.track_dodge(_player.dodge)
	_hud.track_abilities(_player.abilities)
	_run.ended.connect(_on_run_ended)
	_connect_shake()
	_run.kill_counted.connect(_on_kill_counted)
	Profile.leveled_up.connect(_on_leveled_up)
	_run.kill_counted.connect(_loot.on_enemy_killed)
	_loot.collected.connect(_on_loot_collected)
	_death_screen.restart_requested.connect(restart)


## Shakes the camera when the hero is hurt, lands a critical hit or kills an
## elite or boss. Presentation only.
func _connect_shake() -> void:
	# A method, not a lambda: the connection to the autoload goes when Main goes.
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed(Settings.current)
	_player.health.damaged.connect(func(amount: int, _left: int) -> void:
		_camera_rig.add_trauma(0.3 + amount / 80.0))
	for child in _player.get_children():
		if child is MeleeAttack:
			(child as MeleeAttack).struck.connect(func(targets: Array[Health]) -> void:
				if not targets.is_empty() and (child as MeleeAttack).last_hit_critical:
					_camera_rig.add_trauma(0.25))
	_run.kill_counted.connect(func(enemy: Node3D) -> void:
		if enemy is EnemyController and (enemy as EnemyController).ash_value >= 10:
			_camera_rig.add_trauma(0.6))


func _on_settings_changed(settings: GameSettings) -> void:
	_camera_rig.shake_enabled = settings.screen_shake


## Opens the bag; the game waits while it is open.
func open_inventory() -> void:
	if _run.is_over():
		return
	_inventory.open()
	_pause_controller.set_paused(true)


## Opens the skill trees; the game waits while they are open.
func open_skills() -> void:
	if _run.is_over():
		return
	_skills.open()
	_pause_controller.set_paused(true)


func _on_paused_changed(paused: bool) -> void:
	# The bag and the skills pause the game too; the pause menu only shows
	# without them.
	_pause_menu.set_open(paused and not _inventory.visible and not _skills.visible)
	if not paused:
		_inventory.close()
		_skills.close()


## Starts the scene over from scratch.
func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _load_level() -> void:
	if level_scene == null:
		push_error("Main has no level to play.")
		return
	level = level_scene.instantiate() as Level
	level.name = "Level"
	if not encounters_start_by_themselves:
		for node in level.find_children("*", "Node3D", true, false):
			if node is EncounterController:
				node.auto_start = false
	add_child(level)
	move_child(level, 0)
	if level.player_start:
		_player.global_transform = level.player_start.global_transform
		_player.reset_physics_interpolation()
		_camera_rig.snap_to_target()
	_run.watch(level.encounters)
	_loot.item_level = level.item_level


func _on_loot_collected(item: ItemInstance) -> void:
	_loot_found += 1
	var base := _loot.catalog.base(item.base_id)
	_hud.show_toast("%s %s" % [Rarity.name_of(item.rarity), base.display_name if base else item.base_id],
			Rarity.color_of(item.rarity))


func _on_kill_counted(enemy: Node3D) -> void:
	var stats := _player.get_node_or_null(^"Stats") as CharacterStats
	if stats:
		_player.health.heal(stats.value(ItemStats.HEALTH_ON_KILL))
	if enemy is EnemyController:
		Profile.add_xp((enemy as EnemyController).xp_value)


func _on_leveled_up(new_level: int) -> void:
	_hud.show_toast("Level %d: a skill point to spend" % new_level, Color("#D9A44C"))


## Seconds between the killing blow that wins the run and the summary.
const VICTORY_SUMMARY_DELAY := 2.0


func _on_run_ended(victory: bool) -> void:
	GameplayActions.release_all()
	# The reward is paid once, at the end of the run; claim_reward() refuses
	# any second attempt for the same run.
	_run.claim_reward()
	if not victory:
		_death_screen.open("", "", "", summary_text())
		return
	# The run is won: nothing can hurt or move the Warden any more, so what
	# still lies on the floor is gathered for him.
	_loot.collect_all()
	_player.input_enabled = false
	_player.health.invulnerable = true
	_death_screen.open(level.victory_title, "The ash settles, for now.", "Play again",
			summary_text(), VICTORY_SUMMARY_DELAY)


## The run's summary, as shown on the end screen.
func summary_text() -> String:
	var seconds := int(_run.elapsed)
	return "Time %d:%02d    Enemies slain %d    Damage taken %d\nAsh earned %d    Ash held %d    Items found %d" % [
			seconds / 60, seconds % 60, _run.kills, _run.damage_taken, _run.ash, Profile.ash, _loot_found]
