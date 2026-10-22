class_name BossBar
extends VBoxContainer
## The boss's name and health across the top of the screen. It looks for a
## living node in the "boss" group (with a Health) while it has none, so a
## boss that spawns mid-run shows up without anyone wiring it. Hidden when
## there is no living boss. Presentation only.

const BOSS_GROUP := &"boss"

@export var boss_name: String = "THE ASHEN LORD"

var _health: Health

@onready var _label: Label = $Name
@onready var _bar: ProgressBar = $Bar


func _ready() -> void:
	hide()


func _process(_delta: float) -> void:
	if _health and is_instance_valid(_health) and not _health.is_dead():
		_bar.max_value = _health.max_health
		_bar.value = _health.current
		return
	_health = null
	hide()
	var boss := get_tree().get_first_node_in_group(BOSS_GROUP)
	var health := Health.of(boss) if boss else null
	if health and not health.is_dead():
		_health = health
		_label.text = boss.display_title if boss is AshenLord else boss_name
		show()


## The boss being shown, or null.
func tracked() -> Health:
	return _health
