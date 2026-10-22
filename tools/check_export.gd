extends SceneTree
## Loads an exported game package and fails when data the game needs came out
## empty. Godot 4.7.2's export-time conversion of text resources to binary
## dropped every PackedStringArray (wave spawn markers, skill branch names,
## hidden model parts), which left the crypt's rooms without enemies and their
## doors shut. The project now exports text resources as text; this guards it.
## Each check runs only when its file is in the package.
##
## Usage: godot --headless --main-pack <index.pck> --script tools/check_export.gd

const WARDEN := "res://scenes/player/warden.tscn"
const OSSUARY := "res://resources/encounters/ossuary_hall.tres"
const WARDEN_TREE := "res://resources/skills/warden_tree.tres"


func _initialize() -> void:
	var problems: PackedStringArray = []
	var checked := 0
	if ResourceLoader.exists(WARDEN):
		checked += 1
		var warden: Node = (load(WARDEN) as PackedScene).instantiate()
		if (warden.get_node("ModelDressing").hidden_parts as PackedStringArray).is_empty():
			problems.append("the Warden hides no model parts")
		warden.free()
	if ResourceLoader.exists(OSSUARY):
		checked += 1
		var encounter: Resource = load(OSSUARY)
		if encounter.waves.is_empty() or encounter.waves[0].markers.is_empty():
			problems.append("the Ossuary's waves have no spawn markers")
	if ResourceLoader.exists(WARDEN_TREE):
		checked += 1
		if (load(WARDEN_TREE).branches as PackedStringArray).is_empty():
			problems.append("the Warden's skill tree has no branch names")
	if checked == 0:
		problems.append("none of the checked files is in the package")
	if problems.is_empty():
		print("export check passed (%d checks)" % checked)
		quit(0)
	else:
		printerr("export check FAILED: " + "; ".join(problems))
		quit(1)
