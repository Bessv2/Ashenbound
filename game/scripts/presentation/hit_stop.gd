class_name HitStop
extends RefCounted
## A brief freeze when a heavy blow lands, so it is felt: the whole game runs
## at `scale` of its speed for `seconds` of real time, then resumes. Only in
## looks A and B (ArtStyle); the classic look never freezes. Presentation
## only: the simulation just runs slower for a moment, so no rule changes.
## Main resets it when the run ends or the scene goes.

## Bumped by each stop, so only the latest one ends the freeze.
static var _serial: int = 0


## Freezes the game briefly. A stop already running is extended, not stacked.
static func trigger(tree: SceneTree, seconds: float = 0.06, scale: float = 0.05) -> void:
	if tree == null or ArtStyle.current() == ArtStyle.Look.CLASSIC or tree.paused:
		return
	_serial += 1
	var mine := _serial
	Engine.time_scale = scale
	# Real time: the timer ignores the time scale it is undoing.
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if mine == _serial:
			Engine.time_scale = 1.0)


## A slow-motion beat (looks A and B): the game drops to `scale` of its
## speed and eases back to full over `seconds` of real time. For moments that
## should change the pace: a boss falling, a room cleared. Like a freeze, it
## only slows the simulation; a freeze or beat that starts later takes over.
static func slow_motion(tree: SceneTree, seconds: float = 0.9, scale: float = 0.25) -> void:
	if tree == null or ArtStyle.current() == ArtStyle.Look.CLASSIC or tree.paused:
		return
	_serial += 1
	var mine := _serial
	Engine.time_scale = scale
	var steps := 6
	for i in steps:
		# Holds at the slowest for the first third, then eases back up.
		var at := seconds * (0.35 + 0.65 * float(i + 1) / steps)
		var to := lerpf(scale, 1.0, float(i + 1) / steps)
		tree.create_timer(at, true, false, true).timeout.connect(func() -> void:
			if mine == _serial:
				Engine.time_scale = to)


## Whether a freeze is running.
static func is_active() -> bool:
	return Engine.time_scale < 1.0


## Ends any freeze at once.
static func reset() -> void:
	_serial += 1
	Engine.time_scale = 1.0
