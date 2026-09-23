class_name AddNodeCommand
extends NetworkAuthorCommand

var source_node_id: StringName
var node: NetworkNodeDefinition
var link: NetworkLinkDefinition

func _init(p_context: Dictionary = {}, p_source_node_id: StringName = &"", p_node: NetworkNodeDefinition = null, p_link: NetworkLinkDefinition = null) -> void:
	super(p_context); source_node_id = p_source_node_id; node = p_node; link = p_link

func execute() -> Dictionary:
	var live_graph := graph()
	if live_graph == null or live_graph.get_node(source_node_id) == null or node == null or link == null: return {"success": false, "reason": "Invalid connected-node command"}
	if not live_graph.add_node(node): return {"success": false, "reason": "Could not add node"}
	if not live_graph.add_link(link):
		live_graph.remove_node(node.id)
		return {"success": false, "reason": "Could not connect new node"}
	result = {"success": true, "reason": "Connected node added", "node_id": node.id, "path_id": link.id}
	return result

func undo() -> Dictionary:
	var live_graph := graph()
	if live_graph == null: return {"success": false, "reason": "Graph unavailable"}
	live_graph.remove_link(link.id)
	var removed := live_graph.remove_node(node.id)
	return {"success": removed != null, "reason": "Connected node removed" if removed != null else "Could not remove node"}
