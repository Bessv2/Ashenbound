extends "res://tests/framework/test_case.gd"
## Unit tests for the Health component.

var health: Health
var damaged_events: Array = []
var deaths: int = 0
var revives: int = 0


func _ready() -> void:
	health = Health.new()
	health.max_health = 30
	add_child(health)
	health.damaged.connect(func(amount: int, remaining: int) -> void: damaged_events.append([amount, remaining]))
	health.died.connect(func() -> void: deaths += 1)
	health.revived.connect(func() -> void: revives += 1)


func test_starts_at_full_health() -> void:
	check(health.current == 30 and not health.is_dead(), "should start full")


func test_damage_reduces_health() -> void:
	check(health.apply_damage(12) == 12, "returns damage dealt")
	check(health.current == 18, "current health")
	check(damaged_events == [[12, 18]], "damaged signal: %s" % [damaged_events])
	check(deaths == 0, "not dead yet")


func test_overkill_is_clamped_and_dies_once() -> void:
	health.apply_damage(25)
	check(health.apply_damage(25) == 5, "only the remaining 5 is dealt")
	check(health.current == 0 and health.is_dead(), "dead at zero")
	check(deaths == 1, "died emitted once")
	check(health.apply_damage(10) == 0, "dead targets take no damage")
	check(deaths == 1 and damaged_events.size() == 2, "no signals after death")


func test_non_positive_damage_is_ignored() -> void:
	check(health.apply_damage(0) == 0 and health.apply_damage(-5) == 0, "no damage dealt")
	check(health.current == 30 and damaged_events.is_empty(), "health unchanged, no signal")


func test_revive_restores_full_health() -> void:
	health.apply_damage(30)
	health.revive()
	check(health.current == 30 and not health.is_dead(), "full health after revive")
	check(revives == 1, "revived emitted")


func test_of_finds_health_on_a_body() -> void:
	var body := StaticBody3D.new()
	var child := Health.new()
	body.add_child(Node.new())
	body.add_child(child)
	add_child(body)
	check(Health.of(body) == child, "finds the Health child")
	check(Health.of(child) == child, "a Health is its own Health")
	check(Health.of(self) == health, "finds the suite's Health")
	var plain := Node3D.new()
	add_child(plain)
	check(Health.of(plain) == null, "null when there is none")
