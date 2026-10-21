extends Logger
## Collects engine and script errors so the runner can fail a test that logged
## one, even when every assertion passed. Warnings are collected separately and
## reported without failing the test. Loggers can be called from any thread,
## hence the mutex.

var _mutex := Mutex.new()
var _errors: PackedStringArray = []
var _warnings: PackedStringArray = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var entry := "%s (%s:%d in %s)" % [rationale if rationale else code, file, line, function]
	_mutex.lock()
	if error_type == ERROR_TYPE_WARNING:
		_warnings.append(entry)
	else:
		_errors.append(entry)
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func take_errors() -> PackedStringArray:
	_mutex.lock()
	var errors := _errors.duplicate()
	_errors.clear()
	_mutex.unlock()
	return errors


func take_warnings() -> PackedStringArray:
	_mutex.lock()
	var warnings := _warnings.duplicate()
	_warnings.clear()
	_mutex.unlock()
	return warnings
