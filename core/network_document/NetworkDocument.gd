class_name NetworkDocument
extends RefCounted

const CURRENT_FORMAT_VERSION := 1

var format_version := CURRENT_FORMAT_VERSION
var network_id: StringName = &"UNTITLED_NETWORK"
var display_name := "Untitled Network"
var metadata: Dictionary = {}
var nodes: Array[Dictionary] = []
var paths: Array[Dictionary] = []
var spheres: Array[Dictionary] = []
var services: Array[Dictionary] = []
var stationary_ice: Array[Dictionary] = []
var mobile_ice: Array[Dictionary] = []
var story_metadata: Dictionary = {}

const TOPOLOGY_COLLECTIONS: Array[StringName] = [
	&"network_nodes", &"network_links", &"spheres", &"security_sleeves",
	&"services", &"ice_definitions", &"ice_instances",
]

func to_dict() -> Dictionary:
	return {"format_version": format_version, "network_id": network_id, "display_name": display_name, "metadata": metadata.duplicate(true), "nodes": nodes.duplicate(true), "paths": paths.duplicate(true), "spheres": spheres.duplicate(true), "services": services.duplicate(true), "stationary_ice": stationary_ice.duplicate(true), "mobile_ice": mobile_ice.duplicate(true), "story_metadata": story_metadata.duplicate(true)}

static func from_dict(data: Dictionary) -> NetworkDocument:
	var document := NetworkDocument.new()
	document.format_version = int(data.get("format_version", 0)); document.network_id = StringName(data.get("network_id", &"")); document.display_name = String(data.get("display_name", "Untitled Network"))
	document.metadata = (data.get("metadata", {}) as Dictionary).duplicate(true); document.story_metadata = (data.get("story_metadata", {}) as Dictionary).duplicate(true)
	document.nodes.assign(data.get("nodes", [])); document.paths.assign(data.get("paths", [])); document.spheres.assign(data.get("spheres", [])); document.services.assign(data.get("services", [])); document.stationary_ice.assign(data.get("stationary_ice", [])); document.mobile_ice.assign(data.get("mobile_ice", []))
	return document

static func from_content_document(content: CyberspaceContentDocument) -> NetworkDocument:
	## Explicit migration adapter for legacy authored content. Gameplay-facing story
	## data remains metadata; topology is promoted into the versioned document model.
	var document := NetworkDocument.new()
	document.network_id = content.document_id
	document.display_name = content.title
	document.metadata = {"entry_node_id": _find_entry_node(content.network_nodes), "source_schema_version": content.schema_version}
	document.story_metadata = _capture_content_extras(content)
	var node_spheres := {}
	for node: Dictionary in content.network_nodes:
		var record := node.duplicate(true)
		record["type"] = record.get("node_type", &"SYSTEM")
		record.erase("node_type")
		record.erase("services")
		document.nodes.append(record)
		node_spheres[StringName(node.get("id", &""))] = StringName(node.get("sphere_id", &""))
	for path: Dictionary in content.network_links:
		var record := path.duplicate(true)
		record["node_a"] = record.get("source", &"")
		record["node_b"] = record.get("destination", &"")
		record.erase("source")
		record.erase("destination")
		document.paths.append(record)
	for override: Dictionary in content.path_security_overrides:
		var path_index := document.paths.find_custom(func(item: Dictionary): return StringName(item.get("id", &"")) == StringName(override.get("link_id", &"")))
		if path_index < 0: continue
		var directions: Array = document.paths[path_index].get("directions", [])
		var direction_index := directions.find_custom(func(item: Dictionary): return StringName(item.get("source", &"")) == StringName(override.get("source", &"")) and StringName(item.get("destination", &"")) == StringName(override.get("destination", &"")))
		if direction_index >= 0:
			var merged: Dictionary = directions[direction_index].duplicate(true)
			merged.merge(override, true)
			merged.erase("link_id")
			directions[direction_index] = merged
			document.paths[path_index]["directions"] = directions
	for service: Dictionary in content.services:
		document.services.append(service.duplicate(true))
	var sleeves_by_id := {}
	for sleeve: Dictionary in content.security_sleeves:
		sleeves_by_id[StringName(sleeve.get("id", &""))] = sleeve.duplicate(true)
	for sphere: Dictionary in content.spheres:
		var sphere_id := StringName(sphere.get("id", &""))
		var members: Array = sphere.get("node_ids", []).duplicate()
		if members.is_empty():
			for node_id: StringName in node_spheres:
				if node_spheres[node_id] == sphere_id: members.append(node_id)
		var sleeve_id := StringName(sphere.get("original_security_sleeve_id", &""))
		document.spheres.append({"id": sphere_id, "name": sphere.get("display_name", "Sphere"), "node_ids": members, "security_sleeve": sleeves_by_id.get(sleeve_id, {}).duplicate(true), "metadata": sphere.get("metadata", {}).duplicate(true)})
	# Older content represented a subnet only through Security Sleeve members.
	# Promote it to an explicit sphere without inventing overlapping membership.
	for sleeve_id: StringName in sleeves_by_id:
		if document.spheres.any(func(item: Dictionary): return StringName(item.get("security_sleeve", {}).get("id", &"")) == sleeve_id): continue
		var sleeve: Dictionary = sleeves_by_id[sleeve_id]
		var sphere_id := StringName("%s_SPHERE" % String(sleeve_id))
		document.spheres.append({"id": sphere_id, "name": "%s Sphere" % sleeve.get("display_name", sleeve_id), "node_ids": sleeve.get("current_members", []).duplicate(), "security_sleeve": sleeve.duplicate(true), "metadata": {"migrated_from_security_sleeve": true}})
		for node_id in sleeve.get("current_members", []): node_spheres[StringName(node_id)] = sphere_id
	var definitions := {}
	for definition: Dictionary in content.ice_definitions: definitions[StringName(definition.get("id", &""))] = definition.duplicate(true)
	for instance: Dictionary in content.ice_instances:
		var record := instance.duplicate(true)
		var definition: Dictionary = definitions.get(StringName(instance.get("definition_id", &"")), {}).duplicate(true)
		record["definition"] = definition
		var start_node := StringName(record.get("initial_node_id", &""))
		var sphere_id: StringName = node_spheres.get(start_node, &"")
		if sphere_id != &"":
			record["sphere_id"] = sphere_id
			var sphere_index := document.spheres.find_custom(func(item: Dictionary): return StringName(item.get("id", &"")) == sphere_id)
			if sphere_index >= 0: record["security_sleeve_id"] = document.spheres[sphere_index].get("security_sleeve", {}).get("id", &"")
		var binding := StringName(String(definition.get("binding_mode", &"ROAMING")).to_upper())
		(document.stationary_ice if binding == &"HOST_BOUND" else document.mobile_ice).append(record)
	return document

static func _find_entry_node(nodes_data: Array[Dictionary]) -> StringName:
	for node: Dictionary in nodes_data:
		if &"ENTRY" in node.get("tags", []): return StringName(node.get("id", &""))
	return StringName(nodes_data[0].get("id", &"")) if not nodes_data.is_empty() else &""

static func _capture_content_extras(content: CyberspaceContentDocument) -> Dictionary:
	var extras := {"summary": content.summary, "tags": content.tags.duplicate(), "availability": content.availability, "mode_variants": content.mode_variants.duplicate(true), "hud_guidance": content.hud_guidance.duplicate(true), "tutorial_sequence_patches": content.tutorial_sequence_patches.duplicate(true), "tutorial_stage_insertions": content.tutorial_stage_insertions.duplicate(true), "tutorial_beat_overrides": content.tutorial_beat_overrides.duplicate(true), "hard_gate_tutorial_insertions": content.hard_gate_tutorial_insertions.duplicate(true), "data_tutorial_insertions": content.data_tutorial_insertions.duplicate(true), "escalation_tutorial_insertions": content.escalation_tutorial_insertions.duplicate(true), "final_tutorial_insertions": content.final_tutorial_insertions.duplicate(true)}
	for collection_name: StringName in CyberspaceContentDocument.COLLECTIONS:
		if collection_name not in TOPOLOGY_COLLECTIONS: extras[String(collection_name)] = content.collection(collection_name).duplicate(true)
	return extras

static func capture_runtime(graph: NetworkGraph, ice_controller: IceController, entry_node_id: StringName, position_resolver: Callable = Callable()) -> NetworkDocument:
	var document := NetworkDocument.new(); document.network_id = &"AUTHORED_NETWORK"; document.display_name = "Authored Network"; document.metadata["entry_node_id"] = entry_node_id
	var node_values: Array = graph.nodes.values(); node_values.sort_custom(func(a, b): return String(a.id) < String(b.id))
	for node: NetworkNodeDefinition in node_values:
		var world_position: Vector3 = position_resolver.call(node.id) if position_resolver.is_valid() else node.authored_position
		document.nodes.append({"id": node.id, "display_name": node.display_name, "type": StringName(NetworkNodeDefinition.NodeType.keys()[node.node_type]), "network_type": node.network_type, "security_family": node.security_family_name(), "difficulty_rating": node.difficulty_rating, "security_level": node.security_level, "owner": node.owner_faction, "authored_position": [world_position.x, world_position.y, world_position.z], "properties": {}})
		for service: NodeServiceDefinition in node.service_definitions:
			var service_record := service.to_record(); service_record["node_id"] = node.id; document.services.append(service_record)
	var link_values: Array = graph.links.values(); link_values.sort_custom(func(a, b): return String(a.id) < String(b.id))
	for link: NetworkLinkDefinition in link_values:
		var directions: Array[Dictionary] = []
		for direction: TraversalDirectionDefinition in link.traversal_directions.values(): directions.append(direction.snapshot())
		directions.sort_custom(func(a, b): return "%s>%s" % [a.source, a.destination] < "%s>%s" % [b.source, b.destination])
		document.paths.append({"id": link.id, "node_a": link.source, "node_b": link.destination, "one_way": link.one_way, "hidden": link.hidden, "locked": link.locked, "disabled": link.disabled, "traversal_cost": link.traversal_cost, "authority_requirement": link.authority_requirement, "directions": directions, "properties": {}})
	var sphere_values: Array = graph.spheres.values(); sphere_values.sort_custom(func(a, b): return String(a.id) < String(b.id))
	for sphere: SphereDefinition in sphere_values:
		var sleeve := graph.get_security_sleeve(sphere.original_security_sleeve_id)
		var sleeve_record := {}
		if sleeve != null: sleeve_record = {"id": sleeve.id, "display_name": sleeve.display_name, "current_members": sleeve.current_members.duplicate(), "state": StringName(SecuritySleeve.State.keys()[sleeve.state]), "security_count": sleeve.security_count, "metadata": sleeve.metadata.duplicate(true)}
		document.spheres.append({"id": sphere.id, "name": sphere.display_name, "node_ids": sphere.node_ids.duplicate(), "security_sleeve": sleeve_record, "metadata": sphere.metadata.duplicate(true)})
	if ice_controller != null:
		var ice_values: Array = ice_controller.instances.values(); ice_values.sort_custom(func(a, b): return String(a.instance_id) < String(b.instance_id))
		for ice: IceInstance in ice_values:
			var definition := {"id": ice.definition.id, "display_name": ice.definition.display_name, "detection_capability": ice.definition.detection_capability, "movement_cost": ice.definition.movement_cost, "scan_capability": ice.definition.scan_capability, "patrol_route": ice.definition.patrol_route.duplicate(), "maximum_integrity": ice.definition.maximum_integrity, "defense": ice.definition.defense, "binding_mode": StringName(IceDefinition.BindingMode.keys()[ice.definition.binding_mode]), "allowed_binding_node_ids": ice.definition.allowed_binding_node_ids.duplicate()}
			var authored_sphere_id := ice.sphere_id
			if authored_sphere_id == &"" and not ice.definition.is_host_bound():
				var host_node := graph.get_node(ice.current_node_id); authored_sphere_id = host_node.sphere_id if host_node != null else &""
			var record := {"id": ice.instance_id, "definition_id": ice.definition.id, "definition": definition, "initial_node_id": ice.current_node_id, "initial_state": StringName(IceState.Value.keys()[ice.state]), "initially_active": ice.operational, "initial_alert_level": ice.alert_level, "sphere_id": authored_sphere_id, "security_sleeve_id": ice.security_sleeve_id}
			(document.stationary_ice if ice.definition.is_host_bound() else document.mobile_ice).append(record)
	return document

func validate() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if format_version != CURRENT_FORMAT_VERSION: issues.append(_issue("FORMAT_VERSION", "Unsupported format version %d." % format_version, "format_version"))
	if network_id == &"": issues.append(_issue("NETWORK_ID", "Network ID is required.", "network_id"))
	var ids := {}; var node_ids := {}; var sphere_ids := {}; var sleeve_ids := {}; var sphere_membership := {}
	for collection_data in [{"name": "nodes", "items": nodes}, {"name": "paths", "items": paths}, {"name": "spheres", "items": spheres}, {"name": "services", "items": services}, {"name": "stationary_ice", "items": stationary_ice}, {"name": "mobile_ice", "items": mobile_ice}]:
		for index in collection_data.items.size():
			var id := StringName(collection_data.items[index].get("id", &"")); var path := "%s[%d].id" % [collection_data.name, index]
			if id == &"": issues.append(_issue("MISSING_ID", "Stable ID is required.", path))
			elif ids.has(id): issues.append(_issue("DUPLICATE_ID", "ID '%s' is used by both %s and %s." % [id, ids[id], path], path))
			else: ids[id] = path
	for node in nodes: node_ids[StringName(node.get("id", &""))] = true
	for sphere in spheres:
		sphere_ids[StringName(sphere.get("id", &""))] = true
		var sleeve: Dictionary = sphere.get("security_sleeve", {})
		if not sleeve.is_empty(): sleeve_ids[StringName(sleeve.get("id", &""))] = true
	for index in paths.size():
		for field in ["node_a", "node_b"]:
			var endpoint := StringName(paths[index].get(field, &"")); if not node_ids.has(endpoint): issues.append(_issue("DANGLING_PATH", "Path endpoint '%s' does not exist." % endpoint, "paths[%d].%s" % [index, field]))
		for direction in paths[index].get("directions", []):
			for controller_field in ["controller_node_id", "remote_controller_node_id"]:
				var controller_id := StringName(direction.get(controller_field, &"")); if controller_id != &"" and not node_ids.has(controller_id): issues.append(_issue("DANGLING_PATH_CONTROLLER", "Path controller '%s' does not exist." % controller_id, "paths[%d].directions.%s" % [index, controller_field]))
	for index in spheres.size():
		for node_value in spheres[index].get("node_ids", []):
			var node_id := StringName(node_value)
			if not node_ids.has(node_id): issues.append(_issue("DANGLING_SPHERE_MEMBER", "Sphere member '%s' does not exist." % node_id, "spheres[%d].node_ids" % index))
			elif sphere_membership.has(node_id): issues.append(_issue("ILLEGAL_SPHERE_MEMBERSHIP", "Node '%s' belongs to multiple spheres." % node_id, "spheres[%d].node_ids" % index))
			else: sphere_membership[node_id] = spheres[index].get("id", &"")
		var sleeve: Dictionary = spheres[index].get("security_sleeve", {})
		for member in sleeve.get("current_members", []):
			if not node_ids.has(StringName(member)): issues.append(_issue("DANGLING_SLEEVE_MEMBER", "Security Sleeve member '%s' does not exist." % member, "spheres[%d].security_sleeve.current_members" % index))
	for index in services.size():
		if not node_ids.has(StringName(services[index].get("node_id", &""))): issues.append(_issue("DANGLING_SERVICE", "Service node does not exist.", "services[%d].node_id" % index))
	for record in stationary_ice + mobile_ice:
		if not node_ids.has(StringName(record.get("initial_node_id", &""))): issues.append(_issue("DANGLING_ICE_START", "ICE start node does not exist.", "ice.%s.initial_node_id" % record.get("id", "?")))
		for patrol_node in record.get("definition", {}).get("patrol_route", []):
			if not node_ids.has(StringName(patrol_node)): issues.append(_issue("DANGLING_ICE_PATROL", "ICE patrol node '%s' does not exist." % patrol_node, "ice.%s.patrol_route" % record.get("id", "?")))
	for record in mobile_ice:
		var sphere_id := StringName(record.get("sphere_id", &"")); var sleeve_id := StringName(record.get("security_sleeve_id", &""))
		if sphere_id == &"" and sleeve_id == &"": issues.append(_issue("MOBILE_ICE_OWNER", "Mobile ICE requires a sphere or Security Sleeve owner.", "mobile_ice.%s" % record.get("id", "?")))
		if sphere_id != &"" and not sphere_ids.has(sphere_id): issues.append(_issue("DANGLING_ICE_SPHERE", "Mobile ICE sphere does not exist.", "mobile_ice.%s.sphere_id" % record.get("id", "?")))
		if sleeve_id != &"" and not sleeve_ids.has(sleeve_id): issues.append(_issue("DANGLING_ICE_SLEEVE", "Mobile ICE sleeve does not exist.", "mobile_ice.%s.security_sleeve_id" % record.get("id", "?")))
	var entry := StringName(metadata.get("entry_node_id", &""))
	if entry == &"" or not node_ids.has(entry): issues.append(_issue("ENTRY_REQUIRED", "A valid metadata.entry_node_id is required.", "metadata.entry_node_id"))
	return issues

func to_content_document() -> CyberspaceContentDocument:
	var content := CyberspaceContentDocument.new(); content.document_id = network_id; content.title = display_name
	_apply_content_extras(content)
	for item in spheres:
		content.spheres.append({"id": item.get("id", &""), "display_name": item.get("name", item.get("display_name", "Sphere")), "node_ids": item.get("node_ids", []).duplicate(), "original_security_sleeve_id": item.get("security_sleeve", {}).get("id", &""), "metadata": item.get("metadata", {}).duplicate(true)})
	for sphere in spheres:
		var sleeve: Dictionary = sphere.get("security_sleeve", {})
		if not sleeve.is_empty(): content.security_sleeves.append(sleeve.duplicate(true))
	for node in nodes:
		var record := node.duplicate(true); record["node_type"] = record.get("type", &"SYSTEM"); record["sphere_id"] = _sphere_for_node(StringName(record.get("id", &""))); record["services"] = services.filter(func(service): return StringName(service.get("node_id", &"")) == StringName(record.id)).map(func(service): return service.get("id", &""))
		var tags: Array = record.get("tags", []).duplicate(); if StringName(record.id) == StringName(metadata.get("entry_node_id", &"")) and not tags.has(&"ENTRY"): tags.append(&"ENTRY"); record["tags"] = tags
		content.network_nodes.append(record)
	for path in paths:
		var record := path.duplicate(true); record["source"] = record.get("node_a", &""); record["destination"] = record.get("node_b", &""); content.network_links.append(record)
	for service in services: content.services.append(service.duplicate(true))
	var definitions := {}
	for ice in stationary_ice + mobile_ice:
		var definition: Dictionary = ice.get("definition", {})
		if not definition.is_empty(): definitions[StringName(definition.get("id", &""))] = definition
		var instance := ice.duplicate(true); instance.erase("definition"); instance["definition_id"] = definition.get("id", instance.get("definition_id", &"")); content.ice_instances.append(instance)
	content.ice_definitions.assign(definitions.values())
	return content

func _apply_content_extras(content: CyberspaceContentDocument) -> void:
	for property_name in story_metadata:
		if property_name in ["document_id", "title"] or not _has_property(content, String(property_name)): continue
		var value: Variant = story_metadata[property_name]
		var destination: Variant = content.get(String(property_name))
		# JSON deserialization yields untyped Arrays. Assign into the resource's
		# exported typed collection so Godot performs the required element coercion.
		if destination is Array and value is Array:
			destination.assign(value)
			content.set(String(property_name), destination)
		else:
			content.set(String(property_name), value.duplicate(true) if value is Dictionary else value)

func _has_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if String(property.get("name", "")) == property_name: return true
	return false

func _sphere_for_node(node_id: StringName) -> StringName:
	for sphere in spheres:
		if node_id in sphere.get("node_ids", []): return StringName(sphere.get("id", &""))
	return &""

static func _issue(code: String, message: String, path: String) -> Dictionary:
	return {"severity": "ERROR", "code": code, "message": message, "path": path}
