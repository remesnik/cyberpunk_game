class_name PlayerNetworkPosition
extends RefCounted

signal transition_started(from_node_id: StringName, to_node_id: StringName, link_id: StringName)
signal transition_completed(from_node_id: StringName, to_node_id: StringName, link_id: StringName)

var current_node_id: StringName
var previous_node_id: StringName = &""
var is_transitioning := false
var transition_destination_id: StringName = &""
var transition_link_id: StringName = &""
var traversal_history: Array[StringName] = []
var traversal_points: int
var total_traversal_cost_spent := 0
var authority_level := 0
var capabilities: Array[StringName] = []
var credentials: Array[StringName] = []
var scan_capability := 1

func _init(starting_node_id: StringName, starting_traversal_points := 0) -> void:
	current_node_id = starting_node_id
	traversal_points = maxi(starting_traversal_points, 0)
	traversal_history.append(starting_node_id)

func can_afford(cost: int) -> bool:
	return traversal_points >= cost

func spend_traversal_cost(cost: int) -> bool:
	if cost < 0 or not can_afford(cost):
		return false
	traversal_points -= cost
	total_traversal_cost_spent += cost
	return true

func has_capability(capability: StringName) -> bool:
	return capability == &"" or capabilities.has(capability)

func grant_capability(capability: StringName) -> bool:
	if capability == &"" or capabilities.has(capability):
		return false
	capabilities.append(capability)
	capabilities.sort()
	return true

func has_credential(credential: StringName) -> bool:
	return credential != &"" and credentials.has(credential)

func begin_transition(destination_node_id: StringName, link_id: StringName) -> bool:
	if is_transitioning:
		return false
	is_transitioning = true
	transition_destination_id = destination_node_id
	transition_link_id = link_id
	transition_started.emit(current_node_id, destination_node_id, link_id)
	return true

func complete_transition() -> void:
	assert(is_transitioning, "Cannot complete a transition that has not started.")
	var origin := current_node_id
	previous_node_id = origin
	current_node_id = transition_destination_id
	traversal_history.append(current_node_id)
	var completed_link_id := transition_link_id
	is_transitioning = false
	transition_destination_id = &""
	transition_link_id = &""
	transition_completed.emit(origin, current_node_id, completed_link_id)

func relocate(node_id: StringName) -> void:
	if node_id == current_node_id:
		return
	previous_node_id = current_node_id
	current_node_id = node_id
	is_transitioning = false
	transition_destination_id = &""
	transition_link_id = &""
	traversal_history.append(node_id)
