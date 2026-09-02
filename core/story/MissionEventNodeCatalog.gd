class_name MissionEventNodeCatalog
extends RefCounted

const NODE_TYPES: Array[StringName] = [&"SPAWN_ACTOR", &"DESPAWN_ACTOR", &"MOVE_ACTOR", &"DIALOGUE", &"OBJECTIVE_START", &"OBJECTIVE_COMPLETE", &"WAIT_FOR", &"HIGHLIGHT", &"SPAWN_REWARD", &"SPAWN_ICE", &"MODIFY_TRACE", &"TRIGGER_REALTIME_EVENT", &"BRANCH", &"HINT", &"SET_FLAG"]
const GAMEPLAY_EVENTS: Array[StringName] = [&"PLAYER_INSPECTED_CURRENT_NODE", &"NODE_SCANNED", &"NODE_ENTERED", &"SERVICE_COMPROMISED", &"OBJECTIVE_COMPLETED", &"DOORSTOP_DEPLOYED", &"INTRUSION_SUSPENDED_AT_DOORSTOP", &"INTRUSION_RESUMED_FROM_DOORSTOP", &"ICE_DETECTED_PLAYER", &"TRACE_UPDATED", &"COMMS_INTERCEPTED", &"REALTIME_EVENT_OCCURRED"]

static func create(node_type: StringName, id: StringName) -> Dictionary:
	var node := {"id": id, "type": node_type, "enabled": true, "optional": false, "conditions": [], "next_id": &"", "author_notes": ""}
	match node_type:
		&"SPAWN_ACTOR", &"DESPAWN_ACTOR": node.merge({"actor_id": &"", "node_id": &""}, true)
		&"MOVE_ACTOR": node.merge({"actor_id": &"", "node_id": &"", "movement_mode": &"SCRIPTED"}, true)
		&"DIALOGUE": node.merge({"actor_id": &"", "text": "", "channel_id": &"", "realtime": true}, true)
		&"OBJECTIVE_START", &"OBJECTIVE_COMPLETE": node.merge({"objective_id": &""}, true)
		&"WAIT_FOR": node.merge({"event_type": &"NODE_ENTERED", "target_id": &"", "event_conditions": {}}, true)
		&"HIGHLIGHT": node.merge({"target_type": &"NODE", "target_id": &"", "style": &"TUTORIAL_FOCUS"}, true)
		&"SPAWN_REWARD": node.merge({"reward_id": &"", "quantity": 1, "destination": &"CURRENT_NODE"}, true)
		&"SPAWN_ICE": node.merge({"ice_definition_id": &"", "instance_id": &"", "node_id": &""}, true)
		&"MODIFY_TRACE": node.merge({"operation": &"ADD", "amount": 1}, true)
		&"TRIGGER_REALTIME_EVENT": node.merge({"realtime_event_id": &""}, true)
		&"BRANCH": node.merge({"branches": []}, true)
		&"HINT": node.merge({"actor_id": &"", "hint_group_id": &"", "text": "", "escalation_index": 0, "once": true}, true)
		&"SET_FLAG": node.merge({"flag_id": &"", "value": true}, true)
	return node

static func describe(node: Dictionary) -> String:
	var type: StringName = node.get("type", &"UNKNOWN")
	var detail := String(node.get("text", node.get("event_type", node.get("target_id", node.get("node_id", node.get("objective_id", ""))))))
	return "%s  //  %s" % [type, detail.left(54)]

static func legacy_beat_view(beat: Dictionary) -> Dictionary:
	return {"id": beat.get("id", &"LEGACY_BEAT"), "type": &"LEGACY_BEAT", "text": "Existing beat: %s" % beat.get("objective", {}).get("title", "event/dialogue beat"), "legacy_data": beat, "enabled": true, "optional": bool(beat.get("objective", {}).get("optional", false))}

static func convert_legacy_beats(beats: Array, speaker_actor_id: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for beat_value: Variant in beats:
		if not beat_value is Dictionary: continue
		var beat: Dictionary = beat_value
		var prefix := String(beat.get("id", "BEAT"))
		var trigger: Dictionary = beat.get("trigger", {})
		if trigger.has("event_type"):
			var wait := create(&"WAIT_FOR", StringName("%s_WAIT" % prefix)); wait.event_type = trigger.event_type; wait.target_id = trigger.get("target_id", &""); wait.event_conditions = trigger.duplicate(true); wait.source_beat = beat.duplicate(true); result.append(wait)
		for index in beat.get("dialogue", []).size():
			var line: Dictionary = beat.dialogue[index]; var dialogue := create(&"DIALOGUE", StringName("%s_DIALOGUE_%02d" % [prefix, index + 1])); dialogue.actor_id = speaker_actor_id if not speaker_actor_id.is_empty() else line.get("speaker_id", &""); dialogue.speaker_id = line.get("speaker_id", &""); dialogue.text = line.get("text", ""); dialogue.delay_seconds = line.get("time", 0.0); result.append(dialogue)
		var objective: Dictionary = beat.get("objective", {})
		if not objective.is_empty():
			var start := create(&"OBJECTIVE_START", StringName("%s_OBJECTIVE" % prefix)); start.objective_id = objective.get("id", &""); start.objective_data = objective.duplicate(true); start.optional = bool(objective.get("optional", false)); result.append(start)
		var completion: Dictionary = beat.get("completion", {})
		if completion.has("event_type"):
			var finish := create(&"WAIT_FOR", StringName("%s_COMPLETE" % prefix)); finish.event_type = completion.event_type; finish.target_id = completion.get("target_id", &""); finish.event_conditions = completion.duplicate(true); result.append(finish)
	return result
