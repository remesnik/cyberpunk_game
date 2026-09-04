class_name SecuritySleeve
extends RefCounted

enum State { INTACT, BREACHED, SPLIT, BYPASSED, DISABLED }

var id: StringName = &""
var display_name := "Security Sleeve"
var current_members: Array[StringName] = []
var state := State.INTACT
var metadata: Dictionary = {}

func _init(p_id: StringName = &"", p_display_name := "Security Sleeve", p_current_members: Array[StringName] = [], p_state := State.INTACT) -> void:
	id = p_id
	display_name = p_display_name
	current_members = p_current_members.duplicate()
	state = p_state

func contains_node(node_id: StringName) -> bool:
	return current_members.has(node_id)

func add_current_member(node_id: StringName) -> bool:
	if node_id == &"" or current_members.has(node_id): return false
	current_members.append(node_id)
	current_members.sort()
	return true

func remove_current_member(node_id: StringName) -> bool:
	if not current_members.has(node_id): return false
	current_members.erase(node_id)
	return true

func set_state(next_state: State) -> void:
	state = next_state
