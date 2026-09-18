class_name MeatspaceInteractionController
extends RefCounted
## Authored physical verbs use the same PersistentGameState as Story Mode.
var state: PersistentGameState
var definition: Dictionary

func configure(source: Dictionary, persistent_state: PersistentGameState) -> void:
	definition = source
	state = persistent_state

func actions_for(object_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state == null: return result
	var data: Dictionary = definition.get("objects", {}).get(String(object_id), {})
	var flags: Dictionary = state.campaign_state.get("story_flags", {})
	var visibility: Dictionary = data.get("visibility", {})
	if not visibility.is_empty() and bool(flags.get(visibility.flag, false)) != bool(visibility.get("equals", true)): return result
	for action: Dictionary in data.get("verbs", []):
		if action.has("when_flag") and bool(flags.get(action.when_flag, false)) != bool(action.get("equals", true)): continue
		result.append(action.duplicate(true))
	return result

func execute(object_id: StringName, verb_id: StringName) -> Dictionary:
	for verb: Dictionary in actions_for(object_id):
		if StringName(verb.id) != verb_id: continue
		for action: Dictionary in verb.get("actions", []): _apply(action)
		state.emit_changed()
		return {"success": true, "text": verb.get("text", "")}
	return {"success": false, "text": "That action is not available now."}

func _apply(action: Dictionary) -> void:
	match String(action.get("type", "")):
		"SET_FLAG":
			var flags: Dictionary = state.campaign_state.get("story_flags", {}).duplicate(true)
			flags[action.id] = action.get("value", true)
			state.campaign_state["story_flags"] = flags
		"REST":
			state.player_state["fatigue"] = maxf(0.0, float(state.player_state.get("fatigue", 0.0)) - float(action.get("amount", 50.0)))
		"ADVANCE_TIME":
			var times := ["DAWN", "DAY", "DUSK", "NIGHT"]
			var current := times.find(String(state.world_state.get("time_of_day", "NIGHT")))
			state.world_state["time_of_day"] = times[posmod(current + int(action.get("steps", 1)), 4)]
		"TAKE_CONTENTS":
			var inventory: Array = state.player_state.get("inventory", []).duplicate(true)
			var source: Dictionary = definition.get("objects", {}).get(String(action.id), {})
			for item: Dictionary in source.get("contents", []):
				if not inventory.any(func(entry: Variant) -> bool: return entry is Dictionary and entry.get("id") == item.id): inventory.append(item.duplicate(true))
			state.player_state["inventory"] = inventory

func set_time_of_day(value: String) -> void:
	if state == null or value not in ["DAY", "DUSK", "NIGHT", "DAWN"]: return
	state.world_state["time_of_day"] = value
	state.emit_changed()

func primary(object_id: StringName) -> Dictionary:
	for action: Dictionary in actions_for(object_id):
		if String(action.id) != "EXAMINE": return execute(object_id, StringName(action.id))
	return {"success": true, "text": ""}
