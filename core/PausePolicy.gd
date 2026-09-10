extends Node

signal mode_changed(previous_mode: Mode, current_mode: Mode)
signal audio_pause_changed(paused: bool)
signal hard_pause_denied(reason: String)

enum Mode { GAMEPLAY, SOFT_PAUSE, HARD_PAUSE }

var mode: Mode = Mode.GAMEPLAY
var hard_pause_available: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("pause_game"):
		if mode == Mode.HARD_PAUSE:
			set_mode(Mode.GAMEPLAY)
		else:
			set_mode(Mode.HARD_PAUSE)
		get_viewport().set_input_as_handled()


func set_mode(next_mode: Mode) -> bool:
	if next_mode == mode:
		return true
	if next_mode == Mode.HARD_PAUSE and not hard_pause_available:
		hard_pause_denied.emit("Hard pause is unavailable for this session.")
		return false
	var previous := mode
	# Unpause first so all pausable nodes can observe the transition out of hard pause.
	if previous == Mode.HARD_PAUSE and next_mode != Mode.HARD_PAUSE:
		get_tree().paused = false
	mode = next_mode
	if next_mode == Mode.HARD_PAUSE:
		get_tree().paused = true
	mode_changed.emit(previous, mode)
	audio_pause_changed.emit(mode == Mode.HARD_PAUSE)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.pause_changed.emit(mode == Mode.HARD_PAUSE)
		event_bus.pause_policy_changed.emit(previous, mode)
	return true


func enter_soft_pause() -> bool:
	return set_mode(Mode.SOFT_PAUSE)


func resume_gameplay() -> bool:
	return set_mode(Mode.GAMEPLAY)


func allows_cyberspace_actions() -> bool:
	return mode == Mode.GAMEPLAY


func allows_realtime_advance() -> bool:
	return mode != Mode.HARD_PAUSE


func should_pause_audio() -> bool:
	return mode == Mode.HARD_PAUSE


func mode_label() -> String:
	return ["GAMEPLAY", "SOFT PAUSE", "HARD PAUSE"][mode]
