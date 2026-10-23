extends Node3D
## Entry point of the game scene. Builds the run around a level, and connects
## the UI to game state; the UI only emits requests and never pauses the tree
## or restarts the game itself.

## The playable classes: class id → hero scene. The scene's "Player" is the
## Warden; another chosen class replaces it when the run starts.
const HERO_SCENES := {
	"warden": "res://scenes/player/warden.tscn",
	"reaver": "res://scenes/player/reaver.tscn",
	"hexbinder": "res://scenes/player/hexbinder.tscn",
	"dreadhunter": "res://scenes/player/dreadhunter.tscn",
	"reliquary": "res://scenes/player/reliquary.tscn",
	"gravecaller": "res://scenes/player/gravecaller.tscn",
}

const TITLE_SCENE := "res://scenes/title.tscn"

## The level played, instanced as the child "Level" when the scene starts.
@export var level_scene: PackedScene
## When true, the level is the dungeon chosen on the title screen
## (Profile.dungeon) instead of `level_scene`. Tests turn it off.
@export var use_chosen_dungeon: bool = true
## When false, no encounter starts by itself: a quiet level for practice and
## for tests. Encounters started by room triggers still start.
@export var encounters_start_by_themselves: bool = true
## When false, no enemy rises as a Champion: runs whose rewards must be exact
## (tests).
@export var champions_appear: bool = true

var level: Level
## The crypt tier of this run, from Profile.tier when the scene starts.
var difficulty: Difficulty

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
@onready var _character: CharacterPanel = $Character
@onready var _offline: OfflinePanel = $Offline
@onready var _screen_fx: ScreenFx = $ScreenFx
@onready var _potions: PotionBelt = $Potions
@onready var _sound: SoundDirector = $Sound

## Items picked up this run.
var _loot_found: int = 0


func _ready() -> void:
	_use_chosen_hero()
	_load_level()
	_hud.pause_requested.connect(_pause_controller.set_paused.bind(true))
	_pause_menu.resume_requested.connect(_pause_controller.set_paused.bind(false))
	_pause_menu.leave_requested.connect(leave_to_title)
	_pause_controller.paused_changed.connect(_on_paused_changed)
	_pause_menu.set_open(_pause_controller.is_paused())
	_hud.inventory_requested.connect(open_inventory)
	_inventory.close_requested.connect(_pause_controller.set_paused.bind(false))
	_hud.skills_requested.connect(open_skills)
	_skills.close_requested.connect(_pause_controller.set_paused.bind(false))
	_skills.class_chosen.connect(play_class)
	_hud.character_requested.connect(open_character)
	_character.close_requested.connect(_pause_controller.set_paused.bind(false))
	_offline.close_requested.connect(_pause_controller.set_paused.bind(false))
	# A method, not a lambda: the connection to the autoload goes when Main goes.
	Profile.offline_ready.connect(open_offline_rewards)
	_hud.track_health(_player.health)
	_show_hero_name()
	_screen_fx.track(_player.health)
	_hud.track_dodge(_player.dodge)
	_hud.track_abilities(_player.abilities)
	_potions.health = _player.health
	_hud.track_potions(_potions)
	_run.kill_counted.connect(_potions.on_kill)
	_run.ended.connect(_on_run_ended)
	_connect_shake()
	_run.kill_counted.connect(_on_kill_counted)
	Profile.leveled_up.connect(_on_leveled_up)
	_run.kill_counted.connect(_loot.on_enemy_killed)
	_loot.collected.connect(_on_loot_collected)
	_death_screen.restart_requested.connect(_on_restart_chosen)
	_death_screen.alternate_requested.connect(_on_alternate_chosen)
	_sound.watch_run(_run)
	_sound.watch_loot(_loot)
	_sound.watch_potions(_potions)
	_sound.watch_pause(_pause_controller)
	open_offline_rewards()
	if difficulty.tier > 1:
		_hud.show_toast("Tier %d: the dead grow stronger" % difficulty.tier, Color("#D9A44C"))


## The class being played: Profile's choice when it is playable, else the
## Warden.
static func hero_class_of(profile: Node) -> String:
	return profile.hero_class if HERO_SCENES.has(profile.hero_class) else "warden"


## Replaces the scene's Warden with the chosen class's hero, in the same
## place and under the same name, before anything uses it.
func _use_chosen_hero() -> void:
	var chosen: String = hero_class_of(Profile)
	if _player.scene_file_path == HERO_SCENES[chosen]:
		return
	var hero := (load(HERO_SCENES[chosen]) as PackedScene).instantiate() as PlayerController
	hero.camera = _player.camera
	hero.transform = _player.transform
	var index := _player.get_index()
	remove_child(_player)
	_player.free()
	hero.name = "Player"
	add_child(hero)
	move_child(hero, index)
	_player = hero
	_camera_rig.target = hero
	_camera_rig.snap_to_target()
	_run.track_player(hero.health)


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
		if enemy is EnemyController and (Champion.of(enemy) or not (enemy as EnemyController).champion_eligible):
			_camera_rig.add_trauma(0.6)
			HitStop.trigger(get_tree(), 0.14))


func _on_settings_changed(settings: GameSettings) -> void:
	_camera_rig.shake_enabled = settings.screen_shake


## Opens the bag; the game waits while it is open.
func open_inventory() -> void:
	if _run.is_over():
		return
	_inventory.open()
	_pause_controller.set_paused(true)


## Shows what time away earned, when there is something to collect; the
## game waits until it is collected.
func open_offline_rewards() -> void:
	if _run.is_over() or _offline.visible or not _offline.has_rewards():
		return
	_offline.open()
	_pause_controller.set_paused(true)


## Switches to `class_id` (when playable) and starts a new run with it.
func play_class(class_id: String) -> void:
	if not HERO_SCENES.has(class_id):
		return
	Profile.select_class(class_id)
	restart()


## Opens the character sheet; the game waits while it is open.
func open_character() -> void:
	if _run.is_over():
		return
	var stats := _player.get_node_or_null(^"Stats") as CharacterStats
	if stats == null:
		return
	var color := _player.abilities[0].hud_color if not _player.abilities.is_empty() else Color.WHITE
	_character.open(stats.rows(), hero_class_of(Profile), stats.skill_tree.class_title if stats.skill_tree else "",
			color.lerp(Color.WHITE, 0.25))
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
	_pause_menu.set_open(paused and not _inventory.visible and not _skills.visible and not _offline.visible
			and not _character.visible)
	if not paused:
		_inventory.close()
		_skills.close()
		_character.close()
		# Unpaused without collecting: the time stays banked for later.
		_offline.hide()


## Goes back to the title screen. Rewards already paid are kept; the run's
## own Ash and gold are only paid when it ends, so leaving forfeits them.
func leave_to_title() -> void:
	GameplayActions.release_all()
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


## Starts the scene over from scratch.
func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _load_level() -> void:
	if use_chosen_dungeon:
		level_scene = load(Dungeons.scene_path(Profile.dungeon))
	if level_scene == null:
		push_error("Main has no level to play.")
		return
	level = level_scene.instantiate() as Level
	level.name = "Level"
	difficulty = Difficulty.new(Profile.tier)
	if not champions_appear:
		difficulty.champion_chance_override = 0.0
	for node in level.find_children("*", "Node3D", true, false):
		if node is EncounterController:
			node.difficulty = difficulty
			if not encounters_start_by_themselves:
				node.auto_start = false
	add_child(level)
	move_child(level, 0)
	_apply_look()
	if level.player_start:
		_player.global_transform = level.player_start.global_transform
		_player.reset_physics_interpolation()
		_camera_rig.snap_to_target()
	_run.watch(level.encounters)
	_hud.track_minimap(level, _player, _camera_rig.yaw_degrees)
	_sound.watch_level(level, Dungeons.id_of_scene(level_scene.resource_path))
	for node in level.find_children("*", "Node3D", true, false):
		if node is EncounterController:
			var encounter := node as EncounterController
			if encounter.title != "":
				encounter.started.connect(_on_encounter_started.bind(encounter))
			encounter.champion_spawned.connect(_on_champion_spawned)
	_loot.item_level = difficulty.item_level(level.item_level)
	_loot.chance_scale = difficulty.drop_chance_scale()
	_loot.rarity_scale = difficulty.rarity_scale()


## Looks A and B (ArtStyle) restyle the level's surfaces and its grade.
func _apply_look() -> void:
	ArtStyle.dress_world(level)
	for node in level.find_children("*", "WorldEnvironment", true, false):
		var world := node as WorldEnvironment
		world.environment = ArtStyle.environment_for(world.environment)


func _exit_tree() -> void:
	# A freeze must never outlive the run.
	HitStop.reset()


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
	_hud.show_banner("Level %d" % new_level, "A skill point to spend", Color("#D9A44C"))


func _on_champion_spawned(enemy: EnemyController) -> void:
	var champion := Champion.of(enemy)
	_hud.show_toast("A champion rises: %s" % champion.title,
			Champion.AFFIX_COLORS[champion.affixes[0]].lerp(Color.WHITE, 0.3))


func _on_encounter_started(encounter: EncounterController) -> void:
	_hud.show_banner(encounter.title, encounter.subtitle, encounter.title_color)


## The hero's class name, in the colour of its first ability, at the top left.
func _show_hero_name() -> void:
	var stats := _player.get_node_or_null(^"Stats") as CharacterStats
	if stats == null or stats.skill_tree == null:
		return
	var color := _player.abilities[0].hud_color if not _player.abilities.is_empty() else Color.WHITE
	_hud.set_hero(stats.skill_tree.class_title, color.lerp(Color.WHITE, 0.25), hero_class_of(Profile))


## Seconds between the killing blow that wins the run and the summary.
const VICTORY_SUMMARY_DELAY := 2.0


func _on_run_ended(victory: bool) -> void:
	GameplayActions.release_all()
	HitStop.reset()
	_potions.input_enabled = false
	# The reward is paid once, at the end of the run; claim_reward() refuses
	# any second attempt for the same run.
	_run.claim_reward()
	if not victory:
		_death_screen.open("", "", "", summary_text(), -1.0,
				"Lower to tier %d" % (difficulty.tier - 1) if difficulty.tier > 1 else "")
		return
	Profile.complete_tier(difficulty.tier)
	# The run is won: nothing can hurt or move the Warden any more, so what
	# still lies on the floor is gathered for him.
	_loot.collect_all()
	_player.input_enabled = false
	_player.health.invulnerable = true
	if difficulty.tier < Profile.tier_unlocked:
		_death_screen.open(level.victory_title, "Deeper, the dead stir.", "Descend to tier %d" % (difficulty.tier + 1),
				summary_text(), VICTORY_SUMMARY_DELAY, "Replay tier %d" % difficulty.tier)
	else:
		_death_screen.open(level.victory_title, "The ash settles, for now.", "Play again",
				summary_text(), VICTORY_SUMMARY_DELAY)


## The tier an end-screen button leads to: the main button goes deeper after
## a win and retries the tier after a fall; the second button replays the
## tier after a win and goes one lower after a fall. Profile keeps it within
## the open tiers.
func tier_after(main_button: bool) -> int:
	var won := _run.result == RunController.Result.VICTORY
	if main_button:
		return difficulty.tier + 1 if won else difficulty.tier
	return difficulty.tier if won else difficulty.tier - 1


func _on_restart_chosen() -> void:
	Profile.select_tier(tier_after(true))
	restart()


func _on_alternate_chosen() -> void:
	Profile.select_tier(tier_after(false))
	restart()


## The run's summary, as shown on the end screen.
func summary_text() -> String:
	var seconds := int(_run.elapsed)
	return "Tier %d    Time %d:%02d    Enemies slain %d    Damage taken %d\nAsh earned %d    Gold earned %d    Items found %d" % [
			difficulty.tier, seconds / 60, seconds % 60, _run.kills, _run.damage_taken, _run.ash, _run.gold, _loot_found]
