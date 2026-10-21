extends "res://tests/framework/test_case.gd"
## Tests for HitFeedback and DamageNumber.

var body: Node3D
var health: Health
var nested_mesh: MeshInstance3D
var feedback: HitFeedback
var flash := StandardMaterial3D.new()


func _ready() -> void:
	body = Node3D.new()
	health = Health.new()
	body.add_child(health)
	var visual := Node3D.new()
	var group := Node3D.new()
	nested_mesh = MeshInstance3D.new()
	group.add_child(nested_mesh)
	visual.add_child(group)
	body.add_child(visual)
	feedback = HitFeedback.new()
	feedback.health = health
	feedback.visual = visual
	feedback.flash_material = flash
	feedback.flash_duration = 0.1
	feedback.number_color = Color.RED
	body.add_child(feedback)
	add_child(body)


func _damage_numbers() -> Array[DamageNumber]:
	var numbers: Array[DamageNumber] = []
	for child in body.get_children():
		if child is DamageNumber:
			numbers.append(child)
	return numbers


func test_damage_flashes_nested_meshes_briefly() -> void:
	health.apply_damage(5)
	check(nested_mesh.material_overlay == flash, "nested mesh should flash")
	await wait_physics_frames(8)  # 0.133 s > 0.1 s flash.
	check(nested_mesh.material_overlay == null, "flash should clear")


func test_damage_spawns_a_colored_number() -> void:
	health.apply_damage(7)
	var numbers := _damage_numbers()
	check(numbers.size() == 1, "one damage number")
	if numbers.size() == 1:
		check(numbers[0].text == "7", "shows the amount dealt")
		check(numbers[0].modulate.is_equal_approx(Color.RED), "uses the configured color")
	await wait_physics_frames(int(DamageNumber.DURATION * 60) + 2)
	check(_damage_numbers().is_empty(), "number frees itself after its animation")


func test_no_feedback_without_damage() -> void:
	health.apply_damage(0)
	check(nested_mesh.material_overlay == null and _damage_numbers().is_empty(),
			"zero damage shows nothing")
