extends "res://tests/framework/test_case.gd"
## Tests for the second dungeon (docs/dungeons/forgotten_catacombs.md): the
## Ghoul, the Hollow King, the catacombs' rooms and encounters, a full run,
## and choosing the dungeon.

const CatacombsScene := preload("res://scenes/dungeon/catacombs.tscn")
const GhoulScene := preload("res://scenes/enemies/ghoul.tscn")
const KingScene := preload("res://scenes/enemies/hollow_king.tscn")
const WardenScene := preload("res://scenes/player/warden.tscn")
const TitleScene := preload("res://scenes/title.tscn")

## Ash for a full catacombs run: Gallery 5 Ghouls, then 2 Skeletons, 2 Ghouls
## and a Cultist (2); Vault 2 Cultists and 2 Skeletons, 4 Ghouls, then the
## Fallen Knight (10) and 2 Cultists; Pit the Knight and 3 Ghouls, then 5
## Ghouls; the Hollow King (60).
const CATACOMBS_ASH := (5 + 2 + 2 + 2) + (4 + 2 + 4 + 10 + 4) + (10 + 3 + 5) + 60
const ROOMS := [["Gallery", -22.0], ["Vault", -50.0], ["Pit", -80.0], ["Throne", -108.0]]


func _exit_tree() -> void:
	Profile.save_path = ""
	Profile.reset()


func _add_catacombs() -> Node3D:
	var main := instantiate_main(false, CatacombsScene)
	add_child(main)
	return main


## Walks into each combat room and kills everything there, in order.
func _clear_catacombs(main: Node3D) -> bool:
	var player: PlayerController = main.get_node("Player")
	for room: Array in ROOMS:
		player.global_position = Vector3(0, 0, room[1])
		player.reset_physics_interpolation()
		var encounter: EncounterController = main.level.get_node("Encounters/" + room[0])
		var done := await wait_until(func() -> bool:
			for enemy in encounter.living_enemies():
				var health := Health.of(enemy)
				health.invulnerable = false
				health.apply_damage(health.max_health)
			return encounter.phase == EncounterController.Phase.CLEARED, 1200)
		if not done:
			return false
		await wait_physics_frames(2)
	return true


func test_the_ghoul_is_fast_frail_and_quick_to_strike() -> void:
	add_level(30.0)
	var ghoul: EnemyController = GhoulScene.instantiate()
	add_child(ghoul)
	check(ghoul.health.max_health == 18 and ghoul.movement.move_speed > 4.5, "18 health, faster than a skeleton")
	check(ghoul.attack.data.windup < 0.4 and ghoul.attack.data.damage == 7, "a quick 7-damage claw")
	check(ghoul.champion_eligible and ghoul.xp_value == 8 and ghoul.ash_value == 1, "an ordinary enemy")
	var hero: PlayerController = WardenScene.instantiate()
	hero.position = Vector3(0, 0, 6)
	add_child(hero)
	var before := hero.health.current
	check(await wait_until(func() -> bool: return hero.health.current < before, 240), "it runs the hero down and claws")
	check(before - hero.health.current == 7, "for 7: %d" % (before - hero.health.current))


func test_the_hollow_king_fires_a_volley_and_summons_ghouls() -> void:
	add_level(60.0)
	var hero: PlayerController = WardenScene.instantiate()
	hero.position = Vector3(0, 0, 8)
	hero.health.invulnerable = true
	add_child(hero)
	var king: AshenLord = KingScene.instantiate()
	# Inside a 3D parent, as in a level, so its adds have somewhere to rise.
	var hall := Node3D.new()
	add_child(hall)
	hall.add_child(king)
	check(king.display_title == "THE HOLLOW KING" and king.health.max_health == 700, "700 health, its own name")
	check(king.add_scene.resource_path == GhoulScene.resource_path and king.summon_count == 4, "it raises four Ghouls")
	check(await wait_until(func() -> bool: return king.current_attack == king.attack and king.state == EnemyController.State.TELEGRAPH, 300),
			"it winds up its volley from range")
	check(await wait_until(func() -> bool: return hall.find_children("*", "Projectile", false, false).size() == 3, 120),
			"three soul bolts fly at once")
	var bolts := hall.find_children("*", "Projectile", false, false)
	var spread := (bolts[0] as Projectile).direction.angle_to((bolts[2] as Projectile).direction)
	check(spread > deg_to_rad(15.0), "fanned out: %.1f°" % rad_to_deg(spread))
	king.health.apply_damage(roundi(king.health.max_health * 0.45))
	check(king.phase == 2 and king.adds.size() == 4, "phase two raises four Ghouls")
	# It roars, untouchable, as the phase begins; the test ends the roar.
	king.health.invulnerable = false
	king.health.apply_damage(king.health.current)
	await wait_physics_frames(2)
	check(king.health.is_dead(), "the King falls")
	check(king.adds.all(func(a: Node3D) -> bool: return not is_instance_valid(a) or Health.of(a).is_dead()), "and they fall with him")


func test_the_catacombs_are_four_rooms_behind_gates() -> void:
	var main := _add_catacombs()
	await wait_physics_frames(2)
	var level: Level = main.level
	check(level.encounters.size() == 4 and level.item_level == 6, "four encounters, better loot than the crypt")
	for encounter in level.encounters:
		check(encounter.title != "", "%s has a banner" % encounter.name)
		for wave in encounter.data.waves:
			for marker in wave.markers:
				check(encounter.has_node(NodePath(marker)), "%s has its marker %s" % [encounter.name, marker])
	for gate_name in ["Gallery", "Vault", "Pit"]:
		check(not (level.get_node("Navigation/Gates/" + gate_name) as CryptGate).open, "the %s gate starts shut" % gate_name)
	var torch_fire := level.find_children("Fire", "FlameFx", true, false)
	check(not torch_fire.is_empty() and (torch_fire[0] as FlameFx).edge_color.b > 0.8, "its fires burn cold")


func test_a_run_through_the_catacombs_ends_at_the_hollow_throne() -> void:
	var main := _add_catacombs()
	var run: RunController = main.get_node("Run")
	var player: PlayerController = main.get_node("Player")
	player.health.invulnerable = true
	var before: int = Profile.ash
	await wait_physics_frames(5)
	check(await _clear_catacombs(main), "every room cleared")
	check(run.result == RunController.Result.VICTORY, "the run is won")
	check(run.ash == CATACOMBS_ASH, "earned %d Ash, expected %d" % [run.ash, CATACOMBS_ASH])
	check(Profile.ash == before + CATACOMBS_ASH and not run.claim_reward(), "paid once")
	check(await wait_until(func() -> bool: return (main.get_node("DeathScreen") as CanvasLayer).visible, 240), "the summary opens")
	check((main.get_node("DeathScreen") as Node).find_child("Title", true, false).text.contains("catacombs"),
			"with the catacombs' own title")


func test_the_catacombs_open_once_the_crypt_is_cleared() -> void:
	check(Profile.dungeon == Dungeons.CRYPT, "a new profile plays the crypt")
	check(not Profile.select_dungeon(Dungeons.CATACOMBS) and Profile.dungeon == Dungeons.CRYPT, "the catacombs start locked")
	Profile.complete_tier(1)
	check(Profile.select_dungeon(Dungeons.CATACOMBS) and Profile.dungeon == Dungeons.CATACOMBS, "a crypt clear opens them")
	check(Profile.to_dict().dungeon == Dungeons.CATACOMBS, "the choice is saved")
	var saved := Profile.to_dict()
	Profile.reset()
	check(Profile.dungeon == Dungeons.CRYPT, "reset goes back to the crypt")
	saved.erase("dungeon")
	check(Profile._apply(saved) and Profile.dungeon == Dungeons.CRYPT, "an older save plays the crypt")
	saved["dungeon"] = Dungeons.CATACOMBS
	check(Profile._apply(saved) and Profile.dungeon == Dungeons.CATACOMBS, "and the choice loads back")


func test_main_plays_the_chosen_dungeon() -> void:
	Profile.complete_tier(1)
	Profile.select_dungeon(Dungeons.CATACOMBS)
	var main := instantiate_main()
	main.use_chosen_dungeon = true
	add_child(main)
	await wait_physics_frames(2)
	check(main.level.scene_file_path == CatacombsScene.resource_path, "the catacombs are loaded")


func test_the_title_screen_offers_the_open_dungeons() -> void:
	var title: TitleScreen = TitleScene.instantiate()
	add_child(title)
	title.enter_requested.disconnect(title._go_to_crypt)
	var row := title.find_child("Dungeons", true, false)
	var catacombs := row.get_node(Dungeons.CATACOMBS) as Button
	check(row.get_child_count() == 2 and catacombs.disabled, "two dungeons, the second locked")
	check(not title.choose_dungeon(Dungeons.CATACOMBS), "a locked one cannot be chosen")
	Profile.complete_tier(1)
	title._refresh()
	check(not catacombs.disabled and title.choose_dungeon(Dungeons.CATACOMBS), "after a crypt clear it can")
	check((title.find_child("Enter", true, false) as Button).text == "Enter the catacombs", "and the way in says so")
	title.free()
