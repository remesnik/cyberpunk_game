class_name ShortcutController
extends RefCounted

signal shortcut_activated(shortcut_id: StringName, link_id: StringName)

var graph: NetworkGraph
var definitions: Dictionary = {}
var active_shortcut_ids: Array[StringName] = []

func _init(p_graph: NetworkGraph) -> void:
	graph = p_graph

func register_shortcut(definition: ShortcutDefinition) -> bool:
	if definition.id == &"" or definitions.has(definition.id) or graph.get_link(definition.link_id) == null:
		return false
	definitions[definition.id] = definition
	return true

func activate(shortcut_id: StringName, position: PlayerNetworkPosition, knowledge: PlayerKnowledge) -> bool:
	if not definitions.has(shortcut_id):
		return false
	if active_shortcut_ids.has(shortcut_id):
		return true
	var definition := definitions[shortcut_id] as ShortcutDefinition
	var link := graph.get_link(definition.link_id)
	link.disabled = false
	link.locked = false
	link.traversal_cost = mini(link.traversal_cost, definition.reduced_traversal_cost)
	if definition.credential_granted != &"" and not position.credentials.has(definition.credential_granted):
		position.credentials.append(definition.credential_granted)
	knowledge.reveal_link(link, KnowledgeLevel.Value.SCANNED)
	active_shortcut_ids.append(shortcut_id)
	active_shortcut_ids.sort()
	shortcut_activated.emit(shortcut_id, definition.link_id)
	return true
