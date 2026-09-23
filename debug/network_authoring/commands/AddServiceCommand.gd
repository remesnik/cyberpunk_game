class_name AddServiceCommand
extends NetworkAuthorCommand

var node_id: StringName
var service: NodeServiceDefinition

func _init(p_context := {}, p_node_id: StringName = &"", p_service: NodeServiceDefinition = null) -> void:
	super(p_context); node_id = p_node_id; service = p_service

func execute() -> Dictionary:
	var node := graph().get_node(node_id) if graph() != null else null
	if node == null or service == null or node.service_definitions.any(func(item): return item.id == service.id): return {"success": false, "reason": "Could not add service"}
	node.service_definitions.append(service); node.services.append(service.to_record()); graph().display_update_requested.emit()
	return {"success": true, "reason": "Service added", "service_id": service.id}

func undo() -> Dictionary:
	var node := graph().get_node(node_id) if graph() != null else null
	if node == null: return {"success": false, "reason": "Node not found"}
	node.service_definitions = node.service_definitions.filter(func(item): return item.id != service.id)
	node.services = node.services.filter(func(item): return StringName(item.get("id", &"")) != service.id)
	graph().display_update_requested.emit(); return {"success": true, "reason": "Service removed"}
