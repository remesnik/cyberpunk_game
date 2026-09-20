class_name NodePathControl
extends RefCounted

enum Scope { SPECIFIC, ALL_NORMAL }

var id: StringName
var interaction: StringName
var subject_id: StringName
var scope := Scope.SPECIFIC
var destination_node_ids: Array[StringName] = []
var link_ids: Array[StringName] = []
var resulting_state := TraversalDirectionDefinition.State.UNLOCKED
var once := true
var activated := false

func _init(p_id: StringName = &"", p_interaction: StringName = &"") -> void:
	id = p_id
	interaction = p_interaction

static func from_authored(data: Dictionary) -> NodePathControl:
	var control := NodePathControl.new(data.get("id", &""), data.get("interaction", data.get("trigger", &"")))
	control.subject_id = data.get("subject_id", data.get("target_id", &""))
	control.scope = Scope.ALL_NORMAL if StringName(String(data.get("scope", &"SPECIFIC")).to_upper()) == &"ALL_NORMAL" else Scope.SPECIFIC
	control.destination_node_ids.assign(data.get("destinations", data.get("destination_node_ids", [])))
	control.link_ids.assign(data.get("link_ids", []))
	var state_name := StringName(String(data.get("resulting_state", &"UNLOCKED")).to_upper())
	if state_name in TraversalDirectionDefinition.State.keys(): control.resulting_state = TraversalDirectionDefinition.State[state_name]
	control.once = bool(data.get("once", true))
	return control

func matches(p_interaction: StringName, context: Dictionary) -> bool:
	if interaction != p_interaction or once and activated: return false
	if subject_id == &"": return true
	for key in [&"subject_id", &"target_id", &"service_id", &"ice_id", &"objective_id", &"stream_id", &"file_id", &"resource_id", &"id"]:
		if StringName(context.get(key, &"")) == subject_id: return true
	return false

func selects(link: NetworkLinkDefinition, destination_id: StringName) -> bool:
	return scope == Scope.ALL_NORMAL or link.id in link_ids or destination_id in destination_node_ids
