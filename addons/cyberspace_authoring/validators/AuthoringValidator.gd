@tool
extends RefCounted


func validate(document: CyberspaceContentDocument) -> Array[Dictionary]:
	if document == null: return [_issue("ERROR", "GENERAL", &"", "No authoring document is open.")]
	var issues: Array[Dictionary] = []; var ids: Dictionary = {}
	for entry: Dictionary in document.all_entries():
		var id: StringName = entry.get("id", &"")
		if id == &"": issues.append(_issue("ERROR", "GENERAL", &"", "Entry has no ID."))
		elif ids.has(id): issues.append(_issue("ERROR", "GENERAL", id, "Duplicate ID '%s'." % id))
		else: ids[id] = entry.get("_collection", &"")
	var node_ids := _ids(document.network_nodes); var service_ids := _ids(document.services); var location_ids := _ids(document.meatspace_locations); var endpoint_ids := _ids(document.realtime_endpoints)
	for link: Dictionary in document.network_links:
		if link.get("source", &"") not in node_ids: issues.append(_issue("ERROR", "NETWORK", link.id, "Link source does not exist."))
		if link.get("destination", &"") not in node_ids: issues.append(_issue("ERROR", "NETWORK", link.id, "Link destination does not exist."))
		if int(link.get("traversal_cost", 0)) < 0: issues.append(_issue("ERROR", "NETWORK", link.id, "Traversal cost cannot be negative."))
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
	if issues.is_empty(): issues.append(_issue("INFO", "GENERAL", document.document_id, "VALIDATE ALL passed with no issues."))
	return issues


func validate_shell() -> Array[Dictionary]: return [_issue("INFO", "GENERAL", &"", "Authoring plugin shell loaded.")]
func _ids(entries: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in entries: result.append(entry.get("id", &""))
	return result
func _node_has_link(id: StringName, links: Array[Dictionary]) -> bool:
	for link in links:
		if link.get("source") == id or link.get("destination") == id: return true
	return false
func _validate_timeline(issues: Array[Dictionary], category: String, entry: Dictionary) -> void:
	var previous := -1.0
	for event: Dictionary in entry.get("timeline", []):
		var time := float(event.get("time", -1.0))
		if time < 0.0 or time < previous: issues.append(_issue("ERROR", category, entry.id, "Timeline is negative or not ordered.")); return
		previous = time
func _issue(level: String, category: String, id: StringName, message: String) -> Dictionary: return {"level": level, "category": category, "entry_id": id, "message": message}
