extends "res://tests/framework/test_case.gd"
## Tests for the title screen: the roster's cards, choosing a class and a
## tier through Profile, and the way in.

const TitleScene := preload("res://scenes/title.tscn")


func _exit_tree() -> void:
	Profile.save_path = ""
	Profile.reset()


func _title() -> TitleScreen:
	var title: TitleScreen = TitleScene.instantiate()
	add_child(title)
	# The way in changes scene; here only the request is checked.
	title.enter_requested.disconnect(title._go_to_crypt)
	return title


func test_the_roster_is_shown_and_only_playable_classes_can_be_chosen() -> void:
	var title := _title()
	var cards := title.find_child("Cards", true, false).get_children()
	check(cards.size() == 6, "a card per class: %d" % cards.size())
	check(title.playable_classes() == ["warden", "reaver", "hexbinder", "dreadhunter"], "four playable: %s" % [title.playable_classes()])
	check(cards.filter(func(c: Button) -> bool: return c.disabled).size() == 2, "the other two are locked")
	check(title.choose("reaver") and Profile.hero_class == "reaver", "the Reaver chosen")
	check(not title.choose("gravecaller") and Profile.hero_class == "reaver", "a locked class cannot be")
	title.free()


func test_the_tier_stays_within_the_open_tiers() -> void:
	Profile.complete_tier(1)
	var title := _title()
	title.step_tier(1)
	check(Profile.tier == 2, "up to tier 2")
	title.step_tier(1)
	check(Profile.tier == 2, "not past the highest open tier")
	title.step_tier(-5)
	check(Profile.tier == 1, "not below tier 1")
	title.free()


func test_enter_asks_for_the_crypt() -> void:
	var title := _title()
	var asked := [0]
	title.enter_requested.connect(func() -> void: asked[0] += 1)
	(title.find_child("Enter", true, false) as Button).pressed.emit()
	check(asked[0] == 1, "Enter the crypt asks once")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title.tscn", "the game starts on the title screen")
	title.free()
