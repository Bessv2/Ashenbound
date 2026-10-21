extends "res://tests/framework/test_case.gd"
## Tests for MeleeAttack against real physics bodies, outside the main scene.

const DummyScene := preload("res://scenes/enemies/training_dummy.tscn")

var attacker: CharacterBody3D
var attack: MeleeAttack
var strikes: Array = []


func _ready() -> void:
	attacker = CharacterBody3D.new()
	attacker.collision_layer = 2
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	attacker.add_child(shape)
	attack = MeleeAttack.new()
	attack.data = AttackData.new()
	attack.data.damage = 10
	attack.data.reach = 1.8
	attack.data.arc_degrees = 120.0
	attack.data.windup = 0.125
	attack.data.recovery = 0.375
	attack.data.aim_assist_radius = 0.0
	attacker.add_child(attack)
	add_child(attacker)
	attack.struck.connect(func(targets: Array[Health]) -> void: strikes.append(targets))


func _dummy_at(position: Vector3) -> TrainingDummy:
	var dummy: TrainingDummy = DummyScene.instantiate()
	add_child(dummy)
	dummy.global_position = position
	return dummy


## Lets newly added bodies register with the physics server.
func _settle() -> void:
	await wait_physics_frames(2)


func test_is_in_arc() -> void:
	var forward := Vector3.FORWARD
	check(MeleeAttack.is_in_arc(Vector3(0, 0, -2), forward, 120.0), "straight ahead")
	check(MeleeAttack.is_in_arc(Vector3(1, 0, -1), forward, 120.0), "45° is inside a 120° arc")
	check(not MeleeAttack.is_in_arc(Vector3(1, 0, 0), forward, 120.0), "90° is outside a 120° arc")
	check(not MeleeAttack.is_in_arc(Vector3(0, 0, 2), forward, 120.0), "behind")
	check(MeleeAttack.is_in_arc(Vector3(0, 0, 2), forward, 360.0), "a full circle hits behind")
	check(MeleeAttack.is_in_arc(Vector3(0, 5, 0), forward, 30.0), "a target at the same spot counts")


func test_hit_lands_when_the_windup_ends() -> void:
	var dummy := _dummy_at(Vector3(0, 0, -1.5))
	await _settle()
	check(attack.try_start(Vector3.FORWARD), "attack should start")
	check(attack.is_busy(), "busy during windup")
	await wait_physics_frames(7)  # 0.117 s of a 0.125 s windup.
	check(dummy.health.current == 50, "no damage before the windup ends")
	await wait_physics_frames(1)
	check(dummy.health.current == 40, "hit lands at the end of the windup, health %d" % dummy.health.current)
	check(strikes.size() == 1 and strikes[0].size() == 1, "struck reports one target")


func test_cannot_start_again_until_recovered() -> void:
	await _settle()
	attack.try_start(Vector3.FORWARD)
	check(not attack.try_start(Vector3.FORWARD), "no second attack during windup")
	await wait_physics_frames(20)
	check(not attack.try_start(Vector3.FORWARD), "no second attack during recovery")
	await wait_physics_frames(11)  # 31 frames = 0.517 s > windup + recovery.
	check(attack.try_start(Vector3.FORWARD), "ready again after recovery")


func test_misses_targets_behind_and_out_of_reach() -> void:
	var behind := _dummy_at(Vector3(0, 0, 1.5))
	var far := _dummy_at(Vector3(0, 0, -3.5))
	await _settle()
	attack.try_start(Vector3.FORWARD)
	await wait_physics_frames(10)
	check(behind.health.current == 50, "target behind is not hit")
	check(far.health.current == 50, "target out of reach is not hit")
	check(strikes.size() == 1 and strikes[0].is_empty(), "struck reports a miss")


func test_hits_every_target_in_the_arc() -> void:
	var left := _dummy_at(Vector3(-0.9, 0, -1.2))
	var right := _dummy_at(Vector3(0.9, 0, -1.2))
	await _settle()
	attack.try_start(Vector3.FORWARD)
	await wait_physics_frames(10)
	check(left.health.current == 40 and right.health.current == 40, "both targets hit")


func test_never_hits_the_attacker() -> void:
	attacker.collision_layer = 4  # Same layer as the targets.
	var own_health := Health.new()
	attacker.add_child(own_health)
	await _settle()
	attack.try_start(Vector3.FORWARD)
	await wait_physics_frames(10)
	check(own_health.current == own_health.max_health, "attacker must not damage itself")


func test_aim_assist_turns_toward_the_nearest_target() -> void:
	attack.data.aim_assist_radius = 4.0
	var near := _dummy_at(Vector3(1.5, 0, 0))  # 90° to the right: outside the arc.
	var far := _dummy_at(Vector3(-3.0, 0, 0))
	await _settle()
	attack.try_start(Vector3.FORWARD)
	check_vector_near(attack.direction, Vector3.RIGHT, 0.001, "aims at the nearest target")
	await wait_physics_frames(10)
	check(near.health.current == 40, "nearest target is hit")
	check(far.health.current == 50, "farther target is not hit")


func test_without_targets_the_attack_keeps_its_facing() -> void:
	attack.data.aim_assist_radius = 4.0
	await _settle()
	attack.try_start(Vector3.LEFT)
	check_vector_near(attack.direction, Vector3.LEFT, 0.001, "facing is kept")


func test_dead_targets_are_ignored() -> void:
	attack.data.aim_assist_radius = 4.0
	var dead := _dummy_at(Vector3(1.0, 0, 0))
	dead.health.apply_damage(1000)
	await _settle()
	attack.try_start(Vector3.FORWARD)
	check_vector_near(attack.direction, Vector3.FORWARD, 0.001, "aim assist skips dead targets")
