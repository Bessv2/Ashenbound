class_name Health
extends Node
## Hit points for anything that can be damaged. Add it as a direct child of
## the body that attacks should hit; Health.of() finds it from the collider.

signal damaged(amount: int, remaining: int)
signal died
signal revived

@export_range(1, 100000, 1) var max_health: int = 100

var current: int = 0


func _ready() -> void:
	current = max_health


func is_dead() -> bool:
	return current <= 0


## Applies damage and returns the amount actually dealt, which is less than
## `amount` when it exceeds the remaining health. Dead targets take none.
func apply_damage(amount: int) -> int:
	if is_dead() or amount <= 0:
		return 0
	var dealt := mini(amount, current)
	current -= dealt
	damaged.emit(dealt, current)
	if current == 0:
		died.emit()
	return dealt


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
