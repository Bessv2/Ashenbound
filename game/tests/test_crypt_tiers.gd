extends "res://tests/framework/test_case.gd"
## Tests for crypt tiers (docs/dungeons/tiers.md): scaling, unlocking,
## choosing, saving, and a full run at a higher tier.

const CryptScene := preload("res://scenes/dungeon/crypt.tscn")
const SkeletonScene := preload("res://scenes/enemies/skeleton_warrior.tscn")
const CultistScene := preload("res://scenes/enemies/dark_cultist.tscn")
const LordScene := preload("res://scenes/enemies/ashen_lord.tscn")
const SAVE := "user://test_tiers_profile.json"
## Ash for a full tier 1 run (see test_run_summary.gd).
const CRYPT_ASH := 3 + 3 + 2 + 2 * 2 + 4 + 10 + 50


func _exit_tree() -> void:
	for path in [SAVE, "user://test_tiers_profile.backup.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	Profile.save_path = ""
	Profile.reset()


func _attacks_of(enemy: Node) -> Array[MeleeAttack]:
	var attacks: Array[MeleeAttack] = []
	for node in enemy.find_children("*", "", true, false):
		if node is MeleeAttack:
			attacks.append(node)
	return attacks


func test_a_tier_scales_health_damage_and_rewards() -> void:
	var tier_one := Difficulty.new(1)
	var tier_three := Difficulty.new(3)
	check(Difficulty.new(0).tier == 1 and Difficulty.new(99).tier == Difficulty.MAX_TIER, "tiers stay within 1 to 10")
	check_near(tier_three.health_scale(), 1.35 * 1.35, 0.0001, "tier 3: +82% health")
	check_near(tier_three.damage_scale(), 1.13 * 1.13, 0.0001, "tier 3: +28% damage")
	check(tier_three.item_level(1) == 9, "tier 3: item level 9")
	for scene: PackedScene in [SkeletonScene, CultistScene, LordScene]:
		var plain: EnemyController = scene.instantiate()
		var scaled: EnemyController = scene.instantiate()
		tier_one.apply(plain)
		tier_three.apply(scaled)
		add_child(plain)
		add_child(scaled)
		check(scaled.health.max_health == roundi(plain.health.max_health * tier_three.health_scale()) and scaled.health.current == scaled.health.max_health,
				"%s: %d health at full" % [scaled.name, scaled.health.max_health])
		check(scaled.ash_value == plain.ash_value * 2 and scaled.xp_value == plain.xp_value * 2,
				"%s: double Ash and XP" % scaled.name)
		var attacks := _attacks_of(scaled)
		check(not attacks.is_empty(), "%s has attacks" % scaled.name)
		for attack in attacks:
			check(attack.roll_damage() == maxi(roundi(attack.data.damage * tier_three.damage_scale()), 1),
					"%s %s hits for %d" % [scaled.name, attack.name, attack.roll_damage()])
		for attack in _attacks_of(plain):
			check(attack.roll_damage() == attack.data.damage, "tier 1 leaves %s as built" % attack.name)
		plain.free()
		scaled.free()


func test_scaled_bolts_carry_the_tier_damage() -> void:
	var cultist: EnemyController = CultistScene.instantiate()
	Difficulty.new(5).apply(cultist)
	add_child(cultist)
	var bolt: RangedAttack = _attacks_of(cultist).filter(func(a: MeleeAttack) -> bool: return a is RangedAttack)[0]
	bolt.try_start(Vector3.FORWARD)
	var projectile: Projectile
	for i in 200:
		await wait_physics_frames(1)
		for child in get_children():
			if child is Projectile:
				projectile = child
		if projectile:
			break
	check(projectile != null and projectile.damage == roundi(bolt.data.damage * 1.6),
			"a tier 5 bolt deals +60%%: %s" % (projectile.damage if projectile else -1))
	cultist.free()
	if projectile:
		projectile.free()


func test_clearing_a_tier_opens_the_next_once_and_choices_stay_in_range() -> void:
	check(Profile.tier == 1 and Profile.tier_unlocked == 1, "a new profile starts at tier 1")
	check(Profile.select_tier(3) == 1, "a closed tier cannot be chosen")
	check(Profile.complete_tier(1) and Profile.tier_unlocked == 2, "clearing tier 1 opens tier 2")
	check(not Profile.complete_tier(1), "clearing it again opens nothing more")
	check(Profile.select_tier(2) == 2, "tier 2 can be chosen now")
	check(Profile.select_tier(0) == 1, "never below tier 1")
	for t in range(2, Difficulty.MAX_TIER + 3):
		Profile.complete_tier(t)
	check(Profile.tier_unlocked == Difficulty.MAX_TIER, "never above the last tier")


func test_tiers_survive_a_save_and_older_saves_start_at_tier_1() -> void:
	Profile.save_path = SAVE
	Profile.complete_tier(1)
	Profile.complete_tier(2)
	Profile.select_tier(2)
	Profile.save_profile()
	Profile.reset()
	check(Profile.load_profile() == OK and Profile.tier_unlocked == 3 and Profile.tier == 2, "the open tiers and the choice come back")
	var old := FileAccess.open(SAVE, FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 2, "ash": 3, "claimed": [], "inventory": [], "equipment": {}, "level": 4}))
	old.close()
	check(Profile.load_profile() == OK and Profile.tier_unlocked == 1 and Profile.tier == 1 and Profile.level == 4,
			"a version 2 save loads at tier 1")
	var odd := FileAccess.open(SAVE, FileAccess.WRITE)
	odd.store_string(JSON.stringify({"version": 3, "ash": 0, "claimed": [], "inventory": [], "equipment": {},
			"tier_unlocked": 2, "tier": 7}))
	odd.close()
	check(Profile.load_profile() == OK and Profile.tier == 2, "a saved choice above the open tiers is pulled back")


func test_a_tier_3_run_pays_double_opens_tier_4_and_offers_it() -> void:
	Profile.complete_tier(2)
	Profile.select_tier(3)
	var main := instantiate_main(false, CryptScene)
	add_child(main)
	var run: RunController = main.get_node("Run")
	var player: PlayerController = main.get_node("Player")
	var loot: LootDropper = main.get_node("Loot")
	player.health.invulnerable = true
	check(main.difficulty.tier == 3 and loot.item_level == main.level.item_level + 8, "the run is tier 3, loot 8 item levels up: %d" % loot.item_level)
	check(loot.chance_scale > 1.0 and loot.rarity_scale > 1.0, "and better drops")
	for room: Array in [["Ossuary", -20.0], ["Chapel", -50.0], ["Throne", -85.0]]:
		player.global_position = Vector3(0, 0, room[1])
		player.reset_physics_interpolation()
		var encounter: EncounterController = main.level.get_node("Encounters/" + room[0])
		check(await wait_until(func() -> bool:
			for enemy in encounter.living_enemies():
				var health := Health.of(enemy)
				health.invulnerable = false
				health.apply_damage(health.max_health)
			return encounter.phase == EncounterController.Phase.CLEARED, 900), "%s cleared" % room[0])
		await wait_physics_frames(2)
	check(run.result == RunController.Result.VICTORY, "the run is won")
	check(run.ash == CRYPT_ASH * 2, "tier 3 pays double Ash: %d" % run.ash)
	check(Profile.tier_unlocked == 4, "tier 4 opens")
	var screen: DeathScreen = main.get_node("DeathScreen")
	var descend: Button = screen.get_node("%RestartButton")
	var replay: Button = screen.get_node("%AlternateButton")
	check(descend.text == "Descend to tier 4" and replay.visible and replay.text == "Replay tier 3",
			"the end screen offers both: %s / %s" % [descend.text, replay.text])
	check(main.summary_text().begins_with("Tier 3"), "the summary names the tier")
	check(main.tier_after(true) == 4 and main.tier_after(false) == 3, "descend leads to 4, replay to 3")


func test_a_fall_offers_a_lower_tier() -> void:
	Profile.complete_tier(1)
	Profile.select_tier(2)
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var player: PlayerController = main.get_node("Player")
	player.health.apply_damage(player.health.max_health)
	var screen: DeathScreen = main.get_node("DeathScreen")
	var lower: Button = screen.get_node("%AlternateButton")
	check(lower.visible and lower.text == "Lower to tier 1", "a lower tier is offered: %s" % lower.text)
	check(main.tier_after(true) == 2 and main.tier_after(false) == 1, "retry stays at 2, lower goes to 1")
	check(Profile.tier_unlocked == 2, "a fall opens nothing")
