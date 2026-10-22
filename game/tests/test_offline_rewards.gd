extends "res://tests/framework/test_case.gd"
## Tests for offline rewards (docs/OFFLINE_REWARDS.md): banked time, the
## eight-hour cap, a clock that goes backwards, payment once, saving, and the
## "While you were away" screen.

const SAVE := "user://test_offline_profile.json"

var _real_clock: Callable
## The fake clock's time, in unix seconds.
var _now := [1_000_000]


func _ready() -> void:
	_real_clock = Profile.clock
	Profile.clock = func() -> int: return _now[0]


func _exit_tree() -> void:
	Profile.clock = _real_clock
	for path in [SAVE, "user://test_offline_profile.backup.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	Profile.save_path = ""
	Profile.reset()


## A profile that cleared tier `cleared` and was last seen now.
func _cleared(cleared: int) -> void:
	for t in range(1, cleared + 1):
		Profile.complete_tier(t)
	Profile.last_seen = _now[0]


func test_rewards_follow_time_and_tier_up_to_the_cap() -> void:
	check(OfflineRewards.earned(OfflineRewards.MIN_SECONDS - 1, 1).xp == 0, "a short absence earns nothing")
	check(OfflineRewards.earned(7200, 0).gold == 0, "nothing without a cleared tier")
	check(OfflineRewards.earned(7200, 1) == {"xp": 790, "gold": 170, "ash": 76}, "two hours at tier 1: one run's worth")
	check(OfflineRewards.earned(20 * 3600, 1) == OfflineRewards.earned(8 * 3600, 1), "capped at eight hours")
	check(OfflineRewards.earned(8 * 3600, 1).ash == 76 * 4, "eight hours: four runs")
	check(OfflineRewards.earned(7200, 3).xp == 790 * 2, "tier 3 doubles it")
	check(OfflineRewards.describe_time(2 * 3600 + 15 * 60) == "2 h 15 min" and OfflineRewards.describe_time(45 * 60) == "45 min", "times read well")


func test_time_away_is_banked_once_capped_and_never_backwards() -> void:
	var ready := [0]
	var count := func() -> void: ready[0] += 1
	Profile.offline_ready.connect(count)
	Profile.last_seen = _now[0]
	_now[0] += 3600
	check(Profile.bank_time_away() == 0 and Profile.offline_seconds == 0, "nothing banks before a tier is cleared")
	_cleared(1)
	_now[0] += 3600
	check(Profile.bank_time_away() == 3600 and Profile.offline_seconds == 3600 and ready[0] == 1, "an hour banked, announced once")
	check(Profile.bank_time_away() == 0, "the same hour is not banked twice")
	_now[0] -= 5 * 3600
	check(Profile.bank_time_away() == 0 and Profile.last_seen == _now[0], "a clock set back banks nothing and restarts from there")
	_now[0] += 30 * 3600
	Profile.bank_time_away()
	check(Profile.offline_seconds == OfflineRewards.CAP_SECONDS, "the bank stops at eight hours: %d" % Profile.offline_seconds)
	_now[0] += 3600
	check(Profile.bank_time_away() == 0 and ready[0] == 2, "a full bank takes no more")
	Profile.offline_ready.disconnect(count)


func test_collecting_pays_once() -> void:
	_cleared(3)
	_now[0] += 4 * 3600
	Profile.bank_time_away()
	var expected := OfflineRewards.earned(4 * 3600, 3)
	check(Profile.offline_preview() == expected, "the preview matches the rules")
	var reward := Profile.claim_offline()
	check(reward == expected and Profile.gold == expected.gold and Profile.ash == expected.ash, "paid: %s" % [reward])
	check(Profile.level > 1, "the XP levels the hero: level %d" % Profile.level)
	check(Profile.offline_seconds == 0 and Profile.claim_offline() == {"xp": 0, "gold": 0, "ash": 0}, "a second claim pays nothing")


func test_the_bank_and_the_clock_survive_a_save() -> void:
	Profile.save_path = SAVE
	_cleared(2)
	_now[0] += 3600
	Profile.bank_time_away()
	_now[0] += 60
	Profile.save_profile()
	check(Profile.last_seen == _now[0], "saving stamps the time")
	Profile.reset()
	check(Profile.load_profile() == OK, "loads")
	check(Profile.offline_seconds == 3600 and Profile.last_seen == _now[0] and Profile.tier_cleared == 2,
			"bank, time and cleared tier come back")
	var old := FileAccess.open(SAVE, FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 3, "ash": 0, "claimed": [], "inventory": [], "equipment": {}, "tier_unlocked": 4}))
	old.close()
	check(Profile.load_profile() == OK and Profile.tier_cleared == 3 and Profile.offline_seconds == 0, "an older save: tier 3 cleared, nothing banked")


func test_clearing_the_last_tier_counts() -> void:
	for t in range(1, Difficulty.MAX_TIER + 1):
		Profile.complete_tier(t)
	check(Profile.tier_cleared == Difficulty.MAX_TIER, "tier 10 cleared is remembered")


func test_the_away_screen_pauses_until_collected() -> void:
	_cleared(1)
	_now[0] += 2 * 3600
	Profile.bank_time_away()
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var panel: OfflinePanel = main.get_node("Offline")
	check(panel.visible and get_tree().paused, "the screen is up and the game waits")
	check(not (main.get_node("PauseMenu") as CanvasLayer).visible, "without the pause menu")
	panel.collect()
	check(not panel.visible and not get_tree().paused, "Collect resumes the game")
	check(Profile.gold == 170 and Profile.offline_seconds == 0, "and pays: %d gold" % Profile.gold)
	main.free()
	await wait_physics_frames(1)
	var again := instantiate_main()
	add_child(again)
	await wait_physics_frames(2)
	check(not (again.get_node("Offline") as OfflinePanel).visible and not get_tree().paused, "nothing to collect, no screen")


func test_unpausing_without_collecting_keeps_the_time() -> void:
	_cleared(1)
	_now[0] += 3600
	Profile.bank_time_away()
	var main := instantiate_main()
	add_child(main)
	await wait_physics_frames(2)
	var panel: OfflinePanel = main.get_node("Offline")
	(main.get_node("PauseController") as PauseController).set_paused(false)
	check(not panel.visible and Profile.offline_seconds == 3600, "hidden, still banked")
