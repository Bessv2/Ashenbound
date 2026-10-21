extends Logger
## Counts engine and script errors so the runner can fail a test that logged
## one, even when every assertion passed. Warnings are not counted.
## Loggers can be called from any thread, hence the mutex.

var _mutex := Mutex.new()
var _errors: PackedStringArray = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	_errors.append("%s (%s:%d in %s)" % [rationale if rationale else code, file, line, function])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func take_errors() -> PackedStringArray:
	_mutex.lock()
	var errors := _errors.duplicate()
	_errors.clear()
	_mutex.unlock()
	return errors
