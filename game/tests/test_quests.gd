extends "res://tests/framework/test_case.gd"
## Story quests, achievements and daily challenges: docs/QUESTS.md.

const CryptScene := preload("res://scenes/dungeon/crypt.tscn")

var _real_clock: Callable
var _now := [1_000_000_000]


func _ready() -> void:
	_real_clock = Profile.clock
	Profile.clock = func() -> int: return _now[0]
	Profile.rng.seed = 4


func _exit_tree() -> void:
	Profile.clock = _real_clock


func test_every_quest_names_real_fights_and_has_texts() -> void:
	for id: String in Quests.STORY:
		var quest: Dictionary = Quests.STORY[id]
		check(Dungeons.INFO.has(id), "%s is a dungeon" % id)
		check(quest.objectives.size() == quest.texts.size(), "%s: a text per objective" % id)
		var level: Level = load(Dungeons.scene_path(id)).instantiate()
		var titles := level.encounters.map(func(e: EncounterController) -> String: return e.title)
		for objective: String in quest.objectives:
			check(titles.has(objective), "%s: \"%s\" is one of its fights: %s" % [id, objective, titles])
		level.free()


func test_a_story_quest_pays_once_when_every_objective_is_done() -> void:
	check(Profile.claim_quest("crypt") == "Not finished yet.", "nothing done yet")
	check(Profile.record_encounter("crypt", "The Ossuary") and not Profile.record_encounter("crypt", "The Ossuary"),
			"an objective counts once")
	check(not Profile.record_encounter("crypt", "Somewhere else"), "only the quest's own fights count")
	Profile.record_encounter("crypt", "The Ruined Chapel")
	check(not Profile.quest_complete("crypt"), "the boss is still to do")
	Profile.record_encounter("crypt", "The Ashen Throne")
	check(Profile.quest_complete("crypt") and Profile.claimable_count() >= 1, "complete, and waiting")
	check(Profile.claim_quest("crypt") == "", "claimed")
	check(Profile.gold == 300 and Profile.material("iron_ore") == 10, "its gold and ore paid: %d gold" % Profile.gold)
	check(Profile.inventory.items.size() == 1 and Profile.inventory.items[0].rarity >= Rarity.Tier.RARE,
			"and a Rare item or better")
	check(Profile.claim_quest("crypt") == "Already claimed." and Profile.gold == 300, "never twice")


func test_a_full_bag_holds_the_quest_reward_back() -> void:
	for title in Quests.STORY.crypt.objectives:
		Profile.record_encounter("crypt", title)
	var rng := RandomNumberGenerator.new()
	while not Profile.inventory.is_full():
		Profile.inventory.add(Profile.catalog.roll(Profile.catalog.bases[0], 1, 0, rng))
	check(Profile.claim_quest("crypt") == "Make room in the bag first." and Profile.gold == 0, "nothing paid into a full bag")


func test_achievements_pay_once_at_their_goal() -> void:
	Profile.count(Quests.KILLS, 49)
	check(Profile.achievement_progress("slayer_1") == Vector2i(49, 50), "49 of 50")
	check(Profile.claim_achievement("slayer_1") == "Not yet.", "not before the goal")
	Profile.count(Quests.KILLS)
	check(Profile.claim_achievement("slayer_1") == "" and Profile.gold == 100, "paid at 50")
	check(Profile.claim_achievement("slayer_1") == "Already claimed." and Profile.gold == 100, "once")


func test_dailies_change_each_day_count_from_its_start_and_forgive_a_miss() -> void:
	Profile.count(Quests.KILLS, 500)
	var today := Profile.dailies()
	check(today.size() == Quests.DAILY_COUNT, "three challenges")
	check(today.all(func(c: Dictionary) -> bool: return c.progress == 0), "yesterday's work does not count today")
	var ids := today.map(func(c: Dictionary) -> String: return c.id)
	var first: Dictionary = today[0]
	var stat: String = Quests.daily(first.id)[2]
	Profile.count(stat, first.goal)
	check(Profile.claim_daily(first.id) == "" and Profile.claim_daily(first.id) == "Already claimed.", "claimed once")
	var different := false
	for day in range(1, 8):
		_now[0] += 86400
		var next := Profile.dailies().map(func(c: Dictionary) -> String: return c.id)
		different = different or next != ids
		check(Profile.dailies().all(func(c: Dictionary) -> bool: return not c.claimed and c.progress == 0),
				"day %d starts fresh, nothing owed from before" % day)
	check(different, "the challenges change from day to day")
	check(Quests.dailies_of(20000) == Quests.dailies_of(20000), "the same day always has the same three")


func test_crafting_and_camps_count_toward_goals() -> void:
	Profile.complete_tier(1)
	Profile.gold = 10000
	for id in Materials.ORDER:
		Profile.materials[id] = 100
	Profile.craft_item("iron_helm")
	_now[0] += 3600
	Profile.collect_camp(Camps.MINE)
	Profile.upgrade_camp(Camps.MINE)
	check(Profile.stat_count(Quests.CRAFTED) == 1 and Profile.stat_count(Quests.CAMP_COLLECTS) >= 1
			and Profile.stat_count(Quests.CAMP_UPGRADES) == 1, "counted: %s" % Profile.stats)


func test_a_run_records_kills_objectives_and_wins() -> void:
	var main := instantiate_main(false, CryptScene)
	add_child(main)
	await wait_physics_frames(2)
	var throne: EncounterController = main.level.encounters.filter(func(e: EncounterController) -> bool:
		return e.title == "The Ashen Throne")[0]
	throne.cleared.emit()
	check(Profile.objective_done("crypt", 2), "clearing the throne ticks off the Ashen Lord")
	check(main.get_node("HUD").toasts().any(func(l: Label) -> bool: return l.text.begins_with("Quest:")), "with a message")


func test_quest_progress_is_saved() -> void:
	Profile.record_encounter("catacombs", "The Bone Pit")
	Profile.count(Quests.BOSSES, 2)
	Profile.achievements_claimed.append("runs_1")
	var saved := Profile.to_dict()
	Profile.reset()
	check(Profile._apply(JSON.parse_string(JSON.stringify(saved))), "loads")
	check(Profile.objective_done("catacombs", 2) and Profile.stat_count(Quests.BOSSES) == 2
			and Profile.achievements_claimed.has("runs_1"), "objectives, counters and claims came back")


func test_the_quests_window_claims_from_the_title() -> void:
	for title in Quests.STORY.crypt.objectives:
		Profile.record_encounter("crypt", title)
	var title: TitleScreen = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	title.enter_requested.disconnect(title._go_to_crypt)
	var badge := title.find_child("QuestsButton", true, false).get_node("Badge") as Label
	check(badge.visible and badge.text == "1", "the Quests button shows a reward waiting")
	title.open_quests()
	var panel := title.quests_panel()
	check(panel.press_claim("story", "crypt") == "" and Profile.quests_claimed.has("crypt"), "claimed from the window")
	panel.show_page(QuestsPanel.Page.ACHIEVEMENTS)
	check(panel.find_child("slayer_1", true, false) != null, "the achievements are listed")
	panel.show_page(QuestsPanel.Page.DAILY)
	check(Profile.dailies().all(func(c: Dictionary) -> bool: return panel.find_child(c.id, true, false) != null), "today's challenges are listed")
	title.free()
