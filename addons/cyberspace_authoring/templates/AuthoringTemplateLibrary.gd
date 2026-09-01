@tool
extends RefCounted

const NAMES := [&"ABANDONED_SERVER", &"CORPORATE_SECURITY_NODE", &"PBX_SERVER", &"CAMERA_NETWORK", &"ACCESS_CONTROL_SYSTEM", &"ALARM_SYSTEM", &"PHYSICAL_SECURITY_TEAM", &"PLAYER_PENETRATION_TEAM", &"ACTIVE_COMMS_CALL", &"HIDDEN_STORY_CALL", &"VIDEO_CLUE", &"MEATSPACE_OPERATION", &"NULL_ANOMALY", &"DEAD_ACCOUNT", &"HIDDEN_ROUTE_CLUE", &"BOSS_FORESHADOWING"]


func apply(document: CyberspaceContentDocument, template_id: StringName) -> Array[StringName]:
	if document == null or template_id not in NAMES: return []
	var created: Array[StringName] = []; var id := _unique(document, template_id)
	if template_id in [&"ABANDONED_SERVER", &"CORPORATE_SECURITY_NODE", &"PBX_SERVER", &"CAMERA_NETWORK", &"ACCESS_CONTROL_SYSTEM", &"ALARM_SYSTEM", &"NULL_ANOMALY", &"DEAD_ACCOUNT"]:
		var type := &"SERVER"
		if template_id == &"PBX_SERVER": type = &"PBX"
		elif template_id == &"CAMERA_NETWORK": type = &"CAMERA_SERVER"
		elif template_id == &"ACCESS_CONTROL_SYSTEM": type = &"ACCESS_CONTROL"
		elif template_id == &"ALARM_SYSTEM": type = &"ALARM_CONTROLLER"
		document.add_entry(&"network_nodes", {"id": id, "display_name": String(template_id).replace("_", " ").capitalize(), "node_type": type, "owner": &"", "faction": &"", "security_level": 2, "description": "Created from ordinary authoring template.", "tags": [template_id], "region_id": &"", "services": [], "starting_discovery_state": &"UNKNOWN", "graffiti": [], "flavor_text": [], "story_hooks": [], "author_notes": ""}); created.append(id)
	elif template_id in [&"PHYSICAL_SECURITY_TEAM", &"PLAYER_PENETRATION_TEAM"]:
		document.add_entry(&"physical_teams", {"id": id, "display_name": String(template_id).replace("_", " ").capitalize(), "team_type": &"SECURITY" if template_id == &"PHYSICAL_SECURITY_TEAM" else &"PLAYER_CONTRACTED", "members": [], "equipment": [], "default_comms_channel": &"", "tags": [template_id], "author_notes": ""}); created.append(id)
	elif template_id in [&"ACTIVE_COMMS_CALL", &"HIDDEN_STORY_CALL"]:
		document.add_entry(&"comms_sessions", {"id": id, "display_name": "Authored Realtime Call", "channel_id": &"", "participants": [], "start_conditions": [], "duration": 60.0, "encryption_level": 0, "timeline": [], "story_tags": [template_id], "author_notes": ""}); created.append(id)
	elif template_id == &"VIDEO_CLUE":
		document.add_entry(&"video_feeds", {"id": id, "display_name": "Video Clue", "physical_location_id": &"", "network_endpoint_id": &"", "initial_state": &"LIVE", "can_monitor": true, "can_record": true, "can_loop": true, "timeline": [], "story_tags": [template_id], "author_notes": ""}); created.append(id)
	else:
		document.add_entry(&"story_hooks", {"id": id, "title": String(template_id).replace("_", " ").capitalize(), "internal_name": id, "summary": "Created from template.", "trigger_conditions": [], "activation_actions": [], "completion_conditions": [], "failure_conditions": [], "priority": 0, "repeat_policy": &"ONCE", "followup_hook_ids": [], "tags": [template_id], "author_notes": ""}); created.append(id)
	return created


func _unique(document: CyberspaceContentDocument, base: StringName) -> StringName:
	var id := base; var serial := 2
	while not document.find_entry(id).is_empty(): id = StringName("%s_%02d" % [base, serial]); serial += 1
	return id
