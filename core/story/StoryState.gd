class_name StoryState
extends RefCounted
## Typed access to authored campaign state stored by PersistentGameState.

const MISSION_LOCKED := &"locked"
const MISSION_UNLOCKED := &"unlocked"
const MISSION_ACTIVE := &"active"
const MISSION_COMPLETED := &"completed"
const MISSION_FAILED := &"failed"

var game_state: PersistentGameState

func _init(state: PersistentGameState = null) -> void:
	game_state = state
	if game_state != null: ensure_defaults(game_state)

static func ensure_defaults(state: PersistentGameState) -> void:
	var story_time := StringName(state.world_state.get("time_of_day", &"NIGHT"))
	if story_time not in [&"DAWN", &"DAY", &"DUSK", &"NIGHT"]:
		story_time = &"NIGHT"
	state.world_state["time_of_day"] = story_time
	var campaign := state.campaign_state
	for entry: Dictionary in [
		{"key": "story_flags", "value": {}}, {"key": "story_values", "value": {}},
		{"key": "story_states", "value": {}}, {"key": "contacts", "value": {}},
		{"key": "mission_states", "value": {}}, {"key": "story_event_state", "value": {}},
		{"key": "objectives", "value": {}}, {"key": "room_object_states", "value": {}},
	]:
		if not campaign.get(entry.key) is Dictionary: campaign[entry.key] = entry.value
	state.campaign_state = campaign

func get_flag(id: StringName, default := false) -> bool: return bool(_bucket("story_flags").get(id, default))
func set_flag(id: StringName, value: bool) -> void: _set_entry("story_flags", id, value)

func get_value(id: StringName, default: Variant = 0) -> Variant:
	var value: Variant = _bucket("story_values").get(id, default)
	return value if value is int or value is float else default
func set_value(id: StringName, value: Variant) -> bool:
	if not (value is int or value is float): return false
	_set_entry("story_values", id, value); return true
func increment_value(id: StringName, amount: Variant) -> bool:
	if not (amount is int or amount is float): return false
	return set_value(id, get_value(id, 0) + amount)

func get_state(id: StringName, default: StringName = &"") -> StringName: return StringName(_bucket("story_states").get(id, default))
func set_state(id: StringName, value: StringName) -> void: _set_entry("story_states", id, value)

func is_contact_unlocked(id: StringName) -> bool: return bool(_contact(id).get("unlocked", false))
func unlock_contact(id: StringName) -> void:
	var contact := _contact(id); contact["unlocked"] = true; _set_entry("contacts", id, contact)
func get_reputation(id: StringName) -> float: return float(_contact(id).get("reputation", 0.0))
func change_reputation(id: StringName, amount: float) -> void:
	var contact := _contact(id); contact["reputation"] = clampf(float(contact.get("reputation", 0.0)) + amount, -10.0, 10.0); _set_entry("contacts", id, contact)
func get_contact_state(id: StringName) -> Dictionary: return _contact(id)
func update_contact_state(id: StringName, changes: Dictionary) -> void:
	var contact := _contact(id); contact.merge(changes, true); _set_entry("contacts", id, contact)

func get_mission_status(id: StringName) -> StringName:
	if _bucket("mission_states").has(id): return StringName(_bucket("mission_states")[id])
	if StringName(game_state.campaign_state.get("active_mission_id", &"")) == id: return MISSION_ACTIVE
	if id in game_state.campaign_state.get("completed_mission_ids", []): return MISSION_COMPLETED
	if id in game_state.campaign_state.get("unlocked_mission_ids", []): return MISSION_UNLOCKED
	return MISSION_LOCKED
func set_mission_status(id: StringName, status: StringName) -> void:
	_set_entry("mission_states", id, status)
	var unlocked: Array = game_state.campaign_state.get("unlocked_mission_ids", [])
	var completed: Array = game_state.campaign_state.get("completed_mission_ids", [])
	if status != MISSION_LOCKED and id not in unlocked: unlocked.append(id)
	if status == MISSION_COMPLETED and id not in completed: completed.append(id)
	if status == MISSION_ACTIVE: game_state.campaign_state["active_mission_id"] = id
	elif StringName(game_state.campaign_state.get("active_mission_id", &"")) == id: game_state.campaign_state["active_mission_id"] = &""
	game_state.campaign_state["unlocked_mission_ids"] = unlocked
	game_state.campaign_state["completed_mission_ids"] = completed
func set_room_object_state(id: StringName, value: Variant) -> void: _set_entry("room_object_states", id, value)

func has_completed_event(id: StringName) -> bool: return get_event_count(id) > 0
func get_event_count(id: StringName) -> int: return int(_event_record(id).get("count", 0))
func mark_event_completed(id: StringName, trigger_serial := 0) -> void:
	var record := _event_record(id)
	record["count"] = int(record.get("count", 0)) + 1
	record["last_trigger_serial"] = trigger_serial
	_set_entry("story_event_state", id, record)

func get_path(scope: StringName, id: StringName, context: Dictionary = {}) -> Variant:
	match scope:
		&"story", &"value": return get_value(id, null)
		&"flag": return get_flag(id)
		&"state": return get_state(id)
		&"contact_unlocked": return is_contact_unlocked(id)
		&"contact_reputation": return get_reputation(id)
		&"mission": return get_mission_status(id)
		&"player": return game_state.player_state.get(id)
		&"trigger": return context.get(id)
		&"game": return game_state.is_story_mode() if id == &"story_mode" else null
	return null

func _bucket(key: String) -> Dictionary: return game_state.campaign_state.get_or_add(key, {})
func _set_entry(bucket: String, id: StringName, value: Variant) -> void:
	_bucket(bucket)[id] = value
	game_state.emit_changed()
func _contact(id: StringName) -> Dictionary: return (_bucket("contacts").get(id, {}) as Dictionary).duplicate(true)
func _event_record(id: StringName) -> Dictionary: return (_bucket("story_event_state").get(id, {}) as Dictionary).duplicate(true)
