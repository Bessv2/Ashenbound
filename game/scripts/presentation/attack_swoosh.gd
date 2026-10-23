class_name AttackSwoosh
extends Node
## Draws a glowing arc along each attack's reach and arc when its hit
## resolves: ember for a normal hit, gold for a critical one. Visual only.

const CRIT_COLOR := Color(1.0, 0.85, 0.35)

@export var attacks: Array[MeleeAttack] = []
@export var color: Color = Color(1.0, 0.45, 0.15)


func _ready() -> void:
	for attack in attacks:
		attack.struck.connect(_on_struck.bind(attack))


func _on_struck(targets: Array[Health], attack: MeleeAttack) -> void:
	var owner_body := attack.get_parent() as Node3D
	if owner_body == null:
		return
	var critical := attack.last_hit_critical and not targets.is_empty()
	var arc := minf(attack.data.arc_degrees, 359.0)
	var hue := CRIT_COLOR if critical else color
	match ArtStyle.current():
		ArtStyle.Look.HEROIC:
			RealFx.swing(owner_body, attack.direction, attack.data.reach, arc, hue)
		ArtStyle.Look.GRIM:
			ToonFx.swing(owner_body, attack.direction, attack.data.reach, arc, hue)
		_:
			Vfx.slash(owner_body, attack.direction, attack.data.reach, arc, hue)
	# A landed blow freezes the moment (looks A and B); a critical one longer.
	if not targets.is_empty() and owner_body.is_inside_tree():
		HitStop.trigger(owner_body.get_tree(), 0.09 if critical else 0.055)
