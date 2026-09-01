class_name CrashCache
extends RefCounted

var active := false
var node_id: StringName = &""
var resources: Dictionary = {}
var created_at_tick := 0

func create_at(p_node_id: StringName, p_resources: Dictionary, tick: int) -> void:
	active = true
	node_id = p_node_id
	resources = p_resources.duplicate(true)
	created_at_tick = tick

func clear() -> void:
	active = false
	node_id = &""
	resources.clear()
	created_at_tick = 0
