class_name AuthoredIceFactory
extends RefCounted


static func create_definition(data: Dictionary) -> IceDefinition:
	if StringName(data.get("id", &"")).is_empty():
		return null
	var patrol: Array[StringName] = []
	patrol.assign(data.get("patrol_route", []))
	return IceDefinition.new(
		data.id,
		String(data.get("display_name", data.id)),
		int(data.get("detection_capability", 1)),
		int(data.get("movement_cost", 1)),
		int(data.get("scan_capability", 1)),
		patrol,
		int(data.get("maximum_integrity", 8)),
		int(data.get("defense", 1))
	)


static func create_instance(data: Dictionary, definitions: Dictionary) -> IceInstance:
	var definition := definitions.get(data.get("definition_id", &"")) as IceDefinition
	if definition == null or StringName(data.get("id", &"")).is_empty():
		return null
	var state_name := StringName(data.get("initial_state", &"DORMANT"))
	var state_value := IceState.Value.DORMANT
	for candidate: int in IceState.Value.values():
		if StringName(IceState.label(candidate)) == state_name:
			state_value = candidate
			break
	var instance := IceInstance.new(data.id, definition, data.get("initial_node_id", &""), state_value)
	instance.operational = bool(data.get("initially_active", true))
	instance.alert_level = clampi(int(data.get("initial_alert_level", 0)), 0, 100)
	return instance


static func populate(controller: IceController, definition_entries: Array[Dictionary], instance_entries: Array[Dictionary]) -> Dictionary:
	var definitions: Dictionary = {}
	for entry: Dictionary in definition_entries:
		var definition := create_definition(entry)
		if definition != null:
			definitions[definition.id] = definition
	var instances: Dictionary = {}
	for entry: Dictionary in instance_entries:
		var instance := create_instance(entry, definitions)
		if instance != null and controller.add_ice(instance):
			instances[instance.instance_id] = instance
	return {"definitions": definitions, "instances": instances}
