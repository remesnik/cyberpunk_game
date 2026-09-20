class_name NetworkLinkDefinition
extends RefCounted

enum TraversalGateType { NONE, BLOCK_EXIT_UNTIL_RESOLVED, BLOCK_ENTRY_UNTIL_REQUIREMENT, ONE_WAY, SCRIPTED }

var id: StringName
var source: StringName
var destination: StringName
var one_way: bool
var hidden: bool
var locked: bool
var disabled: bool
var discovered: bool
var traversal_cost: int
var authority_requirement: int
var capability_requirement: StringName
var required_capabilities_all: Array[StringName] = []
var required_capabilities_any: Array[StringName] = []
var accepted_credentials: Array[StringName] = []
var recommended_capabilities: Array[StringName] = []
var traversal_gate_type := TraversalGateType.NONE
var traversal_requirement: Dictionary = {}
var blocked_reason := "ACCESS REQUIREMENT NOT MET"
var traversal_directions: Dictionary = {}

func _init(p_id: StringName, p_source: StringName, p_destination: StringName, p_one_way := false, p_hidden := false, p_locked := false, p_disabled := false, p_discovered := true, p_traversal_cost := 1, p_authority_requirement := 0, p_capability_requirement: StringName = &"") -> void:
	id = p_id
	source = p_source
	destination = p_destination
	one_way = p_one_way
	hidden = p_hidden
	locked = p_locked
	disabled = p_disabled
	discovered = p_discovered
	traversal_cost = maxi(p_traversal_cost, 0)
	authority_requirement = maxi(p_authority_requirement, 0)
	capability_requirement = p_capability_requirement
	if capability_requirement != &"":
		required_capabilities_all.append(capability_requirement)
	# Legacy links migrate to independent directions while retaining their old
	# availability. New authored content can override these records explicitly.
	var initial_state := TraversalDirectionDefinition.State.HIDDEN if hidden and not discovered else (TraversalDirectionDefinition.State.LOCKED if locked else TraversalDirectionDefinition.State.UNLOCKED)
	set_direction(TraversalDirectionDefinition.new(source, destination, initial_state, source))
	if not one_way:
		set_direction(TraversalDirectionDefinition.new(destination, source, initial_state, destination))

func direction_key(from_node_id: StringName, to_node_id: StringName) -> StringName:
	return StringName("%s->%s" % [from_node_id, to_node_id])

func set_direction(direction: TraversalDirectionDefinition) -> void:
	traversal_directions[direction_key(direction.source_node_id, direction.destination_node_id)] = direction

func get_direction(from_node_id: StringName, to_node_id: StringName) -> TraversalDirectionDefinition:
	return traversal_directions.get(direction_key(from_node_id, to_node_id)) as TraversalDirectionDefinition

func configure_direction(from_node_id: StringName, to_node_id: StringName, data: Dictionary) -> TraversalDirectionDefinition:
	var direction := get_direction(from_node_id, to_node_id)
	if direction == null:
		direction = TraversalDirectionDefinition.new(from_node_id, to_node_id)
		set_direction(direction)
	direction.apply_authored(data)
	return direction

func connects_from(node_id: StringName) -> bool:
	if one_way and node_id == destination: return false
	return get_direction(node_id, destination_from_legacy(node_id)) != null

func destination_from_legacy(node_id: StringName) -> StringName:
	if source == node_id: return destination
	if destination == node_id: return source
	return &""

func destination_from(node_id: StringName) -> StringName:
	if one_way and node_id == destination: return &""
	var other := destination_from_legacy(node_id)
	if other != &"" and get_direction(node_id, other) != null: return other
	return &""

func is_visible() -> bool:
	return not hidden or discovered

func access_requirements_met(capabilities: Array[StringName], credentials: Array[StringName]) -> bool:
	for requirement in required_capabilities_all:
		if not capabilities.has(requirement):
			return false
	if required_capabilities_any.is_empty() and accepted_credentials.is_empty():
		return true
	for requirement in required_capabilities_any:
		if capabilities.has(requirement):
			return true
	for credential in accepted_credentials:
		if credentials.has(credential):
			return true
	return false

func gate_applies(from_node_id: StringName, to_node_id: StringName) -> bool:
	if traversal_gate_type == TraversalGateType.NONE: return false
	# Authored source -> destination is the progression direction. Reverse travel
	# remains a retreat path unless the author creates a second directed gate.
	return source == from_node_id and destination == to_node_id
