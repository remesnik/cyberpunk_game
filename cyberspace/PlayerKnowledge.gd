class_name PlayerKnowledge
extends RefCounted

const CAPABILITY_CATALOG := preload("res://cyberspace/display/node_capability_catalog.tres")

signal knowledge_changed

## Sanitized player-facing records. World objects are never returned to displays.
var node_records: Dictionary = {}
var link_records: Dictionary = {}
var ice_records: Dictionary = {}
var hacker_records: Dictionary = {}
var service_records: Dictionary = {}
var realtime_endpoint_records: Dictionary = {}
var realtime_process_records: Dictionary = {}
var ice_observations: Array[Dictionary] = []
## Tracks only already-discovered contributors, preventing repeated observations
## from inflating category counts. This is knowledge state, never world state.
var node_capability_sources: Dictionary = {}


func observe_hacker(actor: HackerNPC) -> void:
	if actor == null or actor.definition == null:
		return
	hacker_records[actor.instance_id] = {
		"id": actor.instance_id,
		"contact_id": StringName("HACKER_%s" % actor.instance_id),
		"display_name": actor.definition.display_name,
		"callsign": actor.definition.callsign,
		"faction": actor.definition.faction,
		"relationship": actor.definition.player_relationship,
		"node_id": actor.current_node_id,
		"state": actor.state,
		"present": true,
	}
	knowledge_changed.emit()


func mark_hacker_absent(actor_id: StringName) -> void:
	if not hacker_records.has(actor_id) or not bool(hacker_records[actor_id].get("present", false)):
		return
	hacker_records[actor_id]["present"] = false
	knowledge_changed.emit()


func get_visible_hackers_at(node_ids: Array[StringName]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in hacker_records.values():
		if bool(record.get("present", false)) and node_ids.has(record.get("node_id", &"")):
			result.append(record.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("callsign", "")) < String(b.get("callsign", "")))
	return result

func get_node_level(node_id: StringName) -> KnowledgeLevel.Value:
	return int(node_records.get(node_id, {}).get("level", KnowledgeLevel.Value.UNKNOWN))

func get_link_level(link_id: StringName) -> KnowledgeLevel.Value:
	return int(link_records.get(link_id, {}).get("level", KnowledgeLevel.Value.UNKNOWN))

func get_ice_level(instance_id: StringName) -> KnowledgeLevel.Value:
	return int(ice_records.get(instance_id, {}).get("level", KnowledgeLevel.Value.UNKNOWN))

func knows_node(node_id: StringName) -> bool:
	return get_node_level(node_id) >= KnowledgeLevel.Value.IDENTIFIED

func player_knows_node_exists(node_id: StringName) -> bool:
	return bool(node_records.get(node_id, {}).get("exists_known", node_records.has(node_id)))

func player_knows_node_level(node_id: StringName) -> bool:
	return bool(node_records.get(node_id, {}).get("level_known", false))

func player_knows_node_contents(node_id: StringName) -> bool:
	return bool(node_records.get(node_id, {}).get("contents_known", false))

func get_known_node_capabilities(node_id: StringName) -> Array[int]:
	var result: Array[int] = []
	result.assign(node_records.get(node_id, {}).get("capability_types", []))
	return result

func get_known_node_capability_counts(node_id: StringName) -> Dictionary:
	return (node_records.get(node_id, {}).get("capability_counts", {}) as Dictionary).duplicate()

func get_unknown_node_content_count(node_id: StringName) -> int:
	return maxi(0, int(node_records.get(node_id, {}).get("unknown_content_count", 0)))

func reveal_uncertain_node_contents(node_id: StringName, count: int, source: StringName = &"INTELLIGENCE") -> void:
	if node_id == &"" or count <= 0:
		return
	var record := _node_record(node_id)
	record["exists_known"] = true
	record["unknown_content_count"] = maxi(get_unknown_node_content_count(node_id), count)
	_add_node_source(record, source)
	node_records[node_id] = record
	knowledge_changed.emit()

func reveal_node_capability(node_id: StringName, capability: Variant, source: StringName = &"OBSERVATION", contributor_id: StringName = &"") -> void:
	var parsed := NodeCapabilityType.parse(capability)
	if node_id == &"" or parsed < 0:
		return
	var record := _node_record(node_id)
	var capabilities: Array = record.get("capability_types", []).duplicate()
	var counts: Dictionary = (record.get("capability_counts", {}) as Dictionary).duplicate()
	var contributor_is_new := true
	if contributor_id != &"":
		var node_sources: Dictionary = (node_capability_sources.get(node_id, {}) as Dictionary).duplicate(true)
		var capability_sources: Array = (node_sources.get(parsed, []) as Array).duplicate()
		contributor_is_new = not capability_sources.has(contributor_id)
		if contributor_is_new:
			capability_sources.append(contributor_id)
			node_sources[parsed] = capability_sources
			node_capability_sources[node_id] = node_sources
	elif capabilities.has(parsed):
		contributor_is_new = false
	if not contributor_is_new:
		return
	if not capabilities.has(parsed): capabilities.append(parsed)
	counts[parsed] = int(counts.get(parsed, 0)) + 1
	record["capability_types"] = capabilities
	record["capability_counts"] = counts
	_add_node_source(record, source)
	node_records[node_id] = record
	knowledge_changed.emit()

func set_local_system_access_node(node_id: StringName, san_id: StringName, present: bool) -> void:
	if present:
		reveal_node_capability(node_id, NodeCapabilityType.Value.SYSTEM_ACCESS_NODE, &"LOCAL_DECK_LINK", san_id)
	var record := _node_record(node_id)
	if present:
		record["local_san_present"] = true
	else:
		_forget_node_capability_contributor(node_id, NodeCapabilityType.Value.SYSTEM_ACCESS_NODE, san_id)
		record = _node_record(node_id)
		record["local_san_present"] = false
	node_records[node_id] = record
	knowledge_changed.emit()

func _forget_node_capability_contributor(node_id: StringName, capability: int, contributor_id: StringName) -> void:
	var node_sources: Dictionary = (node_capability_sources.get(node_id, {}) as Dictionary).duplicate(true)
	var sources: Array = (node_sources.get(capability, []) as Array).duplicate()
	if not sources.has(contributor_id): return
	sources.erase(contributor_id)
	node_sources[capability] = sources
	node_capability_sources[node_id] = node_sources
	var record := _node_record(node_id)
	var counts: Dictionary = (record.get("capability_counts", {}) as Dictionary).duplicate()
	var remaining := maxi(0, int(counts.get(capability, 0)) - 1)
	if remaining == 0:
		counts.erase(capability)
		var capabilities: Array = record.get("capability_types", []).duplicate()
		capabilities.erase(capability)
		record["capability_types"] = capabilities
	else: counts[capability] = remaining
	record["capability_counts"] = counts
	node_records[node_id] = record

func player_has_scanned_node(node_id: StringName) -> bool:
	return bool(node_records.get(node_id, {}).get("scanned", false))

func player_has_visited_node(node_id: StringName) -> bool:
	return bool(node_records.get(node_id, {}).get("visited", false))

func get_node_knowledge_state(node_id: StringName) -> StringName:
	if player_has_visited_node(node_id): return &"VISITED"
	if player_has_scanned_node(node_id): return &"SCANNED"
	if player_knows_node_level(node_id): return &"LEVEL_KNOWN"
	return &"UNKNOWN"

func discover_node(node: NetworkNodeDefinition, source: StringName = &"OBSERVATION") -> void:
	if node == null: return
	var record := _node_record(node.id)
	record["exists_known"] = true
	_add_node_source(record, source)
	node_records[node.id] = record
	knowledge_changed.emit()

func reveal_node_level(node: NetworkNodeDefinition, source: StringName = &"INTELLIGENCE") -> void:
	if node == null: return
	var record := _node_record(node.id)
	record.merge({"exists_known": true, "level_known": true, "security_level": node.security_level}, true)
	_add_node_source(record, source)
	node_records[node.id] = record
	knowledge_changed.emit()

func reveal_node_contents(node: NetworkNodeDefinition, source: StringName = &"INTELLIGENCE") -> void:
	if node == null: return
	var record := _node_record(node.id)
	record.merge({"exists_known": true, "contents_known": true, "unknown_content_count": 0, "owner_faction": node.owner_faction, "service_ids": node.services.map(func(service): return service.get("id", &"")), "capability_types": CAPABILITY_CATALOG.derive_from_services(node.services), "capability_counts": CAPABILITY_CATALOG.derive_counts_from_services(node.services), "required_capabilities_all": node.required_capabilities_all.duplicate(), "required_capabilities_any": node.required_capabilities_any.duplicate(), "accepted_credentials": node.accepted_credentials.duplicate(), "recommended_capabilities": node.recommended_capabilities.duplicate()}, true)
	_seed_capability_sources(node)
	_add_node_source(record, source)
	node_records[node.id] = record
	knowledge_changed.emit()

func mark_node_scanned(node: NetworkNodeDefinition, reveal_level := true, reveal_contents := true, source: StringName = &"SCAN") -> void:
	if node == null: return
	var record := _node_record(node.id)
	record.merge({"exists_known": true, "identity_known": true, "display_name": node.display_name, "node_type": node.node_type, "scanned": true, "level": maxi(int(record.get("level", 0)), KnowledgeLevel.Value.SCANNED)}, true)
	if reveal_level: record.merge({"level_known": true, "security_level": node.security_level}, true)
	if reveal_contents:
		record.merge({"contents_known": true, "unknown_content_count": 0, "owner_faction": node.owner_faction, "service_ids": node.services.map(func(service): return service.get("id", &"")), "capability_types": CAPABILITY_CATALOG.derive_from_services(node.services), "capability_counts": CAPABILITY_CATALOG.derive_counts_from_services(node.services), "required_capabilities_all": node.required_capabilities_all.duplicate(), "required_capabilities_any": node.required_capabilities_any.duplicate(), "accepted_credentials": node.accepted_credentials.duplicate(), "recommended_capabilities": node.recommended_capabilities.duplicate()}, true)
		_seed_capability_sources(node)
	_add_node_source(record, source)
	node_records[node.id] = record
	knowledge_changed.emit()

func mark_node_visited(node: NetworkNodeDefinition, source: StringName = &"TRAVERSAL") -> void:
	if node == null: return
	var record := _node_record(node.id)
	record.merge({"exists_known": true, "identity_known": true, "display_name": node.display_name, "node_type": node.node_type, "visited": true, "level": maxi(int(record.get("level", 0)), KnowledgeLevel.Value.IDENTIFIED)}, true)
	_add_node_source(record, source)
	node_records[node.id] = record
	knowledge_changed.emit()

func knows_link(link_id: StringName) -> bool:
	return get_link_level(link_id) >= KnowledgeLevel.Value.IDENTIFIED

func suspects_link(link_id: StringName) -> bool:
	return get_link_level(link_id) == KnowledgeLevel.Value.DETECTED

func knows_security_at(node_id: StringName) -> bool:
	for record in ice_records.values():
		if int(record.get("level", 0)) >= KnowledgeLevel.Value.IDENTIFIED and record.get("node_id", &"") == node_id:
			return true
	return false

func knows_ice(instance_id: StringName) -> bool:
	return get_ice_level(instance_id) >= KnowledgeLevel.Value.IDENTIFIED

func reveal_node(node: NetworkNodeDefinition, level: KnowledgeLevel.Value) -> void:
	if node == null: return
	var record := _node_record(node.id)
	record["exists_known"] = true
	record["level"] = maxi(level, int(record.get("level", KnowledgeLevel.Value.UNKNOWN)))
	if level >= KnowledgeLevel.Value.IDENTIFIED:
		record.merge({"identity_known": true, "display_name": node.display_name, "node_type": node.node_type}, true)
	if level >= KnowledgeLevel.Value.SCANNED:
		record.merge({"scanned": true, "level_known": true, "contents_known": true, "unknown_content_count": 0, "security_level": node.security_level, "owner_faction": node.owner_faction, "service_ids": node.services.map(func(service): return service.get("id", &"")), "capability_types": CAPABILITY_CATALOG.derive_from_services(node.services), "capability_counts": CAPABILITY_CATALOG.derive_counts_from_services(node.services), "required_capabilities_all": node.required_capabilities_all.duplicate(), "required_capabilities_any": node.required_capabilities_any.duplicate(), "accepted_credentials": node.accepted_credentials.duplicate(), "recommended_capabilities": node.recommended_capabilities.duplicate()}, true)
		_seed_capability_sources(node)
	if level >= KnowledgeLevel.Value.COMPROMISED: record["compromised"] = true
	_add_node_source(record, &"LEGACY_REVEAL")
	node_records[node.id] = record
	knowledge_changed.emit()

func detect_link(link: NetworkLinkDefinition) -> void:
	if link == null or get_link_level(link.id) >= KnowledgeLevel.Value.DETECTED:
		return
	# A detected contact deliberately contains no destination or topology fields.
	link_records[link.id] = {"level": KnowledgeLevel.Value.DETECTED, "contact_id": _contact_id(link.id), "source": link.source}
	knowledge_changed.emit()

func reveal_link(link: NetworkLinkDefinition, level: KnowledgeLevel.Value) -> void:
	if link == null or level <= get_link_level(link.id):
		return
	var record := {"level": level, "contact_id": _contact_id(link.id), "source": link.source}
	if level >= KnowledgeLevel.Value.IDENTIFIED:
		record.merge({"id": link.id, "source": link.source, "destination": link.destination, "one_way": link.one_way}, true)
	if level >= KnowledgeLevel.Value.SCANNED:
		record.merge({"locked": link.locked, "disabled": link.disabled, "traversal_cost": link.traversal_cost, "authority_requirement": link.authority_requirement, "required_capabilities_all": link.required_capabilities_all.duplicate(), "required_capabilities_any": link.required_capabilities_any.duplicate(), "accepted_credentials": link.accepted_credentials.duplicate(), "recommended_capabilities": link.recommended_capabilities.duplicate()}, true)
	link_records[link.id] = record
	knowledge_changed.emit()

func scan_node(graph: NetworkGraph, node_id: StringName) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var node := graph.get_node(node_id)
	if node == null:
		return events
	mark_node_scanned(node)
	for link_id in node.connected_links:
		var link := graph.get_link(link_id)
		if link == null or not link.connects_from(node_id):
			continue
		if link.hidden and not link.discovered:
			detect_link(link)
			events.append({"type": &"UNKNOWN_SIGNAL_DETECTED", "contact_id": _contact_id(link.id)})
			continue
		reveal_link(link, KnowledgeLevel.Value.SCANNED)
		var destination := graph.get_node(link.destination_from(node_id))
		reveal_node(destination, KnowledgeLevel.Value.IDENTIFIED)
		events.append({"type": &"NODE_IDENTIFIED", "node_id": destination.id})
	return events

func observe_traversal(graph: NetworkGraph, from_node_id: StringName, to_node_id: StringName) -> void:
	mark_node_visited(graph.get_node(to_node_id))
	var link := graph.find_link(from_node_id, to_node_id)
	if link != null:
		reveal_link(link, KnowledgeLevel.Value.IDENTIFIED)

func get_node_view(node_id: StringName) -> Dictionary:
	return (node_records.get(node_id, {}) as Dictionary).duplicate(true)

func get_local_contacts(current_node_id: StringName) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	for record_value in link_records.values():
		var record := record_value as Dictionary
		var level := int(record.get("level", KnowledgeLevel.Value.UNKNOWN))
		if level == KnowledgeLevel.Value.DETECTED and record.get("source", &"") == current_node_id:
			contacts.append({"kind": &"UNKNOWN_SIGNAL", "contact_id": record.contact_id, "level": level})
		elif level >= KnowledgeLevel.Value.IDENTIFIED:
			var source: StringName = record.get("source", &"")
			var destination: StringName = record.get("destination", &"")
			var other := destination if source == current_node_id else source
			var one_way := bool(record.get("one_way", false))
			if source != current_node_id and (one_way or destination != current_node_id):
				continue
			var node_view := get_node_view(other)
			if node_view.is_empty():
				contacts.append({"kind": &"UNKNOWN_NODE", "contact_id": record.contact_id, "level": KnowledgeLevel.Value.DETECTED})
			else:
				contacts.append({"kind": &"NODE", "contact_id": record.contact_id, "link": record.duplicate(true), "node": node_view})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.contact_id) < String(b.contact_id))
	return contacts

func resolve_link_contact(contact_id: StringName) -> StringName:
	for link_id in link_records:
		if link_records[link_id].get("contact_id", &"") == contact_id:
			return link_id
	return &""

func resolve_ice_contact(contact_id: StringName) -> StringName:
	for ice_id in ice_records:
		if ice_records[ice_id].get("contact_id", &"") == contact_id:
			return ice_id
	return &""

func resolve_service_contact(contact_id: StringName) -> StringName:
	for service_id in service_records:
		if service_records[service_id].get("contact_id", &"") == contact_id:
			return service_id
	return &""

func get_service_level(service_id: StringName) -> KnowledgeLevel.Value:
	return int(service_records.get(service_id, {}).get("level", KnowledgeLevel.Value.UNKNOWN))

func reveal_service(service: Dictionary, node_id: StringName, level: KnowledgeLevel.Value) -> void:
	var service_id: StringName = service.get("id", &"")
	if service_id == &"" or level <= get_service_level(service_id):
		return
	var was_unidentified := get_service_level(service_id) < KnowledgeLevel.Value.IDENTIFIED and level >= KnowledgeLevel.Value.IDENTIFIED
	var record := {"level": level, "contact_id": _contact_id(service_id), "node_id": node_id}
	if level >= KnowledgeLevel.Value.IDENTIFIED:
		var identified_service: Array[Dictionary] = [service]
		record.merge({"id": service_id, "display_name": service.get("display_name", "SERVICE"), "capability_types": CAPABILITY_CATALOG.derive_from_services(identified_service)}, true)
	if level >= KnowledgeLevel.Value.SCANNED:
		record.merge({"security_level": service.get("security_level", 0), "vulnerabilities": service.get("vulnerabilities", []).duplicate()}, true)
	service_records[service_id] = record
	var discovered_services: Array[Dictionary] = [service]
	for capability: int in CAPABILITY_CATALOG.derive_from_services(discovered_services):
		reveal_node_capability(node_id, capability, &"SERVICE_DISCOVERY", service_id)
	if was_unidentified:
		_resolve_one_uncertain_content(node_id)
	knowledge_changed.emit()

func get_services_at(node_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in service_records.values():
		if record.get("node_id", &"") == node_id:
			result.append((record as Dictionary).duplicate(true))
	return result

func commit_scan(result: ScanResult, graph: NetworkGraph, ice_controller: IceController) -> void:
	if not result.success:
		return
	for discovery in result.discoveries:
		var kind: StringName = discovery.get("entity_kind", &"")
		var entity_id: StringName = discovery.get("entity_id", &"")
		var level: KnowledgeLevel.Value = int(discovery.get("level", KnowledgeLevel.Value.UNKNOWN))
		match kind:
			&"NODE", &"NODE_DETAILS":
				if kind == &"NODE_DETAILS":
					mark_node_scanned(graph.get_node(entity_id), discovery.has("security_level"), true)
				else:
					reveal_node(graph.get_node(entity_id), level)
			&"NODE_CONTENT_COUNT", &"UNKNOWN_CONTENT":
				reveal_uncertain_node_contents(entity_id, int(discovery.get("count", 1)), &"SCAN")
			&"LINK":
				var link := graph.get_link(entity_id)
				if level == KnowledgeLevel.Value.DETECTED:
					detect_link(link)
				else:
					reveal_link(link, level)
			&"ICE":
				if level == KnowledgeLevel.Value.DETECTED:
					detect_ice(entity_id)
				else:
					var ice := ice_controller.get_ice(entity_id)
					if ice != null:
						report_ice(entity_id, discovery.get("node_id", ice.current_node_id), discovery.get("state", ice.state), level)
			&"SERVICE":
				var service_data := _find_service(graph, entity_id)
				if not service_data.is_empty():
					reveal_service(service_data.service, service_data.node_id, level)
			&"REALTIME_ENDPOINT":
				reveal_realtime_endpoint(discovery)
	knowledge_changed.emit()


func knows_realtime_endpoint(endpoint_id: StringName) -> bool:
	return realtime_endpoint_records.has(endpoint_id)


func knows_realtime_process(process_id: StringName) -> bool:
	return realtime_process_records.has(process_id)


func reveal_realtime_endpoint(discovery: Dictionary) -> void:
	var endpoint_id: StringName = discovery.get("entity_id", &"")
	if endpoint_id == &"":
		return
	# Store a sanitized knowledge record, never the objective endpoint or process objects.
	realtime_endpoint_records[endpoint_id] = {
		"id": endpoint_id,
		"level": discovery.get("level", KnowledgeLevel.Value.IDENTIFIED),
		"endpoint_type": discovery.get("endpoint_type", RealtimeEndpointDefinition.EndpointType.CUSTOM),
		"network_node_id": discovery.get("network_node_id", &""),
		"service_id": discovery.get("service_id", &""),
		"description": discovery.get("description", ""),
		"tags": discovery.get("tags", []).duplicate(),
		"accessible": discovery.get("accessible", false),
		"authority_requirement": discovery.get("authority_requirement", 0),
		"capability_requirement": discovery.get("capability_requirement", &""),
		"access_requirement": discovery.get("access_requirement", &""),
		"associated_process_ids": [],
	}
	reveal_node_capability(discovery.get("network_node_id", &""), NodeCapabilityType.Value.MEATSPACE, &"ENDPOINT_DISCOVERY", endpoint_id)
	var endpoint_capability := _endpoint_capability(int(discovery.get("endpoint_type", RealtimeEndpointDefinition.EndpointType.CUSTOM)))
	if endpoint_capability >= 0:
		reveal_node_capability(discovery.get("network_node_id", &""), endpoint_capability, &"ENDPOINT_DISCOVERY", endpoint_id)
	for process_view: Dictionary in discovery.get("associated_processes", []):
		var process_id: StringName = process_view.get("id", &"")
		if process_id != &"":
			var sanitized_process := process_view.duplicate(true)
			sanitized_process["endpoint_id"] = endpoint_id
			realtime_process_records[process_id] = sanitized_process
			realtime_endpoint_records[endpoint_id].associated_process_ids.append(process_id)
	knowledge_changed.emit()

func detect_ice(instance_id: StringName) -> void:
	if get_ice_level(instance_id) >= KnowledgeLevel.Value.DETECTED:
		return
	ice_records[instance_id] = {"level": KnowledgeLevel.Value.DETECTED, "contact_id": _contact_id(instance_id), "display_name": "UNKNOWN SECURITY PROCESS", "position_stale": false}
	knowledge_changed.emit()

func report_ice(instance_id: StringName, node_id: StringName, state: IceState.Value, level: KnowledgeLevel.Value = KnowledgeLevel.Value.IDENTIFIED) -> void:
	var record := (ice_records.get(instance_id, {}) as Dictionary).duplicate(true)
	var previous_node: StringName = record.get("last_known_node_id", record.get("node_id", &""))
	if bool(record.get("position_stale", false)): _adjust_stale_ice_count(previous_node, -1)
	elif previous_node != &"" and previous_node != node_id: _forget_node_capability_contributor(previous_node, NodeCapabilityType.Value.ICE, instance_id)
	record.merge({"level": maxi(level, get_ice_level(instance_id)), "contact_id": _contact_id(instance_id), "id": instance_id, "display_name": String(instance_id), "node_id": node_id, "last_known_node_id": node_id, "position_stale": false, "state": state}, true)
	ice_records[instance_id] = record
	reveal_node_capability(node_id, NodeCapabilityType.Value.ICE, &"ICE_OBSERVATION", instance_id)
	knowledge_changed.emit()

func mark_ice_position_stale(instance_id: StringName) -> void:
	if not ice_records.has(instance_id): return
	var record := (ice_records[instance_id] as Dictionary).duplicate(true)
	if int(record.get("level", 0)) < KnowledgeLevel.Value.IDENTIFIED or bool(record.get("position_stale", false)): return
	var old_node: StringName = record.get("node_id", &"")
	if old_node == &"": return
	_forget_node_capability_contributor(old_node, NodeCapabilityType.Value.ICE, instance_id)
	_adjust_stale_ice_count(old_node, 1)
	record.merge({"last_known_node_id": old_node, "node_id": &"", "position_stale": true}, true)
	ice_records[instance_id] = record
	knowledge_changed.emit()

func _adjust_stale_ice_count(node_id: StringName, delta: int) -> void:
	if node_id == &"": return
	var record := _node_record(node_id)
	record["stale_ice_count"] = maxi(0, int(record.get("stale_ice_count", 0)) + delta)
	node_records[node_id] = record

func _endpoint_capability(endpoint_type: int) -> int:
	match endpoint_type:
		RealtimeEndpointDefinition.EndpointType.VIDEO, RealtimeEndpointDefinition.EndpointType.AUDIO:
			return NodeCapabilityType.Value.FEED
		RealtimeEndpointDefinition.EndpointType.COMMS:
			return NodeCapabilityType.Value.COMMUNICATIONS
		RealtimeEndpointDefinition.EndpointType.ALARM:
			return NodeCapabilityType.Value.SECURITY
		RealtimeEndpointDefinition.EndpointType.ACCESS_CONTROL, RealtimeEndpointDefinition.EndpointType.DEVICE_CONTROL:
			return NodeCapabilityType.Value.CONTROL_SYSTEM
		RealtimeEndpointDefinition.EndpointType.SENSOR, RealtimeEndpointDefinition.EndpointType.TEAM_TRACKING:
			return NodeCapabilityType.Value.IO
	return -1

func add_observation(type: StringName, node_id: StringName) -> void:
	ice_observations.append({"type": type, "node_id": node_id})
	if ice_observations.size() > 12:
		ice_observations.pop_front()

func _contact_id(objective_id: StringName) -> StringName:
	return StringName("CONTACT_%08X" % abs(String(objective_id).hash()))

func _find_service(graph: NetworkGraph, service_id: StringName) -> Dictionary:
	for node_id in graph.nodes:
		for service in graph.get_node(node_id).services:
			if service.get("id", &"") == service_id:
				return {"node_id": node_id, "service": service}
	return {}

func _node_record(node_id: StringName) -> Dictionary:
	var record := (node_records.get(node_id, {}) as Dictionary).duplicate(true)
	if record.is_empty():
		record = {"id": node_id, "level": KnowledgeLevel.Value.UNKNOWN, "exists_known": false, "identity_known": false, "level_known": false, "contents_known": false, "unknown_content_count": 0, "capability_types": [], "capability_counts": {}, "stale_ice_count": 0, "local_san_present": false, "scanned": false, "visited": false, "compromised": false, "sources": []}
	return record

func _seed_capability_sources(node: NetworkNodeDefinition) -> void:
	var node_sources: Dictionary = {}
	for service: Dictionary in node.services:
		var service_id: StringName = service.get("id", &"")
		var single_service: Array[Dictionary] = [service]
		for capability: int in CAPABILITY_CATALOG.derive_from_services(single_service):
			var sources: Array = node_sources.get(capability, [])
			if service_id != &"" and not sources.has(service_id): sources.append(service_id)
			node_sources[capability] = sources
	node_capability_sources[node.id] = node_sources

func _resolve_one_uncertain_content(node_id: StringName) -> void:
	var record := _node_record(node_id)
	var remaining := maxi(0, int(record.get("unknown_content_count", 0)) - 1)
	if remaining == int(record.get("unknown_content_count", 0)):
		return
	record["unknown_content_count"] = remaining
	node_records[node_id] = record

func _add_node_source(record: Dictionary, source: StringName) -> void:
	var sources: Array = record.get("sources", []).duplicate()
	if not source.is_empty() and not sources.has(source): sources.append(source)
	record["sources"] = sources
