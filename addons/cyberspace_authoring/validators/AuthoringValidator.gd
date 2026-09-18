@tool
extends RefCounted

const MissionCatalog := preload("res://core/story/MissionEventNodeCatalog.gd")


func validate(document: CyberspaceContentDocument) -> Array[Dictionary]:
	if document == null: return [_issue("ERROR", "GENERAL", &"", "No authoring document is open.")]
	var issues: Array[Dictionary] = []; var ids: Dictionary = {}
	_validate_availability(issues, document.document_id, StringName(document.availability), document.mode_variants)
	for entry: Dictionary in document.all_entries():
		var id: StringName = entry.get("id", &"")
		if id == &"": issues.append(_issue("ERROR", "GENERAL", &"", "Entry has no ID."))
		elif ids.has(id): issues.append(_issue("ERROR", "GENERAL", id, "Duplicate ID '%s'." % id))
		else: ids[id] = entry.get("_collection", &"")
		_validate_availability(issues, id, StringName(entry.get("availability", document.availability)), entry.get("mode_variants", {}))
	var node_ids := _ids(document.network_nodes); var service_ids := _ids(document.services); var location_ids := _ids(document.meatspace_locations); var endpoint_ids := _ids(document.realtime_endpoints)
	var program_ids := _ids(document.program_definitions)
	var comms_channel_ids := _ids(document.comms_channels)
	var ice_definition_ids := _ids(document.ice_definitions)
	var sphere_ids := _ids(document.spheres)
	var sleeve_ids := _ids(document.security_sleeves)
	var legacy_sphere_claims := {}
	for node: Dictionary in document.network_nodes:
		var sphere_id: StringName = node.get("sphere_id", &"")
		if sphere_id == &"": issues.append(_issue("WARNING", "SPHERES", node.id, "Network node has no persistent Sphere membership."))
		elif sphere_id not in sphere_ids: issues.append(_issue("ERROR", "SPHERES", node.id, "Network node references missing Sphere '%s'." % sphere_id))
	for sphere: Dictionary in document.spheres:
		if not _valid_sphere_id(StringName(sphere.get("id", &""))): issues.append(_issue("ERROR", "SPHERES", sphere.get("id", &""), "Sphere ID must begin with A-Z and contain only A-Z, 0-9, or underscore."))
		if sphere.get("original_security_sleeve_id", &"") != &"" and sphere.get("original_security_sleeve_id") not in sleeve_ids: issues.append(_issue("ERROR", "SPHERES", sphere.id, "Sphere references a missing original Security Sleeve."))
		for member_id in sphere.get("node_ids", []):
			if legacy_sphere_claims.has(member_id) and legacy_sphere_claims[member_id] != sphere.id: issues.append(_issue("ERROR", "SPHERES", member_id, "Node is listed in multiple legacy Sphere member lists. Use node sphere_id as the canonical assignment."))
			else: legacy_sphere_claims[member_id] = sphere.id
			if member_id not in node_ids: issues.append(_issue("ERROR", "SPHERES", sphere.id, "Sphere member node '%s' is missing." % member_id))
			else:
				var member := document.network_nodes.filter(func(node): return node.get("id", &"") == member_id)[0] as Dictionary
				if member.get("sphere_id", &"") != sphere.id: issues.append(_issue("ERROR", "SPHERES", member_id, "Node and Sphere membership disagree."))
	for sleeve: Dictionary in document.security_sleeves:
		if sleeve.get("state", &"INTACT") not in [&"INTACT", &"BREACHED", &"SPLIT", &"BYPASSED", &"DISABLED"]: issues.append(_issue("ERROR", "SECURITY SLEEVES", sleeve.id, "Security Sleeve state is invalid."))
		for member_id in sleeve.get("current_members", []):
			if member_id not in node_ids: issues.append(_issue("ERROR", "SECURITY SLEEVES", sleeve.id, "Current sleeve member '%s' is missing." % member_id))
	for link: Dictionary in document.network_links:
		if link.get("source", &"") not in node_ids: issues.append(_issue("ERROR", "NETWORK", link.id, "Link source does not exist."))
		if link.get("destination", &"") not in node_ids: issues.append(_issue("ERROR", "NETWORK", link.id, "Link destination does not exist."))
		if int(link.get("traversal_cost", 0)) < 0: issues.append(_issue("ERROR", "NETWORK", link.id, "Traversal cost cannot be negative."))
		var gate := StringName(link.get("traversal_gate", link.get("gate", &"NONE"))).to_upper()
		if gate not in [&"NONE", &"BLOCK_EXIT_UNTIL_RESOLVED", &"BLOCK_ENTRY_UNTIL_REQUIREMENT", &"ONE_WAY", &"SCRIPTED"]: issues.append(_issue("ERROR", "NETWORK GATES", link.id, "Unknown traversal gate type '%s'." % gate))
		elif gate not in [&"NONE", &"ONE_WAY"] and (link.get("traversal_requirement", link.get("requirement", {})) as Dictionary).is_empty(): issues.append(_issue("ERROR", "NETWORK GATES", link.id, "Traversal gate requires an authored requirement."))
		var source := document.find_entry(link.get("source", &"")); var destination := document.find_entry(link.get("destination", &""))
		if not source.is_empty() and not destination.is_empty():
			var source_sphere: StringName = source.get("sphere_id", &""); var destination_sphere: StringName = destination.get("sphere_id", &"")
			if source_sphere != &"" and destination_sphere != &"" and source_sphere != destination_sphere:
				issues.append(_issue("INFO", "CROSS-SPHERE CONNECTIONS", link.id, "%s connects Sphere %s to %s." % [link.id, source_sphere, destination_sphere]))
	for node_id in node_ids:
		if node_id != &"PUBLIC_GATEWAY" and not _node_has_link(node_id, document.network_links): issues.append(_issue("WARNING", "NETWORK", node_id, "Network node is unreachable/orphaned."))
	for endpoint: Dictionary in document.realtime_endpoints:
		if endpoint.get("network_node_id", &"") not in node_ids: issues.append(_issue("ERROR", "MEATSPACE ENDPOINTS", endpoint.id, "Endpoint network node is missing."))
		if endpoint.get("service_id", &"") != &"" and endpoint.get("service_id") not in service_ids: issues.append(_issue("ERROR", "MEATSPACE ENDPOINTS", endpoint.id, "Endpoint service reference is missing."))
		if endpoint.get("physical_location_id", &"") != &"" and endpoint.get("physical_location_id") not in location_ids: issues.append(_issue("ERROR", "MEATSPACE ENDPOINTS", endpoint.id, "Endpoint physical location is missing."))
	for item: Dictionary in document.graffiti:
		if String(item.get("text", "")).is_empty() and item.get("symbol_id", &"") == &"": issues.append(_issue("ERROR", "GRAFFITI / FLAVOR", item.id, "Graffiti has no text or symbol."))
		if item.get("target_id", &"") != &"" and not ids.has(item.target_id): issues.append(_issue("ERROR", "GRAFFITI / FLAVOR", item.id, "Graffiti target is missing."))
	for item: Dictionary in document.flavor_text:
		if String(item.get("text", "")).is_empty(): issues.append(_issue("ERROR", "GRAFFITI / FLAVOR", item.id, "Flavor text is empty."))
	for session: Dictionary in document.comms_sessions:
		if session.get("channel_id", &"") not in _ids(document.comms_channels): issues.append(_issue("ERROR", "COMMS", session.id, "Comms channel is missing."))
		if float(session.get("duration", -1.0)) == 0.0: issues.append(_issue("ERROR", "COMMS", session.id, "Comms duration cannot be zero."))
		_validate_timeline(issues, "COMMS", session)
	for hacker: Dictionary in document.hacker_npcs:
		if hacker.get("initial_node_id", &"") != &"" and hacker.get("initial_node_id") not in node_ids: issues.append(_issue("ERROR", "HACKER NPCS", hacker.id, "Initial network node is missing."))
		if hacker.get("comms_channel_id", &"") != &"" and hacker.get("comms_channel_id") not in comms_channel_ids: issues.append(_issue("ERROR", "HACKER NPCS", hacker.id, "Comms channel is missing."))
	for reaction: Dictionary in document.hacker_reactions:
		if reaction.get("actor_id", &"") not in _ids(document.hacker_npcs): issues.append(_issue("ERROR", "HACKER NPCS", reaction.id, "Contextual reaction actor is missing."))
		if reaction.get("lines", []).is_empty(): issues.append(_issue("WARNING", "HACKER NPCS", reaction.id, "Contextual reaction has no dialogue."))
	for rule: Dictionary in document.tutorial_guidance_rules:
		if rule.get("actor_id", &"") not in _ids(document.hacker_npcs): issues.append(_issue("ERROR", "TUTORIAL", rule.id, "Tutorial guidance actor is missing."))
		if rule.get("hints", []).is_empty(): issues.append(_issue("WARNING", "TUTORIAL", rule.id, "Tutorial guidance rule has no hints."))
		if bool(rule.get("hard_fail", false)) and bool(rule.get("recoverable", true)): issues.append(_issue("ERROR", "TUTORIAL", rule.id, "A recovery rule cannot also hard-fail."))
	for ice: Dictionary in document.ice_instances:
		if ice.get("definition_id", &"") not in ice_definition_ids: issues.append(_issue("ERROR", "ICE", ice.id, "ICE definition is missing."))
		if ice.get("initial_node_id", &"") not in node_ids: issues.append(_issue("ERROR", "ICE", ice.id, "ICE initial node is missing."))
	for sequence: Dictionary in document.story_sequences:
		for beat: Dictionary in sequence.get("beats", []):
			var trigger: Dictionary = beat.get("trigger", {})
			if trigger.get("target_type", &"") == &"NODE" and trigger.get("target_id", &"") not in node_ids: issues.append(_issue("ERROR", "STORY SEQUENCES", sequence.id, "Beat trigger references a missing network node."))
			for command: Dictionary in beat.get("commands", []):
				if command.get("actor_id", &"") != &"" and command.get("actor_id") not in _ids(document.hacker_npcs): issues.append(_issue("ERROR", "STORY SEQUENCES", sequence.id, "Beat command references a missing hacker actor."))
				if command.get("node_id", &"") != &"" and command.get("node_id") not in node_ids: issues.append(_issue("ERROR", "STORY SEQUENCES", sequence.id, "Beat command references a missing network node."))
		_validate_mission_event_nodes(issues, document, sequence, node_ids, ice_definition_ids)
	for video: Dictionary in document.video_feeds:
		if video.get("physical_location_id", &"") not in location_ids: issues.append(_issue("ERROR", "VIDEO", video.id, "Video physical location is missing."))
		if video.get("network_endpoint_id", &"") not in endpoint_ids: issues.append(_issue("ERROR", "VIDEO", video.id, "Video endpoint is missing."))
		_validate_timeline(issues, "VIDEO", video)
	for alarm: Dictionary in document.alarms:
		if alarm.get("network_endpoint_id", &"") not in endpoint_ids: issues.append(_issue("ERROR", "ALARMS", alarm.id, "Alarm endpoint is missing."))
	for team: Dictionary in document.physical_teams:
		if team.get("default_comms_channel", &"") != &"" and team.get("default_comms_channel") not in _ids(document.comms_channels): issues.append(_issue("WARNING", "TEAMS", team.id, "Team comms source is missing."))
	for operation: Dictionary in document.team_operations:
		for segment: Dictionary in operation.get("route", []):
			if segment.get("from", &"") not in location_ids or segment.get("to", &"") not in location_ids: issues.append(_issue("ERROR", "TEAMS", operation.id, "Physical route references a missing location."))
			if float(segment.get("travel_duration_seconds", 0.0)) <= 0.0: issues.append(_issue("ERROR", "TEAMS", operation.id, "Travel duration must be positive."))
	for hook: Dictionary in document.story_hooks:
		for followup in hook.get("followup_hook_ids", []):
			if followup not in _ids(document.story_hooks): issues.append(_issue("ERROR", "STORY", hook.id, "Follow-up hook '%s' is missing." % followup))
		if hook.get("activation_actions", []).is_empty() and hook.get("completion_conditions", []).is_empty(): issues.append(_issue("WARNING", "STORY", hook.id, "Hook cannot resolve or produce an action."))
	for event: Dictionary in document.realtime_events:
		if float(event.get("delay_seconds", 0.0)) < 0.0: issues.append(_issue("ERROR", "REALTIME EVENTS", event.id, "Realtime delay cannot be negative."))
		if event.get("actions", []).is_empty(): issues.append(_issue("WARNING", "REALTIME EVENTS", event.id, "Realtime event has no actions."))
	for program: Dictionary in document.program_definitions:
		if String(program.get("version", "")).is_empty(): issues.append(_issue("ERROR", "PROGRAM REWARDS", program.id, "Program definition has no version."))
		if float(program.get("programming_duration", 0.0)) < 0.0: issues.append(_issue("ERROR", "PROGRAM REWARDS", program.id, "Programming duration cannot be negative."))
		if program.get("program_type", &"") == &"DOORSTOP": _validate_doorstop(issues, program)
	for reward: Dictionary in document.rewards:
		if reward.get("reward_type", &"PROGRAM") == &"PROGRAM" and reward.get("program_definition_id", &"") not in program_ids:
			issues.append(_issue("ERROR", "PROGRAM REWARDS", reward.id, "Reward references missing program ID '%s'." % reward.get("program_definition_id", &"")))
		if int(reward.get("quantity", 0)) < 1: issues.append(_issue("ERROR", "PROGRAM REWARDS", reward.id, "Reward quantity must be at least one."))
		var chance := float(reward.get("probability", 1.0))
		if chance < 0.0 or chance > 1.0: issues.append(_issue("ERROR", "PROGRAM REWARDS", reward.id, "Reward probability must be between 0 and 1."))
		var source_type: StringName = reward.get("source_type", &"")
		if source_type not in [&"NETWORK_NODE", &"HIDDEN_CACHE", &"SUCCESSFUL_HACK", &"STORY_EVENT", &"MEATSPACE_INTERACTION", &"OPTIONAL_OBJECTIVE"]:
			issues.append(_issue("ERROR", "PROGRAM REWARDS", reward.id, "Reward source type is invalid."))
		var source_id: StringName = reward.get("source_id", &"")
		if not _valid_reward_source(document, source_type, source_id): issues.append(_issue("ERROR", "PROGRAM REWARDS", reward.id, "Reward source reference is missing or incompatible with its source type."))
	_validate_story_mode_authoring(issues, document)
	if issues.is_empty(): issues.append(_issue("INFO", "GENERAL", document.document_id, "VALIDATE ALL passed with no issues."))
	return issues


func validate_shell() -> Array[Dictionary]: return [_issue("INFO", "GENERAL", &"", "Authoring plugin shell loaded.")]
func _validate_availability(issues: Array[Dictionary], id: StringName, availability: StringName, variants: Dictionary) -> void:
	if availability not in [&"AVAILABLE_IN_ALL_MODES", &"STORY_ONLY", &"FREE_ROAM_ONLY", &"MODE_SPECIFIC_VARIANT"]:
		issues.append(_issue("ERROR", "CONTENT AVAILABILITY", id, "Unknown game-mode availability '%s'." % availability))
	elif availability == &"MODE_SPECIFIC_VARIANT":
		for required_mode in [&"STORY", &"FREE_ROAM"]:
			if not variants.has(required_mode) and not variants.has(String(required_mode)):
				issues.append(_issue("WARNING", "CONTENT AVAILABILITY", id, "Mode-specific content has no %s variant." % required_mode))
func _valid_sphere_id(value: StringName) -> bool:
	var text := String(value)
	if text.is_empty() or not text[0] in "ABCDEFGHIJKLMNOPQRSTUVWXYZ": return false
	for character in text:
		if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_": return false
	return true
func _ids(entries: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in entries: result.append(entry.get("id", &""))
	return result
func _node_has_link(id: StringName, links: Array[Dictionary]) -> bool:
	for link in links:
		if link.get("source") == id or link.get("destination") == id: return true
	return false
func _valid_reward_source(document: CyberspaceContentDocument, source_type: StringName, source_id: StringName) -> bool:
	if source_id == &"": return false
	match source_type:
		&"NETWORK_NODE": return source_id in _ids(document.network_nodes)
		&"HIDDEN_CACHE": return source_id in _ids(document.hidden_caches)
		&"SUCCESSFUL_HACK": return source_id in _ids(document.services) or source_id in _ids(document.network_nodes)
		&"STORY_EVENT": return source_id in _ids(document.story_hooks) or source_id in _ids(document.realtime_events)
		&"MEATSPACE_INTERACTION": return source_id in _ids(document.meatspace_interactions)
		&"OPTIONAL_OBJECTIVE": return source_id in _ids(document.objectives)
	return false
func _validate_doorstop(issues: Array[Dictionary], program: Dictionary) -> void:
	if float(program.get("programming_duration", 0.0)) <= 0.0: issues.append(_issue("ERROR", "DOORSTOP", program.id, "Doorstop programming duration must be positive realtime seconds."))
	for resource_id in program.get("programming_recipe", {}):
		if StringName(resource_id) == &"" or int(program.programming_recipe[resource_id]) <= 0: issues.append(_issue("ERROR", "DOORSTOP", program.id, "Doorstop resource costs require an ID and positive amount."))
	if not bool(program.get("burn_on_deploy", true)): issues.append(_issue("ERROR", "DOORSTOP", program.id, "Doorstop must burn its activated instance on deployment."))
	if not bool(program.get("one_active_anchor_per_intrusion", true)): issues.append(_issue("ERROR", "DOORSTOP", program.id, "Current runtime requires one active Doorstop anchor per intrusion."))
	if not bool(program.get("return_to_exact_node", true)): issues.append(_issue("ERROR", "DOORSTOP", program.id, "Doorstop must return to its exact deployment node."))
	if not bool(program.get("destroy_anchor_on_return", true)): issues.append(_issue("ERROR", "DOORSTOP", program.id, "Doorstop return must destroy the one-shot anchor."))
	var policy: Dictionary = program.get("suspension_policy", {})
	for key in ["preserve_trace", "alarms_remain_active", "ice_may_reposition", "security_may_escalate", "temporary_effects_may_expire"]:
		if not policy.has(key): issues.append(_issue("WARNING", "DOORSTOP", program.id, "Suspension policy does not explicitly define '%s'." % key))
func _validate_timeline(issues: Array[Dictionary], category: String, entry: Dictionary) -> void:
	var previous := -1.0
	for event: Dictionary in entry.get("timeline", []):
		var time := float(event.get("time", -1.0))
		if time < 0.0 or time < previous: issues.append(_issue("ERROR", category, entry.id, "Timeline is negative or not ordered.")); return
		previous = time

func _validate_mission_event_nodes(issues: Array[Dictionary], document: CyberspaceContentDocument, sequence: Dictionary, node_ids: Array[StringName], ice_definition_ids: Array[StringName]) -> void:
	var ids: Dictionary = {}
	var allowed := MissionCatalog.NODE_TYPES
	for node: Dictionary in sequence.get("event_nodes", []):
		var id: StringName = node.get("id", &""); var type: StringName = node.get("type", &"")
		if id.is_empty(): issues.append(_issue("ERROR", "MISSION SEQUENCE", sequence.id, "Event node requires an ID."))
		elif ids.has(id): issues.append(_issue("ERROR", "MISSION SEQUENCE", sequence.id, "Duplicate event-node ID '%s'." % id))
		else: ids[id] = true
		if type not in allowed: issues.append(_issue("ERROR", "MISSION SEQUENCE", id, "Unknown generic event-node type '%s'." % type))
		if type in [&"SPAWN_ACTOR", &"DESPAWN_ACTOR", &"MOVE_ACTOR", &"DIALOGUE", &"HINT"] and node.get("actor_id", &"") not in _ids(document.hacker_npcs): issues.append(_issue("ERROR", "MISSION SEQUENCE", id, "Hacker actor reference is missing."))
		if type in [&"SPAWN_ACTOR", &"MOVE_ACTOR"] and node.get("node_id", &"") not in node_ids: issues.append(_issue("ERROR", "MISSION SEQUENCE", id, "Network node reference is missing."))
		if type in [&"OBJECTIVE_START", &"OBJECTIVE_COMPLETE"] and node.get("objective_id", &"") not in _ids(document.objectives) and node.get("objective_data", {}).is_empty(): issues.append(_issue("ERROR", "MISSION SEQUENCE", id, "Objective reference is missing."))
		if type == &"HIGHLIGHT" and node.get("target_type", &"NODE") == &"NODE" and node.get("target_id", &"") not in node_ids: issues.append(_issue("ERROR", "MISSION SEQUENCE", id, "Highlighted network node is missing."))
		if type == &"SPAWN_REWARD" and node.get("reward_id", &"") not in _ids(document.rewards): issues.append(_issue("ERROR", "MISSION SEQUENCE", id, "Reward reference is missing."))
		if type == &"SPAWN_ICE" and node.get("ice_definition_id", &"") not in ice_definition_ids: issues.append(_issue("ERROR", "MISSION SEQUENCE", id, "ICE definition reference is missing."))
		if type == &"TRIGGER_REALTIME_EVENT" and node.get("realtime_event_id", &"") not in _ids(document.realtime_events): issues.append(_issue("ERROR", "MISSION SEQUENCE", id, "Realtime event reference is missing."))
		if type == &"WAIT_FOR" and StringName(node.get("event_type", &"")).is_empty(): issues.append(_issue("ERROR", "MISSION SEQUENCE", id, "Wait node requires a structured gameplay event."))
		if type == &"BRANCH" and node.get("branches", []).is_empty(): issues.append(_issue("WARNING", "MISSION SEQUENCE", id, "Branch node has no authored outcomes."))
		if type == &"SET_FLAG" and node.get("flag_id", &"") not in _ids(document.story_variables): issues.append(_issue("ERROR", "MISSION SEQUENCE", id, "Story flag reference is missing."))
		if type in [&"DIALOGUE", &"HINT"] and String(node.get("text", "")).strip_edges().is_empty(): issues.append(_issue("WARNING", "MISSION SEQUENCE", id, "Dialogue node has no text."))
	for node: Dictionary in sequence.get("event_nodes", []):
		if node.get("next_id", &"") != &"" and node.get("next_id") not in ids: issues.append(_issue("ERROR", "MISSION SEQUENCE", node.id, "Next event-node reference is missing."))
		for branch: Dictionary in node.get("branches", []):
			if branch.get("next_id", &"") not in ids: issues.append(_issue("ERROR", "MISSION SEQUENCE", node.id, "Branch outcome references a missing event node."))
func _issue(level: String, category: String, id: StringName, message: String) -> Dictionary: return {"level": level, "category": category, "entry_id": id, "message": message}

func _validate_story_mode_authoring(issues: Array[Dictionary], document: CyberspaceContentDocument) -> void:
	var flags := _ids(document.story_variables); var missions := _ids(document.missions); var contacts := _ids(document.contacts); var calls := _ids(document.contact_comms); var objectives := _ids(document.objectives)
	var valid_actions: Array[StringName] = [&"set_flag", &"set_value", &"increment_value", &"set_state", &"unlock_contact", &"change_reputation", &"start_comms", &"start_dialogue", &"add_objective", &"complete_objective", &"fail_objective", &"unlock_mission", &"change_room_object_state", &"give_ics", &"remove_ics", &"advance_story_time", &"set_story_time"]
	var event_ids: Dictionary = {}
	for event: Dictionary in document.authored_story_events:
		var event_id := StringName(event.get("event_id", event.get("id", &"")))
		if event_ids.has(event_id): issues.append(_issue("ERROR", "STORY EVENTS", event_id, "Duplicate event ID."))
		event_ids[event_id] = true
		if StringName(event.get("trigger", &"")).is_empty(): issues.append(_issue("ERROR", "STORY EVENTS", event_id, "Event trigger is missing."))
		for action: Dictionary in event.get("actions", []):
			var type := StringName(action.get("type", &"")).to_lower(); var reference := StringName(action.get("id", &""))
			if type not in valid_actions: issues.append(_issue("ERROR", "STORY EVENTS", event_id, "Unknown story action '%s'." % type)); continue
			if type in [&"set_flag", &"set_value", &"increment_value"] and reference not in flags: issues.append(_issue("ERROR", "STORY EVENTS", event_id, "Action references unknown story variable '%s'." % reference))
			if type in [&"unlock_contact", &"change_reputation"] and reference not in contacts: issues.append(_issue("ERROR", "STORY EVENTS", event_id, "Action references missing contact '%s'." % reference))
			if type == &"unlock_mission" and reference not in missions: issues.append(_issue("ERROR", "STORY EVENTS", event_id, "Action references missing mission '%s'." % reference))
			if type in [&"add_objective", &"complete_objective", &"fail_objective"] and reference not in objectives: issues.append(_issue("ERROR", "STORY EVENTS", event_id, "Action references missing objective '%s'." % reference))
			if type == &"start_comms" and reference not in calls: issues.append(_issue("ERROR", "STORY EVENTS", event_id, "Action references missing comms call '%s'." % reference))
	for contact: Dictionary in document.contacts:
		for mission_id: Variant in contact.get("missions_offered", []):
			if mission_id not in missions: issues.append(_issue("ERROR", "CONTACTS", contact.id, "Contact offers missing mission '%s'." % mission_id))
		for call_id: Variant in contact.get("comms_content", []):
			if call_id not in calls: issues.append(_issue("ERROR", "CONTACTS", contact.id, "Contact references missing comms '%s'." % call_id))
	for mission: Dictionary in document.missions:
		var local_objectives: Dictionary = {}
		for collection: String in ["primary_objectives", "optional_objectives", "hidden_objectives"]:
			for objective: Dictionary in mission.get(collection, []):
				var objective_id := StringName(objective.get("objective_id", &"")); if local_objectives.has(objective_id): issues.append(_issue("ERROR", "MISSIONS", mission.id, "Duplicate objective '%s'." % objective_id)); local_objectives[objective_id] = true
	for binding: Dictionary in document.room_bindings:
		if String(binding.get("scene_node_path", "")).strip_edges().is_empty(): issues.append(_issue("ERROR", "ROOM BINDINGS", binding.id, "Scene node binding is missing."))
		for key: String in ["visible_if", "hidden_if"]:
			var rule: Dictionary = binding.get(key, {}); if rule.get("scope", &"flag") == &"flag" and rule.get("id", &"") != &"" and rule.get("id") not in flags: issues.append(_issue("ERROR", "ROOM BINDINGS", binding.id, "%s references unknown story flag '%s'." % [key, rule.get("id")]))
