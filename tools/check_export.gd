extends SceneTree
## Loads an exported game package and fails when data the game needs came out
## empty. Godot 4.7.2's export-time conversion of text resources to binary
## dropped every PackedStringArray (wave spawn markers, skill branch names,
## hidden model parts), which left the crypt's rooms without enemies and their
## doors shut. The project now exports text resources as text; this guards it.
##
## Usage: godot --headless --main-pack <index.pck> --script tools/check_export.gd


func _initialize() -> void:
	var problems: PackedStringArray = []
	var encounter: Resource = load("res://resources/encounters/ossuary_hall.tres")
	if encounter == null or encounter.waves.is_empty() or encounter.waves[0].markers.is_empty():
		problems.append("the Ossuary's waves have no spawn markers")
	var tree: Resource = load("res://resources/skills/warden_tree.tres")
	if tree == null or tree.branches.is_empty():
		problems.append("the Warden's skill tree has no branch names")
	var warden: Node = (load("res://scenes/player/warden.tscn") as PackedScene).instantiate()
	if (warden.get_node("ModelDressing").hidden_parts as PackedStringArray).is_empty():
		problems.append("the Warden hides no model parts")
	warden.free()
	if problems.is_empty():
		print("export check passed")
		quit(0)
	else:
		printerr("export check FAILED: " + "; ".join(problems))
		quit(1)
