class_name SetNodeTypeCommand
extends NetworkAuthorCommand

var node_id: StringName
var next_type: NetworkNodeDefinition.NodeType
var previous_type: NetworkNodeDefinition.NodeType

func _init(p_context: Dictionary = {}, p_node_id: StringName = &"", p_type := NetworkNodeDefinition.NodeType.ROUTER) -> void:
	super(p_context); node_id = p_node_id; next_type = p_type

func execute() -> Dictionary:
	var node := graph().get_node(node_id) if graph() != null else null
	if node == null: return {"success": false, "reason": "Node not found"}
	previous_type = node.node_type; node.node_type = next_type
	graph().display_update_requested.emit()
	result = {"success": true, "reason": "Node type changed", "node_id": node_id}
	return result

func undo() -> Dictionary:
	var node := graph().get_node(node_id) if graph() != null else null
	if node == null: return {"success": false, "reason": "Node not found"}
	node.node_type = previous_type; graph().display_update_requested.emit()
	return {"success": true, "reason": "Node type restored"}
