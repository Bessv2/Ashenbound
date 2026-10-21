class_name AttackData
extends Resource
## Tuning for one melee attack, kept as data so characters can share it.

@export_range(1, 1000, 1) var damage: int = 10
## Distance from the attacker's origin that the hit reaches.
@export_range(0.5, 10.0, 0.05, "suffix:m") var reach: float = 1.8
## Width of the hit cone, centered on the attack direction.
@export_range(10.0, 360.0, 1.0, "degrees") var arc_degrees: float = 120.0
## Time from starting the attack to the hit.
@export_range(0.0, 2.0, 0.01, "suffix:s") var windup: float = 0.12
## Time after the hit before the next attack can start.
@export_range(0.0, 2.0, 0.01, "suffix:s") var recovery: float = 0.33
## Movement speed factor while attacking.
@export_range(0.0, 1.0, 0.05) var movement_multiplier: float = 0.35
## The attack turns toward the nearest living target within this radius.
## 0 disables aim assist.
@export_range(0.0, 20.0, 0.1, "suffix:m") var aim_assist_radius: float = 4.0
## Pushes each target that took damage this far away from the attacker.
@export_range(0.0, 10.0, 0.1, "suffix:m") var knockback: float = 0.0
