class_name CyberspaceContentDocument
extends Resource

const SCHEMA_VERSION := 4
const COLLECTIONS: Array[StringName] = [
	&"spheres", &"security_sleeves", &"network_nodes", &"network_links", &"services", &"graffiti", &"flavor_text",
	&"story_hooks", &"story_bundles", &"story_variables", &"meatspace_locations",
	&"realtime_endpoints", &"physical_devices", &"comms_channels", &"comms_sessions",
	&"comms_participants", &"video_feeds", &"alarms", &"physical_teams",
	&"team_operations", &"equipment", &"vendors", &"equipment_orders", &"realtime_events",
	&"program_definitions", &"rewards", &"hidden_caches", &"objectives", &"meatspace_interactions",
	&"hacker_npcs",
	&"story_sequences",
	&"ice_definitions", &"ice_instances",
	&"realtime_processes",
	&"hacker_reactions",
	&"tutorial_guidance_rules",
]

@export var schema_version: int = SCHEMA_VERSION
@export var document_id: StringName = &"UNTITLED"
@export var title: String = "Untitled Cyberspace Content"
@export_multiline var summary: String
@export var tags: Array[StringName] = []
@export_enum("AVAILABLE_IN_ALL_MODES", "STORY_ONLY", "FREE_ROAM_ONLY", "MODE_SPECIFIC_VARIANT") var availability: String = "AVAILABLE_IN_ALL_MODES"
@export var mode_variants: Dictionary = {}
@export var hud_guidance: Dictionary = {}

@export var network_nodes: Array[Dictionary] = []
@export var network_links: Array[Dictionary] = []
@export var spheres: Array[Dictionary] = []
@export var security_sleeves: Array[Dictionary] = []
@export var services: Array[Dictionary] = []
@export var graffiti: Array[Dictionary] = []
@export var flavor_text: Array[Dictionary] = []
@export var story_hooks: Array[Dictionary] = []
@export var story_bundles: Array[Dictionary] = []
@export var story_variables: Array[Dictionary] = []
@export var meatspace_locations: Array[Dictionary] = []
@export var realtime_endpoints: Array[Dictionary] = []
@export var physical_devices: Array[Dictionary] = []
@export var comms_channels: Array[Dictionary] = []
@export var comms_sessions: Array[Dictionary] = []
@export var comms_participants: Array[Dictionary] = []
@export var video_feeds: Array[Dictionary] = []
@export var alarms: Array[Dictionary] = []
@export var physical_teams: Array[Dictionary] = []
@export var team_operations: Array[Dictionary] = []
@export var equipment: Array[Dictionary] = []
@export var vendors: Array[Dictionary] = []
@export var equipment_orders: Array[Dictionary] = []
@export var realtime_events: Array[Dictionary] = []
@export var program_definitions: Array[Dictionary] = []
@export var rewards: Array[Dictionary] = []
@export var hidden_caches: Array[Dictionary] = []
@export var objectives: Array[Dictionary] = []
@export var meatspace_interactions: Array[Dictionary] = []
@export var hacker_npcs: Array[Dictionary] = []
@export var story_sequences: Array[Dictionary] = []
@export var ice_definitions: Array[Dictionary] = []
@export var ice_instances: Array[Dictionary] = []
@export var realtime_processes: Array[Dictionary] = []
@export var hacker_reactions: Array[Dictionary] = []
@export var tutorial_guidance_rules: Array[Dictionary] = []


func collection(name: StringName) -> Array[Dictionary]:
	var value: Variant = get(String(name))
	return value if value is Array else []


func add_entry(collection_name: StringName, entry: Dictionary) -> bool:
	if collection_name not in COLLECTIONS or StringName(entry.get("id", &"")) == &"":
		return false
	var items := collection(collection_name)
	if find_entry(StringName(entry.id)) != {}:
		return false
	items.append(entry.duplicate(true))
	set(String(collection_name), items)
	emit_changed()
	return true


func remove_entry(entry_id: StringName) -> bool:
	for collection_name: StringName in COLLECTIONS:
		var items := collection(collection_name)
		for index in items.size():
			if StringName(items[index].get("id", &"")) == entry_id:
				items.remove_at(index)
				set(String(collection_name), items)
				emit_changed()
				return true
	return false


func update_entry(entry_id: StringName, patch: Dictionary) -> bool:
	for collection_name: StringName in COLLECTIONS:
		var items := collection(collection_name)
		for index in items.size():
			if StringName(items[index].get("id", &"")) == entry_id:
				var updated := items[index].duplicate(true)
				updated.merge(patch, true)
				items[index] = updated
				set(String(collection_name), items)
				emit_changed()
				return true
	return false


func find_entry(entry_id: StringName) -> Dictionary:
	for collection_name: StringName in COLLECTIONS:
		for entry: Dictionary in collection(collection_name):
			if StringName(entry.get("id", &"")) == entry_id:
				var result := entry.duplicate(true)
				result["_collection"] = collection_name
				return result
	return {}


func all_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for collection_name: StringName in COLLECTIONS:
		for entry: Dictionary in collection(collection_name):
			var view := entry.duplicate(true)
			view["_collection"] = collection_name
			result.append(view)
	return result


func sphere_members(sphere_id: StringName) -> Array[StringName]:
	## Node sphere_id is the sole authoring source of truth. Sphere node_ids is
	## accepted only as legacy input and is never required to be edited.
	var result: Array[StringName] = []
	for node: Dictionary in network_nodes:
		if StringName(node.get("sphere_id", &"")) == sphere_id:
			result.append(StringName(node.get("id", &"")))
	result.sort()
	return result


func assign_node_to_sphere(node_id: StringName, sphere_id: StringName) -> bool:
	if sphere_id != &"" and not spheres.any(func(sphere: Dictionary): return StringName(sphere.get("id", &"")) == sphere_id):
		return false
	return update_entry(node_id, {"sphere_id": sphere_id})


func sphere_connections(sphere_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var node_spheres := {}
	for node: Dictionary in network_nodes:
		node_spheres[StringName(node.get("id", &""))] = StringName(node.get("sphere_id", &""))
	for link: Dictionary in network_links:
		var source_sphere: StringName = node_spheres.get(StringName(link.get("source", &"")), &"")
		var destination_sphere: StringName = node_spheres.get(StringName(link.get("destination", &"")), &"")
		if source_sphere == destination_sphere: continue
		if source_sphere == sphere_id or destination_sphere == sphere_id:
			var view := link.duplicate(true)
			view["source_sphere_id"] = source_sphere
			view["destination_sphere_id"] = destination_sphere
			result.append(view)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.get("id", &"")) < String(b.get("id", &"")))
	return result
