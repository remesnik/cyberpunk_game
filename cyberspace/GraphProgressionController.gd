class_name GraphProgressionController
extends RefCounted

signal capability_acquired(capability_id: StringName, node_id: StringName)

var graph: NetworkGraph
var position: PlayerNetworkPosition
var knowledge: PlayerKnowledge
var shortcut_reveals: Dictionary = {}

func _init(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge) -> void:
	graph = p_graph
	position = p_position
	knowledge = p_knowledge

func register_shortcut_reveal(node_id: StringName, link_id: StringName) -> void:
	if not shortcut_reveals.has(node_id):
		shortcut_reveals[node_id] = []
	shortcut_reveals[node_id].append(link_id)

func on_node_entered(node_id: StringName) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var node := graph.get_node(node_id)
	if node == null:
		return events
	for capability_id in node.granted_capability_ids:
		if position.grant_capability(capability_id):
			capability_acquired.emit(capability_id, node_id)
			events.append({"type": &"CAPABILITY_ACQUIRED", "capability_id": capability_id, "node_id": node_id})
	for link_id in shortcut_reveals.get(node_id, []):
		var link := graph.get_link(link_id)
		if link != null:
			knowledge.reveal_link(link, KnowledgeLevel.Value.IDENTIFIED)
			var destination_id := link.destination_from(node_id)
			if destination_id != &"":
				knowledge.reveal_node(graph.get_node(destination_id), KnowledgeLevel.Value.IDENTIFIED)
			events.append({"type": &"SHORTCUT_REVEALED", "link_id": link_id})
	return events
