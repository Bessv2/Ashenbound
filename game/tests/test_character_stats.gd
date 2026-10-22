extends "res://tests/framework/test_case.gd"
## Tests that every item stat changes the matching combat number, and that
## taking the item off restores it (docs/LOOT.md, acceptance checks 3 and 4).

const WardenScene := preload("res://scenes/player/warden.tscn")
const DummyScene := preload("res://scenes/enemies/training_dummy.tscn")

var warden: PlayerController
var stats: CharacterStats
var equipment: Equipment
var catalog: ItemCatalog


func _ready() -> void:
	add_level(40.0)
	warden = WardenScene.instantiate()
	add_child(warden)
	stats = warden.get_node("Stats")
	equipment = Equipment.new()
	stats.track(equipment)
	catalog = ItemCatalog.load_default()


## An item of the first base for `slot`, carrying exactly `values`.
func _item(slot: ItemBase.Slot, values: Dictionary) -> ItemInstance:
	var item := ItemInstance.new()
	item.uid = "test-%d-%d" % [slot, randi()]
	for base in catalog.bases:
		if base.slot == slot:
			item.base_id = base.id
			break
	for stat in values:
		item.base_stats[stat] = values[stat]
	return item


func _dummy_ahead() -> Health:
	var dummy: Node3D = DummyScene.instantiate()
	dummy.position = Vector3(0, 0, -1.2)
	add_child(dummy)
	return Health.of(dummy)


## Damage the basic attack deals to a fresh dummy in front.
func _basic_hit() -> int:
	var target := _dummy_ahead()
	await wait_physics_frames(2)
	var before := target.current
	warden.attack.try_start(Vector3.FORWARD)
	await wait_until(func() -> bool: return target.current < before, 40)
	var dealt := before - target.current
	await wait_until(func() -> bool: return not warden.attack.is_busy(), 120)
	target.get_parent().queue_free()
	return dealt


func test_weapon_damage_and_damage_percent_scale_attacks() -> void:
	check(await _basic_hit() == 10, "bare hands: 10")
	equipment.equip(_item(ItemBase.Slot.WEAPON, {ItemStats.WEAPON_DAMAGE: 20}), catalog)
	check(await _basic_hit() == 20, "a 20-damage weapon doubles it")
	equipment.equip(_item(ItemBase.Slot.AMULET, {ItemStats.DAMAGE_PCT: 50}), catalog)
	check(await _basic_hit() == 30, "+50% damage on top: 30")
	equipment.unequip(Equipment.Slot.WEAPON)
	equipment.unequip(Equipment.Slot.AMULET)
	check(await _basic_hit() == 10, "taking them off restores 10")


func test_critical_hits_use_critical_damage() -> void:
	equipment.equip(_item(ItemBase.Slot.RING, {ItemStats.CRIT_CHANCE: 100}), catalog)
	check(await _basic_hit() == 15, "every hit crits for +50%")
	equipment.equip(_item(ItemBase.Slot.RING, {ItemStats.CRIT_DAMAGE: 50}), catalog)
	check(await _basic_hit() == 20, "+50% critical damage: 20")


func test_attack_speed_shortens_the_basic_attack() -> void:
	var windup := warden.attack.windup_time()
	equipment.equip(_item(ItemBase.Slot.GLOVES, {ItemStats.ATTACK_SPEED_PCT: 100}), catalog)
	check_near(warden.attack.windup_time(), windup / 2.0, 0.0001, "twice as fast")
	equipment.unequip(Equipment.Slot.GLOVES)
	check_near(warden.attack.windup_time(), windup, 0.0001, "back to normal")


func test_max_health_and_armour() -> void:
	var health := warden.health
	equipment.equip(_item(ItemBase.Slot.CHEST, {ItemStats.MAX_HEALTH: 50, ItemStats.ARMOR: 100}), catalog)
	check(health.max_health == 150 and health.current == 150, "+50 max health, still full: %d/%d" % [health.current, health.max_health])
	check(health.apply_damage(12) == 6, "100 armour halves a 12-damage hit")
	equipment.unequip(Equipment.Slot.CHEST)
	check(health.max_health == 100 and health.current == 94, "back to 100, the 6 lost stays lost: %d" % health.current)
	check(health.apply_damage(12) == 12, "no armour, full damage")


func test_move_speed_and_cooldown_reduction_are_capped() -> void:
	equipment.equip(_item(ItemBase.Slot.BOOTS, {ItemStats.MOVE_SPEED_PCT: 50}), catalog)
	check_near(warden.speed_multiplier, 1.3, 0.0001, "move speed capped at +30%")
	equipment.equip(_item(ItemBase.Slot.RELIC, {ItemStats.COOLDOWN_REDUCTION: 60}), catalog)
	var cleave: Ability = warden.get_node("Cleave")
	check_near(cleave.cooldown_scale, 0.6, 0.0001, "cooldowns capped at 40% shorter")
	_dummy_ahead()
	await wait_physics_frames(2)
	check(cleave.try_activate(Vector3.FORWARD), "Cleave fires")
	check_near(cleave.cooldown_fraction(), 1.0, 0.01, "the bar starts full")
	await wait_physics_frames(roundi(4.0 * 0.6 * 60) + 2)
	check(cleave.cooldown_fraction() == 0.0, "and empties in 60% of 4 s")


func test_damage_percent_strengthens_brand() -> void:
	equipment.equip(_item(ItemBase.Slot.AMULET, {ItemStats.DAMAGE_PCT: 50}), catalog)
	var target := _dummy_ahead()
	await wait_physics_frames(2)
	var brand: Ability = warden.get_node("Brand")
	check(brand.try_activate(Vector3.FORWARD), "Brand takes")
	var before := target.current
	check(await wait_until(func() -> bool: return target.current < before, 60), "it burns")
	check(before - target.current == 6, "4 per tick +50%% = 6, got %d" % (before - target.current))


func test_profile_moves_items_between_bag_and_body_without_losing_any() -> void:
	Profile.reset()
	var sword := _item(ItemBase.Slot.WEAPON, {ItemStats.WEAPON_DAMAGE: 12})
	var axe := _item(ItemBase.Slot.WEAPON, {ItemStats.WEAPON_DAMAGE: 14})
	check(Profile.inventory.add(sword) and Profile.inventory.add(axe), "two weapons in the bag")
	check(Profile.equip_from_bag(sword.uid), "equip the sword")
	check(Profile.equip_from_bag(axe.uid), "the axe replaces it")
	check(Profile.equipment.item_in(Equipment.Slot.WEAPON) == axe and Profile.inventory.has(sword.uid),
			"the sword went back in the bag")
	check(Profile.inventory.items.size() + Profile.equipment.all().size() == 2, "still two items")
	while not Profile.inventory.is_full():
		Profile.inventory.add(_item(ItemBase.Slot.RING, {ItemStats.CRIT_CHANCE: 1}))
	check(not Profile.unequip_to_bag(Equipment.Slot.WEAPON), "a full bag refuses the axe")
	check(Profile.equipment.item_in(Equipment.Slot.WEAPON) == axe, "and the axe stays on")
	check(not Profile.equip_from_bag("no-such-item"), "an unknown item is not equipped")
	Profile.reset()


func test_health_on_kill_heals_through_the_run() -> void:
	warden.free()
	var main := instantiate_main(true)
	add_child(main)
	var hero: PlayerController = main.get_node("Player")
	var hero_stats: CharacterStats = hero.get_node("Stats")
	var gear := Equipment.new()
	hero_stats.track(gear)
	gear.equip(_item(ItemBase.Slot.RING, {ItemStats.HEALTH_ON_KILL: 5}), catalog)
	hero.health.invulnerable = false
	hero.health.apply_damage(20)
	var encounter: EncounterController = main.get_node("Level/Enemies/Encounter")
	check(await wait_until(func() -> bool: return not encounter.living_enemies().is_empty(), 200), "enemies rise")
	var enemy := encounter.living_enemies()[0]
	var enemy_health := Health.of(enemy)
	await wait_until(func() -> bool: return not enemy_health.invulnerable, 120)
	enemy_health.apply_damage(1000)
	check(hero.health.current == 85, "a kill heals 5: %d" % hero.health.current)
