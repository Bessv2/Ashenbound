extends "res://tests/framework/test_case.gd"
## Tests for generated dungeons (docs/dungeons/generation.md) and the steeper
## tiers (docs/dungeons/tiers.md).

const CryptScene := preload("res://scenes/dungeon/crypt.tscn")

var main: Node3D
var player: PlayerController


func _exit_tree() -> void:
	Profile.reset()


## The authored level of `dungeon`, laid out anew with `layout_seed`.
func _generated(dungeon: String, layout_seed: int, tier: int = 1) -> Array:
	var level := (load(Dungeons.scene_path(dungeon)) as PackedScene).instantiate() as Level
	var generator := DungeonGenerator.new(dungeon, Difficulty.new(tier), layout_seed)
	generator.generate(level)
	return [level, generator]


## Where every piece of a generator's layout lies: [name, centre, size].
func _layout(generator: DungeonGenerator) -> Array:
	var pieces := []
	for piece in generator.chain + generator.vaults + generator.corridors:
		pieces.append([piece.name, piece.centre, piece.size])
	return pieces


func _rooms_of(level: Level) -> Array[CryptRoom]:
	var rooms: Array[CryptRoom] = []
	for node in level.get_node("Navigation/Rooms").get_children():
		rooms.append(node)
	return rooms


func _teleport(to: Vector3) -> void:
	player.global_position = to
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _clear(encounter: EncounterController) -> bool:
	return await wait_until(func() -> bool:
		for enemy in encounter.living_enemies():
			var health := Health.of(enemy)
			health.invulnerable = false
			health.apply_damage(health.max_health)
		return encounter.phase == EncounterController.Phase.CLEARED, 900)


## Main playing `dungeon` generated with `layout_seed`.
func _add_main(layout_seed: int, dungeon: String = Dungeons.CRYPT) -> void:
	main = instantiate_main(false, load(Dungeons.scene_path(dungeon)))
	main.random_layout = true
	main.layout_seed = layout_seed
	add_child(main)
	player = main.get_node("Player")


func test_the_same_seed_builds_the_same_dungeon_and_seeds_differ() -> void:
	for dungeon in Dungeons.ORDER:
		var first: Array = _generated(dungeon, 7)
		var again: Array = _generated(dungeon, 7)
		check(_layout(first[1]) == _layout(again[1]), "%s: seed 7 builds the same layout twice" % dungeon)
		var layouts := {}
		for layout_seed in 6:
			var built: Array = _generated(dungeon, layout_seed + 1)
			layouts[str(_layout(built[1]))] = true
			built[0].free()
		check(layouts.size() >= 5, "%s: six seeds give %d different layouts" % [dungeon, layouts.size()])
		first[0].free()
		again[0].free()


func test_every_dungeon_keeps_its_story_fights_in_order_and_ends_at_its_boss() -> void:
	for dungeon in Dungeons.ORDER:
		var authored := (load(Dungeons.scene_path(dungeon)) as PackedScene).instantiate() as Level
		var boss_data: EncounterData = authored.encounters[authored.encounters.size() - 1].data
		authored.free()
		for layout_seed in [1, 2, 3]:
			var built: Array = _generated(dungeon, layout_seed, 5)
			var level: Level = built[0]
			var titles := []
			for encounter in level.encounters:
				if encounter.title != "":
					titles.append(encounter.title)
			var objectives: Array = Quests.STORY[dungeon].objectives
			check(titles == objectives, "%s/%d: the story fights in order: %s" % [dungeon, layout_seed, titles])
			check(level.encounters[level.encounters.size() - 1].data == boss_data, "%s/%d: the boss fight comes last" % [dungeon, layout_seed])
			check(level.encounters.size() >= objectives.size(), "%s/%d: %d fights" % [dungeon, layout_seed, level.encounters.size()])
			for encounter in level.encounters + level.optional_encounters:
				for wave in encounter.data.waves:
					check(not wave.enemies.is_empty(), "%s/%d: %s has no empty wave" % [dungeon, layout_seed, encounter.name])
					for marker in wave.markers:
						check(encounter.has_node(NodePath(marker)), "%s/%d: %s has marker %s" % [dungeon, layout_seed, encounter.name, marker])
			var rooms := _rooms_of(level)
			for i in rooms.size():
				for j in range(i + 1, rooms.size()):
					var a := Rect2(Vector2(rooms[i].position.x, rooms[i].position.z) - Vector2(rooms[i].size) * 0.5, Vector2(rooms[i].size)).grow(-0.1)
					var b := Rect2(Vector2(rooms[j].position.x, rooms[j].position.z) - Vector2(rooms[j].size) * 0.5, Vector2(rooms[j].size)).grow(-0.1)
					check(not a.intersects(b), "%s/%d: %s and %s do not overlap" % [dungeon, layout_seed, rooms[i].name, rooms[j].name])
			level.free()


func test_layouts_turn_and_grow_side_vaults() -> void:
	var turned := 0
	var with_vaults := 0
	for layout_seed in 12:
		var built: Array = _generated(Dungeons.CRYPT, layout_seed + 1)
		var generator: DungeonGenerator = built[1]
		if generator.chain.any(func(piece) -> bool: return absf(piece.centre.x) > 1.0):
			turned += 1
		if not generator.vaults.is_empty():
			with_vaults += 1
		check(generator.chain[generator.chain.size() - 1].kind == "boss", "the chain ends at the boss hall")
		built[0].free()
	check(turned >= 8, "most layouts turn east or west: %d of 12" % turned)
	check(with_vaults >= 8, "most layouts have a vault: %d of 12" % with_vaults)


func test_higher_tiers_send_more_enemies() -> void:
	var counts := []
	for tier in [1, 10]:
		var built: Array = _generated(Dungeons.CRYPT, 4, tier)
		var level: Level = built[0]
		var biggest := 0
		for encounter in level.encounters.slice(0, level.encounters.size() - 1):
			for wave in encounter.data.waves:
				biggest = maxi(biggest, wave.enemies.size())
		counts.append(biggest)
		level.free()
	check(counts[1] >= counts[0] + 3, "tier 10 waves are larger: %s" % [counts])


func test_a_generated_crypt_is_connected_behind_its_gates() -> void:
	_add_main(3)
	var level: Level = main.level
	var region: NavigationRegion3D = level.get_node("Navigation")
	check(await wait_for_navigation(region), "the generated crypt bakes its navigation mesh")
	var start := level.player_start.global_position
	var boss := level.encounters[level.encounters.size() - 1].global_position
	var map := region.get_navigation_map()
	var end_of := func() -> Vector3:
		var path := NavigationServer3D.map_get_path(map, start, boss, true)
		return Vector3(path[path.size() - 1].x, 0.0, path[path.size() - 1].z) if not path.is_empty() else start
	check(end_of.call().distance_to(boss) > 10.0, "closed gates cut the path to the boss")
	for gate in level.get_node("Navigation/Gates").get_children():
		(gate as CryptGate).open = true
	check(await wait_until(func() -> bool: return end_of.call().distance_to(boss) < 0.6, 180),
			"with every gate open, a path runs from the start to the boss")


func test_a_run_through_a_generated_dungeon_wins_at_the_boss_and_vaults_are_optional() -> void:
	_add_main(5, Dungeons.VOLCANO)
	var level: Level = main.level
	var run: RunController = main.get_node("Run")
	check(not level.optional_encounters.is_empty(), "this layout has a vault")
	await wait_physics_frames(5)
	for encounter in level.encounters:
		check(not run.is_over(), "the run goes on before %s" % encounter.name)
		_teleport(encounter.global_position)
		check(await wait_until(func() -> bool: return encounter.phase == EncounterController.Phase.ACTIVE, 20),
				"%s starts when the hero walks in" % encounter.name)
		check(await _clear(encounter), "%s is cleared" % encounter.name)
		await wait_physics_frames(2)
	check(run.result == RunController.Result.VICTORY, "the boss's fall wins the run, vaults or not")


func test_a_cleared_vault_lays_out_a_rare_hoard() -> void:
	_add_main(5)
	var level: Level = main.level
	var loot: LootDropper = main.get_node("Loot")
	var run: RunController = main.get_node("Run")
	check(not level.optional_encounters.is_empty(), "this layout has a vault")
	var vault := level.optional_encounters[0]
	await wait_physics_frames(5)
	_teleport(vault.global_position)
	check(await wait_until(func() -> bool: return vault.phase == EncounterController.Phase.ACTIVE, 20),
			"walking into the vault wakes its guardians")
	var kills_before := run.kills
	var lying_before := loot.lying().size()
	check(await _clear(vault), "the vault is cleared")
	await wait_physics_frames(2)
	check(run.kills > kills_before, "the vault's kills count: %d" % run.kills)
	var hoard := loot.lying().slice(lying_before).filter(func(p: LootPickup) -> bool:
		return p.global_position.distance_to(vault.global_position) < 2.0)
	check(hoard.size() == 3, "a hoard of three lies where the guardians stood: %d" % hoard.size())
	check(hoard.all(func(p: LootPickup) -> bool: return p.item.rarity >= Rarity.Tier.RARE), "every hoard item is Rare or better")
	check(not run.is_over(), "a vault does not end the run")


func test_tiers_grow_steeply_and_raise_the_lowest_rarity() -> void:
	var ten := Difficulty.new(10)
	check_near(ten.health_scale(), pow(1.35, 9), 0.0001, "tier 10: about ×15 health")
	check_near(ten.damage_scale(), pow(1.13, 9), 0.0001, "tier 10: about ×3 damage")
	check_near(Difficulty.new(1).health_scale(2), 1.16, 0.0001, "two rooms deep: +16% health")
	check(Difficulty.new(1).extra_enemies() == 0 and Difficulty.new(3).extra_enemies() == 1 and ten.extra_enemies() == 4,
			"one more enemy a wave every two tiers")
	var floors := []
	for tier in [1, 2, 3, 5, 6, 8, 9, 10]:
		floors.append(Difficulty.new(tier).min_rarity())
	check(floors == [0, 0, 1, 1, 2, 2, 3, 3], "lowest rarity by tier: %s" % [floors])
	check(Difficulty.new(4).champion_affix_count() == 2 and Difficulty.new(7).champion_affix_count() == 3,
			"two affixes from tier 4, three from tier 7")
	var table := DropTable.new()
	table.chance = 1.0
	table.rolls = 60
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var items := table.roll(ItemCatalog.load_default(), 30, rng, 1.0, ten.rarity_scale(), ten.min_rarity())
	check(items.size() == 60 and items.all(func(item: ItemInstance) -> bool: return item.rarity >= Rarity.Tier.EPIC),
			"tier 10 drops are Epic or better")
	check(items.any(func(item: ItemInstance) -> bool: return item.rarity >= Rarity.Tier.LEGENDARY),
			"and some are Legendary or Mythic")
	var skeleton: EnemyController = load("res://scenes/enemies/skeleton_warrior.tscn").instantiate()
	var speed := skeleton.speed_multiplier
	ten.apply(skeleton, 1)
	check_near(skeleton.speed_multiplier, speed * 1.27, 0.0001, "tier 10 enemies move 27% faster")
	skeleton.free()
