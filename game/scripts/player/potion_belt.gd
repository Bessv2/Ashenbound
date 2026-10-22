class_name PotionBelt
extends Node
## The hero's health potions (docs/CHAMPIONS.md#health-potions). A run starts
## with a full belt of `max_charges`. Drinking one, on the potion action,
## heals HEAL_SHARE of the hero's health at once; the next can be drunk
## COOLDOWN later. A hero at full health does not waste one.
##
## Kills refill it: one charge for every KILLS_PER_CHARGE ordinary kills, and
## one at once for a champion, an elite or a boss. Kills made while the belt is
## full do not count toward the next charge. Main gives it the hero's Health
## and passes it the run's kills.

signal changed
## A potion was drunk and restored `amount`.
signal drunk(amount: int)

const HEAL_SHARE := 0.35
const COOLDOWN := 1.0
const KILLS_PER_CHARGE := 6
const COLOR := Color(0.85, 0.12, 0.15)

@export_range(1, 10, 1) var max_charges: int = 3

var charges: int = 0
## The hero's Health, which potions heal.
var health: Health
## When false, the potion action is ignored (the run is over).
var input_enabled: bool = true
## Ordinary kills counted toward the next charge.
var kills_toward_charge: int = 0

var _cooldown_left: float = 0.0


func _ready() -> void:
	charges = max_charges


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if input_enabled and Input.is_action_just_pressed(GameplayActions.POTION):
		drink()


## Drinks a potion if there is one, the last was not just drunk, and the hero
## is alive and hurt. Returns the health restored (0 when nothing was drunk).
func drink() -> int:
	if charges <= 0 or _cooldown_left > 0.0 or health == null or health.is_dead() \
			or health.current >= health.max_health:
		return 0
	var restored := health.heal(ceili(health.max_health * HEAL_SHARE))
	charges -= 1
	_cooldown_left = COOLDOWN
	var body := health.get_parent() as Node3D
	if body and body.get_parent():
		Vfx.burst(body.get_parent(), body.global_position + Vector3.UP * 1.0, COLOR, 14, 2.5, 0.5)
	drunk.emit(restored)
	changed.emit()
	return restored


## Counts a kill toward the next charge: a champion, an elite or a boss gives
## one at once.
func on_kill(enemy: Node3D) -> void:
	if charges >= max_charges or not enemy is EnemyController:
		return
	var controller := enemy as EnemyController
	if Champion.of(controller) or not controller.champion_eligible:
		_add_charge()
		return
	kills_toward_charge += 1
	if kills_toward_charge >= KILLS_PER_CHARGE:
		_add_charge()
	else:
		changed.emit()


func _add_charge() -> void:
	charges = mini(charges + 1, max_charges)
	kills_toward_charge = 0
	changed.emit()


## For the HUD button: the cooldown share still to run, or a full sweep while
## the belt is empty, so the button flashes when a charge comes back.
func cooldown_fraction() -> float:
	if charges <= 0:
		return 1.0
	return _cooldown_left / COOLDOWN
