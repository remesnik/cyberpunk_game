class_name RemoveServiceCommand
extends NetworkAuthorCommand

var node_id: StringName
var service_id: StringName
var removed: NodeServiceDefinition

func _init(p_context := {}, p_node_id: StringName = &"", p_service_id: StringName = &"") -> void:
	super(p_context); node_id = p_node_id; service_id = p_service_id

func execute() -> Dictionary:
	var node := graph().get_node(node_id) if graph() != null else null
	if node == null: return {"success": false, "reason": "Node not found"}
	for item: NodeServiceDefinition in node.service_definitions:
		if item.id == service_id: removed = item; break
	if removed == null: return {"success": false, "reason": "Service not found"}
	node.service_definitions.erase(removed); node.services = node.services.filter(func(item): return StringName(item.get("id", &"")) != service_id)
	graph().display_update_requested.emit(); return {"success": true, "reason": "Service removed", "service_id": service_id}

func undo() -> Dictionary:
	var node := graph().get_node(node_id) if graph() != null else null
	if node == null or removed == null: return {"success": false, "reason": "Could not restore service"}
	node.service_definitions.append(removed); node.services.append(removed.to_record()); graph().display_update_requested.emit(); return {"success": true, "reason": "Service restored"}
