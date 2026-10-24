extends "res://tests/framework/test_case.gd"
## Tests for champions (docs/CHAMPIONS.md): their scaling, each affix, their
## bonus drop, and how encounters raise them.

const WardenScene := preload("res://scenes/player/warden.tscn")
const SkeletonScene := preload("res://scenes/enemies/skeleton_warrior.tscn")
const CultistScene := preload("res://scenes/enemies/dark_cultist.tscn")
const KnightScene := preload("res://scenes/enemies/fallen_knight.tscn")
const CryptScene := preload("res://scenes/dungeon/crypt.tscn")

var hero: PlayerController


func _ready() -> void:
	add_level(60.0)
	hero = WardenScene.instantiate()
	add_child(hero)
	# Gear from an earlier test must not soften the numbers checked here.
	hero.health.armor = 0


func _exit_tree() -> void:
	Profile.save_path = ""
	Profile.reset()


## A Skeleton Warrior at `at`, made a champion with `affixes`, its AI off so
## only the champion's own effects act.
func _champion(affixes: Array[Champion.Affix], at: Vector3, scene: PackedScene = SkeletonScene) -> EnemyController:
	var enemy: EnemyController = scene.instantiate()
	enemy.position = at
	Champion.promote(enemy, affixes)
	add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func test_a_champion_is_tougher_worth_more_and_named() -> void:
	var plain: EnemyController = SkeletonScene.instantiate()
	add_child(plain)
	var enemy := _champion([Champion.Affix.HASTED], Vector3(0, 0, -8))
	var champion := Champion.of(enemy)
	check(champion != null and Champion.of(plain) == null, "only the promoted one is a champion")
	check(enemy.health.max_health == roundi(plain.health.max_health * Champion.HEALTH_SCALE) \
			and enemy.health.current == enemy.health.max_health, "2.5× health, full: %d" % enemy.health.max_health)
	check(enemy.xp_value == plain.xp_value * 4 and enemy.gold_value == plain.gold_value * 4 \
			and enemy.ash_value == plain.ash_value * 3, "4× XP and gold, 3× Ash")
	check_near(enemy.attack.damage_scale, Champion.DAMAGE_SCALE, 0.001, "hits 20% harder")
	check(champion.title == "Hasted Skeleton Warrior", "named after its affixes: %s" % champion.title)
	var bar := enemy.get_node("ChampionBar") as EliteBar
	check(bar.title == "HASTED SKELETON WARRIOR" and bar.health == enemy.health, "its name and bar over its head")
	check(enemy.has_node("Ring") and enemy.has_node("ChampionLight"), "a ring and a glow mark it")
	enemy.health.apply_damage(enemy.health.max_health)
	await wait_physics_frames(2)
	check(not enemy.has_node("Ring") and not enemy.has_node("ChampionLight"), "and go when it dies")


func test_hasted_moves_and_attacks_faster() -> void:
	var enemy := _champion([Champion.Affix.HASTED], Vector3(0, 0, -8))
	check_near(enemy.speed_multiplier, Champion.HASTE_SPEED, 0.001, "faster on its feet")
	check_near(enemy.attack.windup_scale, Champion.HASTE_ATTACK, 0.001, "a shorter windup")
	check_near(enemy.attack.recovery_scale, Champion.HASTE_ATTACK, 0.001, "and recovery")


func test_stoneskin_takes_less_damage() -> void:
	var enemy := _champion([Champion.Affix.STONESKIN], Vector3(0, 0, -8))
	check(enemy.health.apply_damage(20) == 12, "a 20 hit deals 12")


func test_vampiric_heals_from_its_hits_and_only_melee_enemies_get_it() -> void:
	var enemy := _champion([Champion.Affix.VAMPIRIC], Vector3(0, 0, -1.2))
	enemy.health.apply_damage(40)
	var hurt := enemy.health.current
	var targets: Array[Health] = [hero.health]
	enemy.attack.struck.emit(targets)
	check(enemy.health.current == hurt + roundi(enemy.health.max_health * Champion.VAMPIRIC_HEAL),
			"a hit landed heals 10%%: %d → %d" % [hurt, enemy.health.current])
	var missed: Array[Health] = []
	enemy.attack.struck.emit(missed)
	check(enemy.health.current == hurt + roundi(enemy.health.max_health * Champion.VAMPIRIC_HEAL), "a miss heals nothing")
	var cultist: EnemyController = CultistScene.instantiate()
	add_child(cultist)
	var rng := RandomNumberGenerator.new()
	for attempt in 40:
		check(not Champion.roll(cultist, 5, rng).has(Champion.Affix.VAMPIRIC), "a ranged enemy is never Vampiric")
	var all := Champion.roll(enemy, 5, rng)
	check(all.size() == 5 and all.has(Champion.Affix.VAMPIRIC), "a melee one may be: %s" % [all])
	check(Champion.roll(enemy, 2, rng).size() == 2, "as many affixes as asked, all different")


func test_ember_wreathed_burns_the_hero_close_by_once_a_second() -> void:
	var enemy := _champion([Champion.Affix.EMBER_WREATHED], Vector3(0, 0, -2.0))
	var champion := Champion.of(enemy)
	check(enemy.has_node("EmberAura"), "the aura's edge is drawn")
	var hits: Array[int] = []
	hero.health.damaged.connect(func(amount: int, _left: int) -> void: hits.append(amount))
	await wait_physics_frames(roundi(2.5 * Engine.physics_ticks_per_second))
	check(hits.size() == 2 and hits[0] == champion.ember_damage() and champion.ember_damage() == 5,
			"two ticks of 5 in 2.5 s: %s" % [hits])
	hero.global_position = Vector3(0, 0, 4)
	await wait_physics_frames(roundi(1.5 * Engine.physics_ticks_per_second))
	check(hits.size() == 2, "nothing from out of its reach: %s" % [hits])


func test_vengeful_erupts_where_it_fell_after_a_warning() -> void:
	var enemy := _champion([Champion.Affix.VENGEFUL], Vector3(0, 0, -2.0))
	var before := hero.health.current
	enemy.health.apply_damage(enemy.health.max_health)
	var blast := find_children("VengefulBlast", "VengefulBlast", false, false)
	check(blast.size() == 1, "an eruption starts where it fell")
	await wait_physics_frames(roundi((VengefulBlast.DELAY - 0.2) * Engine.physics_ticks_per_second))
	check(hero.health.current == before, "nothing during the warning")
	await wait_physics_frames(roundi(0.4 * Engine.physics_ticks_per_second))
	check(hero.health.current == before - 19, "then 16 × 1.2 = 19: %d" % (before - hero.health.current))
	await wait_physics_frames(30)
	check(hero.health.current == before - 19 and find_children("VengefulBlast", "VengefulBlast", false, false).is_empty(),
			"once, and it is gone")


func test_stepping_out_of_a_vengeful_eruption_avoids_it() -> void:
	var enemy := _champion([Champion.Affix.VENGEFUL], Vector3(0, 0, -2.0))
	var before := hero.health.current
	enemy.health.apply_damage(enemy.health.max_health)
	await wait_physics_frames(20)
	hero.global_position = Vector3(0, 0, 3.5)
	await wait_physics_frames(roundi((VengefulBlast.DELAY + 0.3) * Engine.physics_ticks_per_second))
	check(hero.health.current == before, "outside the ring, unhurt")


func test_a_champion_always_drops_a_rare_or_better() -> void:
	var dropper := LootDropper.new()
	dropper.inventory = Inventory.new()
	add_child(dropper)
	for attempt in 10:
		var enemy := _champion([Champion.Affix.STONESKIN], Vector3(2.0 * attempt - 10.0, 0, -10))
		var lying_before := dropper.lying().size()
		dropper.on_enemy_killed(enemy)
		var dropped := dropper.lying().slice(lying_before)
		check(dropped.any(func(p: LootPickup) -> bool: return p.item.rarity >= Rarity.Tier.RARE),
				"kill %d dropped a Rare or better" % attempt)


func test_encounters_raise_champions_by_the_tiers_chance() -> void:
	var difficulty := Difficulty.new(4)
	check(Difficulty.new(1).champion_affix_count() == 1 and difficulty.champion_affix_count() == 2 \
			and Difficulty.new(7).champion_affix_count() == 3, "one affix, two from tier 4, three from tier 7")
	check_near(Difficulty.new(1).champion_chance(), 0.1, 0.001, "10% at tier 1")
	check_near(Difficulty.new(10).champion_chance(), Difficulty.CHAMPION_CHANCE_MAX, 0.001, "capped")
	difficulty.champion_chance_override = 1.0
	var data := EncounterData.new()
	var wave := WaveData.new()
	wave.enemies = [SkeletonScene, KnightScene]
	wave.markers = ["A", "B"]
	data.waves = [wave]
	var encounter := EncounterController.new()
	encounter.data = data
	encounter.difficulty = difficulty
	for marker_name: String in ["A", "B"]:
		var marker := Marker3D.new()
		marker.name = marker_name
		marker.position = Vector3(-3.0 if marker_name == "A" else 3.0, 0, -12)
		encounter.add_child(marker)
	add_child(encounter)
	var risen: Array[String] = []
	encounter.champion_spawned.connect(func(enemy: EnemyController) -> void: risen.append(Champion.of(enemy).title))
	encounter.start()
	var living := encounter.living_enemies()
	var skeleton := living[0] as EnemyController
	var knight := living[1] as EnemyController
	check(Champion.of(skeleton) != null and Champion.of(skeleton).affixes.size() == 2, "the skeleton rose a champion with two affixes")
	check(Champion.of(knight) == null, "the Fallen Knight never does")
	check(risen.size() == 1, "one champion announced: %s" % [risen])
	check(skeleton.health.max_health == roundi(roundi(30 * difficulty.health_scale()) * Champion.HEALTH_SCALE),
			"the champion's health multiplies the tier's: %d" % skeleton.health.max_health)


func test_without_a_difficulty_no_champions_rise() -> void:
	var data := EncounterData.new()
	var wave := WaveData.new()
	for i in 20:
		wave.enemies.append(SkeletonScene)
		wave.markers.append("A")
	data.waves = [wave]
	var encounter := EncounterController.new()
	encounter.data = data
	var marker := Marker3D.new()
	marker.name = "A"
	marker.position = Vector3(0, 0, -12)
	encounter.add_child(marker)
	add_child(encounter)
	encounter.start()
	check(encounter.living_enemies().all(func(e: Node3D) -> bool: return Champion.of(e) == null), "all ordinary")


func test_a_champion_in_the_crypt_is_announced() -> void:
	var main := instantiate_main(false, CryptScene)
	main.champions_appear = true
	add_child(main)
	await wait_physics_frames(2)
	main.difficulty.champion_chance_override = 1.0
	var hud: Hud = main.get_node("HUD")
	(main.level.get_node("Encounters/Ossuary") as EncounterController).start()
	check(hud.toasts().any(func(l: Label) -> bool: return l.text.begins_with("A champion rises: ")),
			"a toast names it: %s" % [hud.toasts().map(func(l: Label) -> String: return l.text)])
