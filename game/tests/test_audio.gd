extends "res://tests/framework/test_case.gd"
## Tests for sound and music (docs/AUDIO.md): every cue has files that load,
## every sound a scene names exists, the volumes are saved and reach the
## buses, combat makes its sounds, the music follows the run, buttons click,
## and sound never changes the fight.

const CryptScene := preload("res://scenes/dungeon/crypt.tscn")
const CatacombsScene := preload("res://scenes/dungeon/catacombs.tscn")
const SkeletonScene := preload("res://scenes/enemies/skeleton_warrior.tscn")
const CultistScene := preload("res://scenes/enemies/dark_cultist.tscn")
const WardenScene := preload("res://scenes/player/warden.tscn")
const TitleScene := preload("res://scenes/title.tscn")
const PauseScene := preload("res://ui/pause_menu/pause_menu.tscn")

const CHARACTER_SCENES := [
	"res://scenes/player/warden.tscn", "res://scenes/player/reaver.tscn",
	"res://scenes/player/hexbinder.tscn", "res://scenes/player/dreadhunter.tscn",
	"res://scenes/player/reliquary.tscn", "res://scenes/player/gravecaller.tscn",
	"res://scenes/player/forsaken_skeleton.tscn",
	"res://scenes/enemies/skeleton_warrior.tscn", "res://scenes/enemies/dark_cultist.tscn",
	"res://scenes/enemies/fallen_knight.tscn", "res://scenes/enemies/ghoul.tscn",
	"res://scenes/enemies/ashen_lord.tscn", "res://scenes/enemies/hollow_king.tscn",
	"res://scenes/enemies/training_dummy.tscn",
]
const PROJECTILE_SCENES := [
	"res://scenes/combat/crossbow_bolt.tscn", "res://scenes/combat/hex_bolt.tscn",
	"res://scenes/combat/shadow_bolt.tscn", "res://scenes/combat/soul_bolt.tscn",
]


func _exit_tree() -> void:
	Audio.stop_all()
	Audio.set_ducked(false)
	# The pause menu test saves its volumes: put the defaults back on disk.
	Settings.current = GameSettings.new()
	Settings.save_to(Settings.SETTINGS_PATH)
	Settings.apply()
	Profile.save_path = ""
	Profile.reset()


func _fresh_history() -> void:
	Audio.stop_all()
	Audio.history.clear()


func test_every_cue_has_files_that_load() -> void:
	for cue in SoundFiles.FILES:
		var paths: Array = SoundFiles.FILES[cue]
		check(not paths.is_empty(), "%s has files" % cue)
		for path: String in paths:
			check(load(path) is AudioStream, "%s loads" % path)
	for cue in SoundBank.MIX:
		check(SoundBank.has(cue), "mixed cue %s has files" % cue)
	for track in SoundBank.TRACKS:
		check(SoundBank.has(track), "track %s has a file" % track)
	for id in Dungeons.ORDER:
		check(SoundBank.TRACKS.has(Dungeons.music_of(id)), "%s has music" % id)


func test_every_sound_a_scene_names_exists() -> void:
	var named: Array[String] = []
	for path: String in CHARACTER_SCENES:
		var scene := (load(path) as PackedScene).instantiate()
		var sounds := scene.get_node_or_null(^"Sounds") as CharacterSounds
		check(sounds != null, "%s has its sounds" % path)
		if sounds:
			for cue in [sounds.impact, sounds.hurt, sounds.death, sounds.death_layer, sounds.growl, sounds.footsteps]:
				if cue != &"":
					named.append("%s: %s" % [path.get_file(), cue])
					check(SoundBank.has(cue), "%s names %s" % [path.get_file(), cue])
		for child in scene.get_children():
			if child is MeleeAttack and (child as MeleeAttack).data:
				var data := (child as MeleeAttack).data
				check(data.swing_sound != &"", "%s %s swings audibly" % [path.get_file(), child.name])
				for cue in [data.windup_sound, data.swing_sound]:
					check(cue == &"" or SoundBank.has(cue), "%s %s names %s" % [path.get_file(), child.name, cue])
			if child is Ability:
				var cue := (child as Ability).sound
				check(cue == &"" or SoundBank.has(cue), "%s %s names %s" % [path.get_file(), child.name, cue])
		scene.free()
	check(named.size() > 30, "the scenes name their sounds: %d" % named.size())
	for path: String in PROJECTILE_SCENES:
		var shot := (load(path) as PackedScene).instantiate() as Projectile
		check(SoundBank.has(shot.impact_sound), "%s lands audibly" % path.get_file())
		shot.free()


func test_volumes_are_saved_clamped_and_reach_the_buses() -> void:
	var settings := GameSettings.new()
	check_near(settings.music_volume, 0.7, 0.001, "music at 70% by default")
	check_near(settings.effects_volume, 1.0, 0.001, "effects at full by default")
	settings.music_volume = 0.25
	settings.effects_volume = 0.5
	var config := ConfigFile.new()
	settings.write_to(config)
	var loaded := GameSettings.new()
	loaded.read_from(config)
	check_near(loaded.music_volume, 0.25, 0.001, "music round-trips")
	check_near(loaded.effects_volume, 0.5, 0.001, "effects round-trip")
	config.set_value(GameSettings.AUDIO, "music_volume", 7.0)
	config.set_value(GameSettings.AUDIO, "effects_volume", "loud")
	loaded.read_from(config)
	check(loaded.music_volume == 1.0 and loaded.effects_volume == 0.5, "clamped, and junk ignored")
	Audio.apply_volumes(loaded)
	var music := AudioServer.get_bus_index(&"Music")
	var effects := AudioServer.get_bus_index(&"Sfx")
	check(music >= 0 and effects >= 0, "the buses exist")
	check_near(AudioServer.get_bus_volume_db(effects), linear_to_db(0.5), 0.01, "effects at half")
	loaded.music_volume = 0.0
	Audio.apply_volumes(loaded)
	check(AudioServer.is_bus_mute(music), "music at zero is off")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(&"World")) == &"Sfx", "the world is under the effects volume")


func test_a_cue_plays_once_per_gap_and_unknown_cues_are_silent() -> void:
	_fresh_history()
	check(Audio.play(&"hit_bone", Vector3.ZERO), "it plays")
	check(not Audio.play(&"hit_bone", Vector3.ZERO), "not again inside its gap")
	check(Audio.play(&"hit_metal", Vector3.ZERO), "another cue does")
	check(not Audio.play(&"no_such_cue") and not Audio.play(&""), "unknown cues are silent")
	check(await wait_until(func() -> bool: return Audio.play(&"hit_bone", Vector3.ZERO), 30), "after its gap it plays again")
	check(Audio.history.count(&"hit_bone") == 2, "and the history says so")


func test_a_blow_swings_strikes_and_kills_audibly_without_changing_damage() -> void:
	_fresh_history()
	add_level(30.0)
	var hero: PlayerController = WardenScene.instantiate()
	add_child(hero)
	var skeleton: EnemyController = SkeletonScene.instantiate()
	skeleton.position = Vector3(0, 0, -1.4)
	skeleton.set_physics_process(false)
	add_child(skeleton)
	await wait_physics_frames(2)
	var before := skeleton.health.current
	hero.attack.try_start(Vector3.FORWARD)
	check(await wait_until(func() -> bool: return skeleton.health.current < before, 120), "the blow lands")
	check(before - skeleton.health.current == 10, "for its usual 10")
	check(Audio.played(&"swing_heavy"), "the greatsword whooshes")
	check(Audio.played(&"hit_bone") and Audio.played(&"hit_thud"), "the skeleton rattles")
	skeleton.health.apply_damage(1000)
	check(Audio.played(&"undead_death") and Audio.played(&"bones_collapse"), "and collapses with a cry")


func test_an_enemy_telegraph_can_be_heard() -> void:
	_fresh_history()
	add_level(30.0)
	var hero: PlayerController = WardenScene.instantiate()
	hero.position = Vector3(0, 0, 7)
	hero.health.invulnerable = true
	add_child(hero)
	var cultist: EnemyController = CultistScene.instantiate()
	add_child(cultist)
	check(await wait_until(func() -> bool: return cultist.state == EnemyController.State.TELEGRAPH, 400),
			"the cultist winds up its bolt")
	check(Audio.played(&"ghost_breath"), "and its chant warns of it")
	check(await wait_until(func() -> bool: return Audio.played(&"spell_cast"), 200), "the bolt leaves with a crack")


func test_the_hero_walks_with_footsteps() -> void:
	_fresh_history()
	add_level(40.0)
	var hero: PlayerController = WardenScene.instantiate()
	add_child(hero)
	await wait_physics_frames(2)
	for i in 60:
		hero.global_position += Vector3(0.1, 0, 0)
		await wait_physics_frames(1)
	check(Audio.history.count(&"footstep") >= 2, "steps as it walks: %d" % Audio.history.count(&"footstep"))


func test_the_music_follows_the_run() -> void:
	_fresh_history()
	var main := instantiate_main(false, CryptScene)
	add_child(main)
	await wait_physics_frames(2)
	check(Audio.music_track == &"music_crypt", "the crypt's own music: %s" % Audio.music_track)
	check(Audio.ambience_track == &"ambience_dungeon", "over the dungeon's bed")
	var sound: SoundDirector = main.get_node("Sound")
	var first: EncounterController = main.level.get_node("Encounters/Ossuary")
	first.start()
	check(Audio.music_track == &"music_combat", "a fight brings the combat music")
	check(await wait_until(func() -> bool:
		for enemy in first.living_enemies():
			var health := Health.of(enemy)
			health.invulnerable = false
			health.apply_damage(health.max_health)
		return first.phase == EncounterController.Phase.CLEARED, 1200), "the room is cleared")
	check(Audio.music_track == &"music_crypt" and Audio.played(&"bell"), "a toll, and the quiet comes back")
	var throne: EncounterController = main.level.get_node("Encounters/Throne")
	throne.start()
	check(await wait_until(func() -> bool: return sound.boss != null, 600), "the Ashen Lord rises")
	check(Audio.music_track == &"music_boss" and Audio.played(&"giant_roar"), "with a roar and the boss music")
	var pause: PauseController = main.get_node("PauseController")
	pause.set_paused(true)
	check(Audio.is_ducked(), "the music dips while paused")
	pause.set_paused(false)
	check(not Audio.is_ducked(), "and comes back")
	(main.get_node("Player") as PlayerController).health.apply_damage(100000)
	check(await wait_until(func() -> bool: return Audio.music_track == &"", 60), "a fall silences the music")
	main.free()
	await wait_physics_frames(2)


func test_the_catacombs_and_the_title_have_their_own_music() -> void:
	_fresh_history()
	var main := instantiate_main(false, CatacombsScene)
	add_child(main)
	await wait_physics_frames(2)
	check(Audio.music_track == &"music_catacombs", "the catacombs: %s" % Audio.music_track)
	main.free()
	var title: TitleScreen = TitleScene.instantiate()
	add_child(title)
	title.enter_requested.disconnect(title._go_to_crypt)
	check(Audio.music_track == &"music_title" and Audio.ambience_track == &"", "the title theme, no dungeon bed")
	title.free()


func test_buttons_click_and_the_pause_menu_sets_the_volumes() -> void:
	_fresh_history()
	var button := Button.new()
	add_child(button)
	button.pressed.emit()
	check(Audio.played(&"ui_click"), "a button clicks")
	_fresh_history()
	var quiet := Button.new()
	quiet.set_meta(&"silent", true)
	add_child(quiet)
	quiet.pressed.emit()
	check(not Audio.played(&"ui_click"), "unless it is meant to be silent")
	var menu: PauseMenu = PauseScene.instantiate()
	add_child(menu)
	var slider := menu.find_child("MusicSlider", true, false) as HSlider
	check(slider != null and is_equal_approx(slider.value, Settings.current.music_volume), "the music slider shows the setting")
	slider.value = 0.3
	check_near(Settings.current.music_volume, 0.3, 0.001, "moving it sets the music volume")
	var saved := ConfigFile.new()
	check(saved.load(Settings.SETTINGS_PATH) == OK and is_equal_approx(float(saved.get_value(GameSettings.AUDIO, "music_volume", 0.0)), 0.3),
			"and saves it")
	(menu.find_child("EffectsSlider", true, false) as HSlider).value = 0.0
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Sfx")), "effects at zero are off")
	menu.free()
	button.free()
	quiet.free()


func test_world_sounds_pause_with_the_game() -> void:
	var world := Audio.get_node(^"World")
	check(world.process_mode == Node.PROCESS_MODE_PAUSABLE, "the world's voices pause")
	check(Audio.process_mode == Node.PROCESS_MODE_ALWAYS, "the interface and the music do not")
	check(world.get_child_count() == Audio.WORLD_VOICES, "a fixed pool of voices")
