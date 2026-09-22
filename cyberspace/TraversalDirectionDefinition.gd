class_name TraversalDirectionDefinition
extends RefCounted

enum State { HIDDEN, DISCOVERED, LOCKED, UNLOCKED, LOCKED_DOWN }
enum GateType { NONE, HARD, SOFT }

var source_node_id: StringName
var destination_node_id: StringName
var controller_node_id: StringName
var state: State
var unlock_requirements: Dictionary = {}
var security_consequences: Dictionary = {}
var controlling_ice_id: StringName
var remote_controller_node_id: StringName
var allow_circular_remote_gate := false
var gate_type := GateType.NONE
var controlling_security: Dictionary = {}
var security_resolved := false
var on_unauthorized_traversal: Array[Dictionary] = []
var blocked_reason := "OUTBOUND PATH LOCKED"

func _init(p_source: StringName, p_destination: StringName, p_state := State.UNLOCKED, p_controller: StringName = &"") -> void:
	source_node_id = p_source
	destination_node_id = p_destination
	controller_node_id = p_controller if p_controller != &"" else p_source
	state = p_state

func is_discovered() -> bool:
	return state != State.HIDDEN

func is_traversable() -> bool:
	return state == State.UNLOCKED

func state_name() -> StringName:
	return StringName(State.keys()[state])

func apply_authored(data: Dictionary) -> void:
	controller_node_id = data.get("controller_node_id", data.get("controller", controller_node_id))
	remote_controller_node_id = data.get("remote_controller_node_id", data.get("remote_controller", &""))
	allow_circular_remote_gate = bool(data.get("allow_circular_remote_gate", false))
	var authored_gate := StringName(String(data.get("gate_type", &"NONE")).to_upper())
	if authored_gate in GateType.keys(): gate_type = GateType[authored_gate]
	controlling_security = (data.get("controlling_security", {}) as Dictionary).duplicate(true)
	security_resolved = bool(data.get("security_resolved", gate_type == GateType.NONE))
	on_unauthorized_traversal.assign(data.get("on_unauthorized_traversal", []))
	controlling_ice_id = data.get("controlling_ice_id", &"")
	unlock_requirements = (data.get("unlock_requirements", {}) as Dictionary).duplicate(true)
	security_consequences = (data.get("security_consequences", {}) as Dictionary).duplicate(true)
	blocked_reason = data.get("blocked_reason", blocked_reason)
	var authored_state := StringName(String(data.get("state", state_name())).to_upper())
	if authored_state in State.keys(): state = State[authored_state]

func snapshot() -> Dictionary:
	return {"source": source_node_id, "destination": destination_node_id, "controller_node_id": controller_node_id, "state": state_name(), "gate_type": StringName(GateType.keys()[gate_type]), "controlling_security": controlling_security.duplicate(true), "security_resolved": security_resolved, "on_unauthorized_traversal": on_unauthorized_traversal.duplicate(true), "unlock_requirements": unlock_requirements.duplicate(true), "security_consequences": security_consequences.duplicate(true), "controlling_ice_id": controlling_ice_id, "remote_controller_node_id": remote_controller_node_id, "allow_circular_remote_gate": allow_circular_remote_gate, "blocked_reason": blocked_reason}
