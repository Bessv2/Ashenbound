extends "res://tests/framework/test_case.gd"
## Tests for loot: rarity, rolls, drops from a dying Hollow, pickup into the
## player's Inventory, and the HUD's gold counter and item feed.

const PlayerScene := preload("res://scenes/player/player.tscn")
const HollowScene := preload("res://scenes/enemies/hollow.tscn")
const HollowLoot := preload("res://resources/loot/hollow_loot.tres")
const BoneAxe := preload("res://resources/items/bone_axe.tres")

var player: PlayerController
var inventory: Inventory


func _ready() -> void:
	add_level(40.0)
	player = PlayerScene.instantiate()
	player.position = Vector3(0, 0, 8)
	add_child(player)
	inventory = Inventory.of(player)


func _place_player(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _drops() -> Array[LootDrop]:
	var found: Array[LootDrop] = []
	for child in get_children():
		if child is LootDrop and not child.is_queued_for_deletion():
			found.append(child)
	return found


## A Hollow whose drops are fixed: `gold` gold and always one Bone Axe.
func _hollow_with_fixed_loot(at: Vector3, gold: int, rarity_weights: PackedFloat32Array) -> EnemyController:
	var table := LootTable.new()
	table.gold_min = gold
	table.gold_max = gold
	table.item_chance = 1.0
	table.rarity_weights = rarity_weights
	table.items = [BoneAxe]
	var hollow: EnemyController = HollowScene.instantiate()
	hollow.position = at
	(hollow.get_node("LootDropper") as LootDropper).loot_table = table
	add_child(hollow)
	return hollow


func test_rarity_colors_match_the_art_direction() -> void:
	var expected := ["#838488", "#529b4d", "#259fd2", "#7b4289", "#d9a44c"]
	var names := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
	for tier in Rarity.Tier.values():
		check(Rarity.color_of(tier).is_equal_approx(Color(expected[tier])), "%s color" % names[tier])
		check(Rarity.name_of(tier) == names[tier], "%s name" % names[tier])
		check(Rarity.text_color_of(tier).get_luminance() > Rarity.color_of(tier).get_luminance(),
				"%s text color is lighter for the dark HUD" % names[tier])


func test_rolls_follow_the_hollow_table() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	const ROLLS := 20000
	var tiers := [0, 0, 0, 0, 0]
	var golds := {}
	var item_drops := 0
	for i in ROLLS:
		tiers[HollowLoot.roll_rarity(rng)] += 1
		golds[HollowLoot.roll_gold(rng)] = true
		item_drops += HollowLoot.roll_items(rng).size()
	var total_weight := 0.0
	for weight in HollowLoot.rarity_weights:
		total_weight += weight
	for tier in tiers.size():
		check_near(float(tiers[tier]) / ROLLS, HollowLoot.rarity_weights[tier] / total_weight, 0.01,
				"share of %s" % Rarity.name_of(tier))
	check(golds.keys().all(func(g: int) -> bool: return g >= 3 and g <= 8) and golds.size() == 6,
			"gold is 3 to 8, every amount possible: %s" % [golds.keys()])
	check_near(float(item_drops) / ROLLS, HollowLoot.item_chance, 0.01, "item drop rate")


func test_a_dying_hollow_scatters_its_drops() -> void:
	var hollow := _hollow_with_fixed_loot(Vector3(0, 0, -4), 6, PackedFloat32Array([0, 0, 1, 0, 0]))
	await wait_physics_frames(2)
	var died_at := hollow.global_position
	hollow.health.apply_damage(hollow.health.max_health)
	await wait_process_frames(1)  # Drops spawn deferred.
	var drops := _drops()
	check(drops.size() == 2, "one gold drop and one item drop, got %d" % drops.size())
	await wait_physics_frames(ceili(LootDrop.POP_TIME * 60) + 1)
	for drop in drops:
		check(drop.is_landed(), "%s landed" % drop.name)
		var offset := drop.global_position - died_at
		check_near(Vector2(offset.x, offset.z).length(), LootDropper.SCATTER_RADIUS, 0.05, "%s lands in the ring" % drop.name)
		check_near(drop.global_position.y, died_at.y, 0.01, "%s lands on the floor" % drop.name)
	var gold_drop := drops.filter(func(d: LootDrop) -> bool: return d.item == null)
	var item_drop := drops.filter(func(d: LootDrop) -> bool: return d.item != null)
	check(gold_drop.size() == 1 and gold_drop[0].gold == 6, "the gold drop carries 6 gold")
	check(item_drop.size() == 1 and item_drop[0].item.data == BoneAxe and item_drop[0].item.rarity == Rarity.Tier.RARE,
			"the item drop is a rare Bone Axe")
	check(drops[0].global_position.distance_to(drops[1].global_position) > 1.0, "the two drops land apart")


func test_walking_over_drops_picks_them_up() -> void:
	var hollow := _hollow_with_fixed_loot(Vector3(0, 0, -4), 6, PackedFloat32Array([0, 0, 0, 1, 0]))
	await wait_physics_frames(2)
	hollow.health.apply_damage(hollow.health.max_health)
	await wait_process_frames(1)
	await wait_physics_frames(ceili(LootDrop.POP_TIME * 60) + 1)
	for drop in _drops():
		_place_player(drop.global_position)
		await wait_physics_frames(3)
	check(inventory.gold == 6, "picked up 6 gold, have %d" % inventory.gold)
	check(inventory.items.size() == 1 and inventory.items[0].rarity == Rarity.Tier.EPIC, "picked up the epic axe")
	await wait_process_frames(1)
	check(_drops().is_empty(), "picked-up drops are gone")


func test_a_drop_is_picked_up_only_after_it_lands() -> void:
	# The player already stands where it will land, so this also checks that
	# being inside the area from the start is enough.
	_place_player(Vector3(2, 0, 0))
	await wait_physics_frames(2)
	LootDrop.spawn_gold(self, Vector3(0, 0.8, 0), Vector3(2, 0, 0), 5)
	await wait_physics_frames(ceili(LootDrop.POP_TIME * 60) - 3)
	check(inventory.gold == 0, "not collected mid-air")
	await wait_physics_frames(5)
	check(inventory.gold == 5, "collected once landed")


func test_a_full_inventory_leaves_items_but_takes_gold() -> void:
	inventory.capacity = 1
	inventory.add_item(Item.new(BoneAxe, Rarity.Tier.COMMON))
	_place_player(Vector3(2, 0, 0))
	var item_drop := LootDrop.spawn_item(self, Vector3(2, 0, 0), Vector3(2, 0, 0), Item.new(BoneAxe, Rarity.Tier.RARE))
	LootDrop.spawn_gold(self, Vector3(2, 0, 0), Vector3(2, 0, 0), 4)
	await wait_physics_frames(40)
	check(inventory.gold == 4, "gold is always taken")
	check(is_instance_valid(item_drop) and inventory.items.size() == 1, "the item stays on the ground")
	inventory.items.clear()
	await wait_physics_frames(2)
	check(inventory.items.size() == 1 and inventory.items[0].rarity == Rarity.Tier.RARE,
			"picked up once there is room")


func test_unclaimed_drops_disappear() -> void:
	var drop := LootDrop.spawn_gold(self, Vector3(-5, 0, 0), Vector3(-5, 0, 0), 3)
	drop.lifetime = 0.5
	await wait_physics_frames(25)
	check(is_instance_valid(drop), "still there before its lifetime")
	await wait_physics_frames(10)
	check(not is_instance_valid(drop) or drop.is_queued_for_deletion(), "gone after its lifetime")


func test_pause_holds_drops() -> void:
	_place_player(Vector3(2, 0, 0))
	await wait_physics_frames(2)
	LootDrop.spawn_gold(self, Vector3(0, 0.8, 0), Vector3(2, 0, 0), 5)
	await wait_physics_frames(5)
	get_tree().paused = true
	await wait_physics_frames(40)
	check(inventory.gold == 0, "nothing is collected while paused")
	get_tree().paused = false
	await wait_physics_frames(30)
	check(inventory.gold == 5, "collected after resuming")


func test_inventory_counts_gold_and_items() -> void:
	var events := [0, 0]
	inventory.gold_changed.connect(func(_total: int) -> void: events[0] += 1)
	inventory.item_added.connect(func(_item: Item) -> void: events[1] += 1)
	inventory.add_gold(5)
	inventory.add_gold(0)
	inventory.add_gold(-3)
	check(inventory.gold == 5 and events[0] == 1, "only positive amounts count")
	inventory.capacity = 2
	check(inventory.add_item(Item.new(BoneAxe, Rarity.Tier.COMMON)), "first item fits")
	check(inventory.add_item(Item.new(BoneAxe, Rarity.Tier.COMMON)), "second item fits")
	check(not inventory.add_item(Item.new(BoneAxe, Rarity.Tier.COMMON)), "third item does not")
	check(inventory.is_full() and events[1] == 2, "full after two, two events")
	check(Item.new(BoneAxe, Rarity.Tier.LEGENDARY).describe() == "Bone Axe (Legendary)", "names spell out the tier")


func test_hud_shows_gold_and_picked_up_items() -> void:
	player.free()
	var main := instantiate_main()
	add_child(main)
	var hud := main.get_node("HUD")
	var carried := Inventory.of(main.get_node("Player"))
	var gold_label: Label = hud.get_node("%GoldLabel")
	var feed: VBoxContainer = hud.get_node("%LootFeed")
	check(gold_label.text == "0 gold", "starts at 0 gold")
	carried.add_gold(7)
	check(gold_label.text == "7 gold", "shows 7 gold, got '%s'" % gold_label.text)
	carried.add_item(Item.new(BoneAxe, Rarity.Tier.RARE))
	var entry: Label = feed.get_child(-1)
	check(entry.text == "Bone Axe (Rare)", "lists the item, got '%s'" % entry.text)
	check(entry.get_theme_color("font_color").is_equal_approx(Rarity.text_color_of(Rarity.Tier.RARE)),
			"in the rare color")
	for i in 6:
		carried.add_item(Item.new(BoneAxe, Rarity.Tier.COMMON))
	await wait_process_frames(1)
	check(feed.get_child_count() == Hud.FEED_MAX_ENTRIES, "keeps at most %d entries" % Hud.FEED_MAX_ENTRIES)


func test_spawner_hollows_drop_beside_themselves() -> void:
	player.free()
	var main := instantiate_main(true)
	add_child(main)
	var spawner: EnemySpawner = main.get_node("Enemies/HollowSpawner")
	await wait_physics_frames(2)
	var hollow: EnemyController
	for child in spawner.get_children():
		if child is EnemyController:
			hollow = child
			break
	var alive := spawner.alive_count()
	hollow.health.apply_damage(hollow.health.max_health)
	await wait_process_frames(1)
	var drops := spawner.get_children().filter(func(c: Node) -> bool: return c is LootDrop)
	check(not drops.is_empty(), "a Hollow always drops at least its gold")
	# The spawner counts the corpse until it is removed, and never the drops.
	await wait_physics_frames(int(hollow.behavior.corpse_time * 60) + 5)
	check(spawner.alive_count() == alive - 1, "one fewer Hollow once the corpse is gone")
	check(drops.all(func(d: LootDrop) -> bool: return is_instance_valid(d)), "its drops are still on the ground")
