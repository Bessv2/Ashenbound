class_name ProjectileAttackData
extends AttackData
## Tuning for an attack that fires a projectile. `reach` is how far the
## projectile flies; `arc_degrees` is unused. The hit lands when the
## projectile touches a target, not when the windup ends.

@export_range(1.0, 60.0, 0.5, "suffix:m/s") var speed: float = 10.0
## Half the width of the telegraphed line on the ground.
@export_range(0.05, 2.0, 0.05, "suffix:m") var radius: float = 0.3
## Height above the attacker's origin the projectile flies at.
@export_range(0.0, 5.0, 0.05, "suffix:m") var height: float = 1.1
