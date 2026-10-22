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

var _rebake_pending: bool = false


func _ready() -> void:
	if navigation_mesh == null:
		push_error("%s has no navigation mesh settings to bake with." % name)
		return
	navigation_mesh = navigation_mesh.duplicate()
	bake_navigation_mesh(false)


## Bakes again, for a level whose obstacles changed (a gate closing). Where
## the build has threads, the bake runs on a worker thread (about 15 ms of work
## for the crypt on a desktop CPU, more on a phone) and the old mesh stays in
## use until it is done. The single-threaded web preview bakes in place. Several
## requests in one frame cost one bake; a request during a bake queues one more.
func request_rebake() -> void:
	if _rebake_pending:
		return
	_rebake_pending = true
	_rebake.call_deferred()


func _rebake() -> void:
	if navigation_mesh == null:
		_rebake_pending = false
		return
	if is_baking():
		if not bake_finished.is_connected(_rebake):
			bake_finished.connect(_rebake, CONNECT_ONE_SHOT)
		return
	_rebake_pending = false
	bake_navigation_mesh(OS.has_feature("threads"))
