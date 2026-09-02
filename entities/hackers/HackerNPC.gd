class_name HackerNPC
extends RefCounted

enum State { OFFLINE, CONNECTED, HIDDEN, DISCONNECTED }

var instance_id: StringName
var definition: HackerNPCDefinition
var current_node_id: StringName
var previous_node_id: StringName
var state: State = State.OFFLINE
var visible_signature := false
var movement_history: Array[StringName] = []
var metadata: Dictionary = {}


func _init(p_instance_id: StringName, p_definition: HackerNPCDefinition, p_node_id: StringName = &"") -> void:
	instance_id = p_instance_id
	definition = p_definition
	current_node_id = p_node_id
	if not p_node_id.is_empty(): movement_history.append(p_node_id)


func is_network_connected() -> bool:
	return state in [State.CONNECTED, State.HIDDEN]


func state_label() -> String:
	return State.keys()[state]
