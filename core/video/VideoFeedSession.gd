class_name VideoFeedSession
extends RefCounted

signal feed_state_changed(feed_id: StringName)
signal authored_event_occurred(feed_id: StringName, event: Dictionary)

var definition: VideoFeedDefinition
var realtime_process_id: StringName
var elapsed_time := 0.0
var current_state := "INITIALIZING"
var active_entities: Dictionary = {}
var occurred_events: Array[Dictionary] = []
var player_recording := false
var recorded_events: Array[Dictionary] = []
var replaying := false
var feed_state: VideoFeedState.Value = VideoFeedState.Value.LIVE
var frozen_snapshot: Dictionary = {}
var loop_snapshot: Dictionary = {}
var spoof_snapshot: Dictionary = {}
var frame_history: Array[Dictionary] = []
var _last_elapsed := -0.000001


func _init(feed_definition: VideoFeedDefinition = null, process_id: StringName = &"") -> void:
	definition = feed_definition
	realtime_process_id = process_id


func advance_to(process_elapsed: float) -> void:
	if definition == null:
		return
	var next_elapsed := maxf(_last_elapsed, process_elapsed)
	for event: Dictionary in definition.authored_event_timeline:
		var timestamp := float(event.get("time", 0.0))
		if timestamp <= _last_elapsed or timestamp > next_elapsed:
			continue
		_apply_event(event)
	_last_elapsed = next_elapsed
	elapsed_time = next_elapsed
	feed_state_changed.emit(definition.id)


func begin_recording() -> bool:
	if definition == null or not definition.can_record:
		return false
	player_recording = true
	return true


func stop_recording() -> void:
	player_recording = false


func disable() -> bool:
	if definition == null or not definition.can_disable:
		return false
	definition.online = false
	feed_state = VideoFeedState.Value.OFFLINE
	feed_state_changed.emit(definition.id)
	return true


func begin_replay() -> bool:
	if definition == null or not definition.can_replay or recorded_events.is_empty():
		return false
	replaying = true
	return true


func apply_signal_state(state: VideoFeedState.Value, payload: Dictionary = {}) -> bool:
	match state:
		VideoFeedState.Value.LIVE:
			definition.online = true
			feed_state = state
		VideoFeedState.Value.OFFLINE:
			if not definition.can_disable:
				return false
			definition.online = false
			feed_state = state
		VideoFeedState.Value.FROZEN:
			frozen_snapshot = _capture_snapshot(elapsed_time)
			feed_state = state
		VideoFeedState.Value.LOOPED:
			loop_snapshot = frame_history[maxi(0, frame_history.size() - 2)].duplicate(true) if not frame_history.is_empty() else _capture_snapshot(elapsed_time)
			feed_state = state
		VideoFeedState.Value.SPOOFED:
			spoof_snapshot = payload.get("snapshot", definition.spoof_profiles.get(payload.get("profile_id", &"DEFAULT"), {})).duplicate(true)
			if spoof_snapshot.is_empty():
				spoof_snapshot = {"available": true, "time": elapsed_time, "state": payload.get("description", "ALL CLEAR"), "entities": []}
			feed_state = state
		VideoFeedState.Value.FAULT:
			feed_state = state
	feed_state_changed.emit(definition.id)
	return true


func get_observer_view() -> Dictionary:
	match feed_state:
		VideoFeedState.Value.LIVE:
			return _capture_snapshot(elapsed_time)
		VideoFeedState.Value.OFFLINE, VideoFeedState.Value.FAULT:
			return {"available": false, "time": elapsed_time, "state": VideoFeedState.label(feed_state), "entities": []}
		VideoFeedState.Value.FROZEN:
			return frozen_snapshot.duplicate(true)
		VideoFeedState.Value.LOOPED:
			return loop_snapshot.duplicate(true)
		VideoFeedState.Value.SPOOFED:
			return spoof_snapshot.duplicate(true)
	return {}


func get_entity_views() -> Array[Dictionary]:
	return _entity_views_at(elapsed_time)


func _entity_views_at(view_time: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in active_entities.values():
		var entity := (value as Dictionary).duplicate(true)
		var age := maxf(0.0, view_time - float(entity.get("spawn_time", view_time)))
		var origin: Vector2 = entity.get("position", Vector2.ZERO)
		var velocity: Vector2 = entity.get("velocity", Vector2.ZERO)
		entity["position"] = origin + velocity * age
		result.append(entity)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.id) < String(b.id))
	return result


func _capture_snapshot(at_time: float) -> Dictionary:
	return {"available": true, "time": at_time, "state": current_state, "entities": _entity_views_at(at_time)}


func _apply_event(event: Dictionary) -> void:
	var copy := event.duplicate(true)
	occurred_events.append(copy)
	if player_recording or definition.recording:
		recorded_events.append(copy.duplicate(true))
	match StringName(event.get("type", &"STATE")):
		&"STATE":
			current_state = String(event.get("description", "NO ACTIVITY"))
		&"ENTER":
			var entity_id: StringName = event.get("entity_id", &"UNKNOWN")
			active_entities[entity_id] = {
				"id": entity_id,
				"kind": event.get("kind", &"PERSON"),
				"position": event.get("position", Vector2(0.1, 0.5)),
				"velocity": event.get("velocity", Vector2.ZERO),
				"spawn_time": float(event.get("time", elapsed_time)),
			}
			current_state = String(event.get("description", "%s ENTERED" % entity_id))
		&"LEAVE":
			active_entities.erase(event.get("entity_id", &""))
			current_state = String(event.get("description", "SUBJECT LEFT FRAME"))
	frame_history.append(_capture_snapshot(float(event.get("time", elapsed_time))))
	if frame_history.size() > 32:
		frame_history.pop_front()
	authored_event_occurred.emit(definition.id, copy)
