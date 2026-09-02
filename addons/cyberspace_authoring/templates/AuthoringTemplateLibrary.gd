@tool
extends RefCounted

const NAMES := [&"ABANDONED_SERVER", &"CORPORATE_SECURITY_NODE", &"PBX_SERVER", &"CAMERA_NETWORK", &"ACCESS_CONTROL_SYSTEM", &"ALARM_SYSTEM", &"PHYSICAL_SECURITY_TEAM", &"PLAYER_PENETRATION_TEAM", &"ACTIVE_COMMS_CALL", &"HIDDEN_STORY_CALL", &"VIDEO_CLUE", &"MEATSPACE_OPERATION", &"NULL_ANOMALY", &"DEAD_ACCOUNT", &"HIDDEN_ROUTE_CLUE", &"BOSS_FORESHADOWING", &"PROGRAM_DEFINITION", &"DOORSTOP_DEFINITION", &"PROGRAM_REWARD", &"GUIDED_SEQUENCE"]


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
	elif template_id in [&"PROGRAM_DEFINITION", &"DOORSTOP_DEFINITION"]:
		var is_doorstop := template_id == &"DOORSTOP_DEFINITION"
		document.add_entry(&"program_definitions", {"id": id, "display_name": "Doorstop" if is_doorstop else "New Program", "program_type": &"DOORSTOP" if is_doorstop else &"GENERIC", "version": "1.0", "description": "Disposable backdoor utility." if is_doorstop else "", "rarity": &"COMMON", "programming_recipe": {}, "programming_requirements": {}, "programming_duration": 5.0 if is_doorstop else 0.0, "required_programming_capability": &"", "required_programming_tool": &"", "programming_prerequisites": [], "allowed_node_types": [], "prohibited_encounter_tags": [], "burn_on_deploy": true, "one_active_anchor_per_intrusion": true, "suspension_policy": {"preserve_trace": true, "trace_increase_per_second": 0.0, "alarms_remain_active": true, "ice_may_reposition": false, "security_may_escalate": false, "temporary_effects_may_expire": true}, "return_to_exact_node": true, "destroy_anchor_on_return": true, "trace_modifiers": {}, "security_modifiers": {}, "tags": [&"DOORSTOP"] if is_doorstop else [], "author_notes": ""}); created.append(id)
	elif template_id == &"PROGRAM_REWARD":
		document.add_entry(&"rewards", {"id": id, "display_name": "Program Reward", "reward_type": &"PROGRAM", "program_definition_id": &"", "quantity": 1, "probability": 1.0, "repeatable": false, "prerequisite_flags": [], "source_type": &"NETWORK_NODE", "source_id": &"", "discovery_text": "Software cache discovered.", "pickup_text": "Program acquired.", "optional": true, "tags": [], "author_notes": ""}); created.append(id)
	elif template_id == &"GUIDED_SEQUENCE":
		document.add_entry(&"story_sequences", {"id": id, "display_name": "New Guided Sequence", "sequence_type": &"MISSION", "event_nodes": [], "entry_node_id": &"", "tags": [], "author_notes": ""}); created.append(id)
	else:
		document.add_entry(&"story_hooks", {"id": id, "title": String(template_id).replace("_", " ").capitalize(), "internal_name": id, "summary": "Created from template.", "trigger_conditions": [], "activation_actions": [], "completion_conditions": [], "failure_conditions": [], "priority": 0, "repeat_policy": &"ONCE", "followup_hook_ids": [], "tags": [template_id], "author_notes": ""}); created.append(id)
	return created


func _unique(document: CyberspaceContentDocument, base: StringName) -> StringName:
	var id := base; var serial := 2
	while not document.find_entry(id).is_empty(): id = StringName("%s_%02d" % [base, serial]); serial += 1
	return id
