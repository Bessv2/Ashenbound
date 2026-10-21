class_name BakedNavigationRegion
extends NavigationRegion3D
## A navigation region that bakes its navigation mesh from its children when it
## enters the tree, so the mesh always matches the level as built.
##
## `navigation_mesh` holds the bake settings. It is usually a shared resource
## file, so the bake goes into a private copy: baking into the shared one would
## hand this level's polygons to every other region that uses it.
##
## The bake runs on the main thread, during scene load. For the test arena it
## takes about 10 ms on a desktop CPU. Bake larger levels in the editor instead.


func _ready() -> void:
	if navigation_mesh == null:
		push_error("%s has no navigation mesh settings to bake with." % name)
		return
	navigation_mesh = navigation_mesh.duplicate()
	bake_navigation_mesh(false)
