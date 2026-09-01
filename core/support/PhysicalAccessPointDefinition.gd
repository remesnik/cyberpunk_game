class_name PhysicalAccessPointDefinition
extends RefCounted

var id: StringName
var display_name: String
var physical_location_id: StringName
var control_node_id: StringName
var control_service_id: StringName
var initially_locked := true
var force_entry_seconds := 8.0
var force_entry_suspicion := 35
var story_tags: Array[StringName] = []


func _init(access_id: StringName = &"", name: String = "", location_id: StringName = &"", node_id: StringName = &"", service_id: StringName = &"") -> void:
	id = access_id
	display_name = name
	physical_location_id = location_id
	control_node_id = node_id
	control_service_id = service_id

