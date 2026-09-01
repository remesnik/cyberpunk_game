class_name CyberspaceContentDocument
extends Resource

const SCHEMA_VERSION := 1
const COLLECTIONS: Array[StringName] = [
	&"network_nodes", &"network_links", &"services", &"graffiti", &"flavor_text",
	&"story_hooks", &"story_bundles", &"story_variables", &"meatspace_locations",
	&"realtime_endpoints", &"physical_devices", &"comms_channels", &"comms_sessions",
	&"comms_participants", &"video_feeds", &"alarms", &"physical_teams",
	&"team_operations", &"equipment", &"vendors", &"equipment_orders", &"realtime_events",
]

@export var schema_version: int = SCHEMA_VERSION
@export var document_id: StringName = &"UNTITLED"
@export var title: String = "Untitled Cyberspace Content"
@export_multiline var summary: String
@export var tags: Array[StringName] = []

@export var network_nodes: Array[Dictionary] = []
@export var network_links: Array[Dictionary] = []
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

