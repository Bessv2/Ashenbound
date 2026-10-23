class_name SoundDirector
extends Node
## The run's music and the sounds of its world events. Main hands it the
## level and the run's systems; it only listens. The music follows the run:
## the dungeon's own track while exploring, the combat track while a room's
## encounter is on, the boss track once a boss rises, a tolling bell when
## the run ends. Gates, loot, potions, champions and levels have their own
## sounds. Sound only: nothing here changes what happens.

## The track played while exploring (Dungeons.INFO "music").
var explore_track: StringName = &"music_crypt"
## Encounters started and not yet cleared.
var fighting: int = 0
## The boss of this run once it has risen.
var boss: AshenLord

var _over: bool = false


func _ready() -> void:
	# A method, not a lambda: the connection to the autoload goes when this goes.
	Profile.leveled_up.connect(_on_leveled_up)


## Starts the dungeon's music and bed and listens to its encounters and gates.
func watch_level(level: Level, dungeon_id: String) -> void:
	explore_track = Dungeons.music_of(dungeon_id)
	Audio.play_music(explore_track)
	Audio.play_ambience(&"ambience_dungeon")
	for encounter in level.encounters:
		encounter.started.connect(_on_encounter_started)
		encounter.cleared.connect(_on_encounter_cleared)
		encounter.wave_started.connect(_on_wave_started.bind(encounter).unbind(1))
		encounter.champion_spawned.connect(_on_champion_spawned)
	for node in level.find_children("*", "Node3D", true, false):
		if node is CryptGate:
			(node as CryptGate).changed.connect(_on_gate_changed.bind(node))


func watch_run(run: RunController) -> void:
	run.ended.connect(_on_run_ended)


func watch_loot(loot: LootDropper) -> void:
	loot.dropped.connect(_on_loot_dropped)
	loot.collected.connect(func(_item: ItemInstance) -> void: Audio.play(&"pickup_gear"))


func watch_potions(belt: PotionBelt) -> void:
	belt.drunk.connect(func(_amount: int) -> void: Audio.play(&"potion_drink"))
	var charges := [belt.charges]
	belt.changed.connect(func() -> void:
		if belt.charges > charges[0]:
			Audio.play(&"potion_refill")
		charges[0] = belt.charges)


## The music dips while the game waits.
func watch_pause(pause: PauseController) -> void:
	pause.paused_changed.connect(Audio.set_ducked)


func _on_encounter_started() -> void:
	fighting += 1
	if boss == null and not _over:
		Audio.play_music(&"music_combat")


func _on_encounter_cleared() -> void:
	fighting = maxi(fighting - 1, 0)
	if _over:
		return
	# The room is won: a low toll, and the quiet comes back.
	Audio.play(&"bell", Vector3.INF, 0.75, -3.0)
	if fighting == 0:
		boss = null
		Audio.play_music(explore_track)


func _on_wave_started(encounter: EncounterController) -> void:
	for enemy in encounter.living_enemies():
		if enemy is AshenLord and enemy != boss:
			boss = enemy as AshenLord
			boss.phase_changed.connect(_on_boss_phase.unbind(1))
			Audio.play_music(&"music_boss", 0.8)
			_on_boss_phase()


## The boss roars as it rises and as each phase begins.
func _on_boss_phase() -> void:
	if is_instance_valid(boss):
		Audio.play(&"giant_roar", boss.global_position + Vector3.UP * 2.0, 0.75, 3.0)


func _on_champion_spawned(enemy: EnemyController) -> void:
	Audio.play(&"beast_roar", enemy.global_position + Vector3.UP, 0.85)


func _on_gate_changed(open: bool, gate: CryptGate) -> void:
	Audio.play(&"gate_chains", gate.global_position, 0.8)
	if not open:
		Audio.play(&"gate_slam", gate.global_position, 0.7)


## Better finds sound brighter; Legendary and Mythic ring a bell too.
func _on_loot_dropped(pickup: LootPickup) -> void:
	var rarity := pickup.item.rarity if pickup.item else 0
	if rarity < Rarity.Tier.RARE:
		Audio.play(&"loot_drop", pickup.global_position)
		return
	Audio.play(&"loot_rare", pickup.global_position, 1.0 + 0.1 * (rarity - Rarity.Tier.RARE), 2.0)
	if rarity >= Rarity.Tier.LEGENDARY:
		Audio.play(&"bell", pickup.global_position, 1.5, 2.0)


func _on_leveled_up(_level: int) -> void:
	Audio.play(&"ui_confirm")
	Audio.play(&"bell", Vector3.INF, 1.2)


func _on_run_ended(victory: bool) -> void:
	_over = true
	if victory:
		Audio.play(&"bell", Vector3.INF, 0.6, 3.0)
		Audio.play_music(explore_track, 3.0)
	else:
		Audio.play(&"bell", Vector3.INF, 0.45, 3.0)
		Audio.play(&"ghost_moan", Vector3.INF, 0.7)
		Audio.play_music(&"", 2.5)
