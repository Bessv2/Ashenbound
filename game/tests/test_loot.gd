extends "res://tests/framework/test_case.gd"
## Tests for drops: drop tables, items on the floor, picking them up, and
## gathering what is left at victory (docs/LOOT.md, acceptance check 5).

const WardenScene := preload("res://scenes/player/warden.tscn")
const KnightScene := preload("res://scenes/enemies/fallen_knight.tscn")
const CryptScene := preload("res://scenes/dungeon/crypt.tscn")

var catalog: ItemCatalog


func _ready() -> void:
	catalog = ItemCatalog.load_default()


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	return rng


func test_drop_tables_follow_their_chance_rolls_and_minimum() -> void:
	var never := DropTable.new()
	never.chance = 0.0
	never.rolls = 5
	check(never.roll(catalog, 3, _rng()).is_empty(), "chance 0 drops nothing")
	var boss := DropTable.new()
	boss.chance = 1.0
	boss.rolls = 3
	boss.min_rarity = Rarity.Tier.RARE
	var rng := _rng()
	for attempt in 50:
		var items := boss.roll(catalog, 4, rng)
		check(items.size() == 3, "three items each time")
		for item in items:
			check(item.rarity >= Rarity.Tier.RARE and item.item_level == 4, "Rare or better, level 4")
	var some := DropTable.new()
	some.chance = 0.1
	var dropped := 0
	for attempt in 2000:
		dropped += some.roll(catalog, 1, rng).size()
	check_near(dropped / 2000.0, 0.1, 0.025, "a 10% table drops about one in ten")


func test_walking_over_an_item_picks_it_up_once_and_a_full_bag_leaves_it() -> void:
	add_level(30.0)
	var hero: PlayerController = WardenScene.instantiate()
	add_child(hero)
	var bag := Inventory.new()
	var dropper := LootDropper.new()
	dropper.inventory = bag
	add_child(dropper)
	var picked: Array[ItemInstance] = []
	dropper.collected.connect(func(item: ItemInstance) -> void: picked.append(item))
	var item := catalog.roll(catalog.bases[0], 1, Rarity.Tier.RARE, _rng())
	# Tracked by id: lambdas must not capture a node that gets freed.
	var pickup_id := dropper.drop(item, Vector3(0, 0, -4)).get_instance_id()
	await wait_physics_frames(5)
	check(is_instance_id_valid(pickup_id) and bag.items.is_empty(), "out of reach, it stays on the floor")
	hero.global_position = Vector3(0, 0, -3.5)
	check(await wait_until(func() -> bool: return not is_instance_id_valid(pickup_id), 10), "walking over it picks it up")
	check(bag.items.size() == 1 and picked == [item], "once, into the bag")
	bag.capacity = 1
	var second_id := dropper.drop(catalog.roll(catalog.bases[1], 1, Rarity.Tier.COMMON, _rng()), hero.global_position).get_instance_id()
	await wait_physics_frames(10)
	check(is_instance_id_valid(second_id) and bag.items.size() == 1, "a full bag leaves it on the floor")
	bag.capacity = 2
	check(await wait_until(func() -> bool: return not is_instance_id_valid(second_id), 10), "and it is taken once there is room")


func test_a_fallen_knight_drops_two_better_items_where_it_dies() -> void:
	var main := instantiate_main()
	add_child(main)
	var loot: LootDropper = main.get_node("Loot")
	var knight: EnemyController = KnightScene.instantiate()
	knight.position = Vector3(8, 0, 8)
	main.add_child(knight)
	await wait_physics_frames(2)
	loot.on_enemy_killed(knight)
	var lying := loot.lying()
	check(lying.size() == 2, "two items: %d" % lying.size())
	for pickup in lying:
		check(pickup.item.rarity >= Rarity.Tier.COMMON, "a real item")
		check(pickup.global_position.distance_to(Vector3(8, 0, 8)) < 1.5, "near the body")


func test_victory_gathers_the_lords_loot_into_the_bag() -> void:
	var main := instantiate_main(false, CryptScene)
	add_child(main)
	var player: PlayerController = main.get_node("Player")
	player.health.invulnerable = true
	await wait_physics_frames(5)
	for room: Array in [["Ossuary", -20.0], ["Chapel", -50.0], ["Throne", -85.0]]:
		player.global_position = Vector3(0, 0, room[1])
		var encounter: EncounterController = main.level.get_node("Encounters/" + room[0])
		check(await wait_until(func() -> bool:
			for enemy in encounter.living_enemies():
				var health := Health.of(enemy)
				health.invulnerable = false
				health.apply_damage(health.max_health)
			return encounter.phase == EncounterController.Phase.CLEARED, 900), "%s cleared" % room[0])
		await wait_physics_frames(2)
	var loot: LootDropper = main.get_node("Loot")
	check(loot.lying().is_empty(), "nothing left on the floor")
	var rares := Profile.inventory.items.filter(func(i: ItemInstance) -> bool: return i.rarity >= Rarity.Tier.RARE)
	check(rares.size() >= 3, "the Lord's three Rare+ items are in the bag: %d" % rares.size())
	check(Profile.inventory.items.size() >= 5, "plus the Knight's two: %d" % Profile.inventory.items.size())
	var details: Label = main.get_node("DeathScreen").get_node("%Details")
	check(details.text.contains("Items found %d" % Profile.inventory.items.size()), details.text)
