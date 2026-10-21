class_name PerfLog
extends Node
## Debug builds only: every `interval` seconds of real time, prints one line of
## frame statistics, for measuring performance on a device:
##
##   adb logcat -s godot | grep PERF
##
## Runs while paused too, so a paused game still reports. Removes itself in
## release builds and headless runs (tests), where nobody reads the output.

const PREFIX := "PERF"

@export_range(1.0, 60.0, 0.5, "suffix:s") var interval: float = 5.0

var _elapsed: float = 0.0
var _frames: int = 0
var _worst_frame: float = 0.0


func _ready() -> void:
	if not OS.is_debug_build() or DisplayServer.get_name() == "headless":
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_elapsed += delta
	_frames += 1
	_worst_frame = maxf(_worst_frame, delta)
	if _elapsed < interval:
		return
	print(format_line(_frames / _elapsed, _worst_frame,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.MEMORY_STATIC)))
	_elapsed = 0.0
	_frames = 0
	_worst_frame = 0.0


## One log line: average FPS over the interval, the slowest frame, draw calls
## in the last frame, live nodes and static memory.
static func format_line(fps: float, worst_frame: float, draw_calls: float, nodes: float, static_memory: float) -> String:
	return "%s fps=%.1f worst_ms=%.1f draw_calls=%d nodes=%d static_mb=%.1f" % [
			PREFIX, fps, worst_frame * 1000.0, int(draw_calls), int(nodes), static_memory / 1048576.0]
