class_name Health
extends Node
## Hit points for anything that can be damaged. Add it as a direct child of
## the body that attacks should hit; Health.of() finds it from the collider.

## Something tried to deal `amount` damage to this living, vulnerable target,
## before mitigation. Emitted before `damaged`, and even when mitigation
## leaves nothing to deal.
signal hit(amount: int)
signal damaged(amount: int, remaining: int)
signal died
signal revived
## Health was restored by `amount`, leaving `remaining`.
signal healed(amount: int, remaining: int)

@export_range(1, 100000, 1) var max_health: int = 100

var current: int = 0
## While true, apply_damage() deals nothing. Set by Dodge during its
## invulnerable window.
var invulnerable: bool = false
## Share of each hit that is dealt, rounded to the nearest whole point. Set by
## Bulwark Guard while it is up.
var damage_multiplier: float = 1.0
## Reduces every hit: damage × 100 / (100 + armour). From equipment.
var armor: int = 0
## Optional: returns an extra damage factor for a hit coming from a world
## position, e.g. a shield that halves hits from the front (FrontalGuard).
## Called only for hits that say where they come from.
var direction_multiplier: Callable


func _ready() -> void:
	current = max_health


func is_dead() -> bool:
	return current <= 0


## Applies damage and returns the amount actually dealt: `amount` scaled by
## `damage_multiplier` (and by `direction_multiplier` when `from`, the world
## position the hit comes from, is given), and no more than the remaining
## health. Dead and invulnerable targets take none.
func apply_damage(amount: int, from: Vector3 = Vector3.INF) -> int:
	if is_dead() or invulnerable or amount <= 0:
		return 0
	var multiplier := damage_multiplier * 100.0 / (100.0 + maxi(armor, 0))
	if from != Vector3.INF and direction_multiplier.is_valid():
		multiplier *= direction_multiplier.call(from)
	# Fixed before `hit` is emitted, so a handler that changes the multiplier
	# (a guard ending, for one) does not change this hit.
	var mitigated := maxi(roundi(amount * multiplier), 0)
	hit.emit(amount)
	if mitigated == 0 or is_dead():
		return 0
	var dealt := mini(mitigated, current)
	current -= dealt
	damaged.emit(dealt, current)
	if current == 0:
		died.emit()
	return dealt


## Restores up to `amount` health, never above `max_health`, and returns how
## much was restored. The dead stay dead (see revive()).
func heal(amount: int) -> int:
	if is_dead() or amount <= 0:
		return 0
	var restored := mini(amount, max_health - current)
	if restored == 0:
		return 0
	current += restored
	healed.emit(restored, current)
	return restored


func revive() -> void:
	current = max_health
	revived.emit()


## The Health on `node` itself or among its direct children, or null.
static func of(node: Node) -> Health:
	if node is Health:
		return node
	for child in node.get_children():
		if child is Health:
			return child
	return null
