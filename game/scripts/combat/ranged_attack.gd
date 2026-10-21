class_name RangedAttack
extends MeleeAttack
## An attack that fires a Projectile when its windup ends, instead of striking
## the area in front of the attacker. Same windup → release → recovery cycle,
## signals and cancel rules as MeleeAttack; `struck` fires at the release with
## no targets, since the projectile hits (or misses) later on its own.
##
## `data` must be a ProjectileAttackData. Projectiles are added next to the
## attacker, so they belong to the same level and go when it goes.

@export var projectile_scene: PackedScene


func _strike() -> Array[Health]:
	var shooter := get_parent() as Node3D
	var settings := data as ProjectileAttackData
	if projectile_scene == null or settings == null or shooter.get_parent() == null:
		push_error("%s: a RangedAttack needs a projectile scene and ProjectileAttackData." % shooter.name)
		return []
	var projectile := projectile_scene.instantiate() as Projectile
	projectile.direction = direction
	projectile.speed = settings.speed
	projectile.damage = settings.damage
	projectile.max_distance = settings.reach
	projectile.target_mask = target_mask
	if shooter is CollisionObject3D:
		projectile.exclude = [(shooter as CollisionObject3D).get_rid()]
	projectile.position = shooter.position + Vector3.UP * settings.height
	shooter.add_sibling(projectile)
	return []
