class_name ConfigureServiceCommand
extends NetworkAuthorCommand

var service: NodeServiceDefinition
var changes: Dictionary
var previous: Dictionary

func _init(p_context := {}, p_service: NodeServiceDefinition = null, p_changes := {}) -> void:
	super(p_context); service = p_service; changes = p_changes.duplicate(true)

func execute() -> Dictionary:
	if service == null: return {"success": false, "reason": "Service not found"}
	previous = {"display_name": service.display_name, "service_type": service.service_type, "security_level": service.security_level}
	_apply(changes); _sync_record(); return {"success": true, "reason": "Service configured", "service_id": service.id}

func undo() -> Dictionary:
	if service == null: return {"success": false, "reason": "Service not found"}
	_apply(previous); _sync_record(); return {"success": true, "reason": "Service configuration restored"}

func _apply(values: Dictionary) -> void:
	service.display_name = String(values.get("display_name", service.display_name))
	service.service_type = NodeServiceCatalog.normalize(values.get("service_type", service.service_type))
	service.security_level = maxi(0, int(values.get("security_level", service.security_level)))
	service.supported_operations = NodeServiceCatalog.default_operations(service.service_type)

func _sync_record() -> void:
	for node: NetworkNodeDefinition in graph().nodes.values():
		if not node.service_definitions.has(service): continue
		for index in node.services.size():
			if StringName(node.services[index].get("id", &"")) == service.id:
				node.services[index] = service.to_record(); graph().display_update_requested.emit(); return
		# Keep legacy record and typed definition collections synchronized even if
		# older runtime content arrived without a parallel record.
		node.services.append(service.to_record()); graph().display_update_requested.emit(); return
