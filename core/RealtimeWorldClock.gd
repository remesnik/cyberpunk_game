class_name RealtimeWorldClock
extends Node

signal elapsed_time_changed(elapsed_seconds: float)

var elapsed_seconds := 0.0
var running := false
var _pause_policy: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _pause_policy == null:
		_pause_policy = get_node_or_null("/root/PausePolicy")


func bind_pause_policy(policy: Node) -> void:
	_pause_policy = policy


func start(reset_time := true) -> void:
	if reset_time:
		elapsed_seconds = 0.0
	running = true
	elapsed_time_changed.emit(elapsed_seconds)


func stop() -> void:
	running = false


func restore(saved_elapsed_seconds: float, resume := true) -> void:
	elapsed_seconds = maxf(0.0, saved_elapsed_seconds)
	running = resume
	elapsed_time_changed.emit(elapsed_seconds)


func _process(delta: float) -> void:
	if not running or (_pause_policy != null and not _pause_policy.allows_realtime_advance()):
		return
	elapsed_seconds += delta
	elapsed_time_changed.emit(elapsed_seconds)


func formatted_session_time() -> String:
	var total_centiseconds := int(floor(elapsed_seconds * 100.0))
	var minutes := total_centiseconds / 6000
	var seconds := (total_centiseconds / 100) % 60
	var centiseconds := total_centiseconds % 100
	return "%02d:%02d.%02d" % [minutes, seconds, centiseconds]
