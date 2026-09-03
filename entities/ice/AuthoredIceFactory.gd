class_name AuthoredIceFactory
extends RefCounted

const IceBindingProfileScript := preload("res://entities/ice/IceBindingProfile.gd")


static func create_definition(data: Dictionary) -> IceDefinition:
	if StringName(data.get("id", &"")).is_empty():
		return null
	var patrol: Array[StringName] = []
	patrol.assign(data.get("patrol_route", []))
	var definition := IceDefinition.new(
		data.id,
		String(data.get("display_name", data.id)),
		int(data.get("detection_capability", 1)),
		int(data.get("movement_cost", 1)),
		int(data.get("scan_capability", 1)),
		patrol,
		int(data.get("maximum_integrity", 8)),
		int(data.get("defense", 1))
	)
	var tracking: Dictionary = data.get("trail_tracking", {})
	definition.trail_tracking.enabled = bool(tracking.get("enabled", false))
	definition.trail_tracking.detection_threshold = maxf(0.0, float(tracking.get("detection_threshold", 0.5)))
	definition.trail_tracking.max_age = maxi(0, int(tracking.get("max_age", 8)))
	definition.trail_tracking.tracking_quality = maxf(0.0, float(tracking.get("tracking_quality", 1.0)))
	definition.trail_tracking.memory_ticks = maxi(0, int(tracking.get("memory_ticks", 3)))
	var san_attack: Dictionary = data.get("san_attack", {})
	definition.san_attack.san_attack_enabled = bool(san_attack.get("enabled", false))
	definition.san_attack.deck_attack_enabled = bool(san_attack.get("deck_attack_enabled", false))
	definition.san_attack.action_interval = maxi(1, int(san_attack.get("action_interval", 1)))
	definition.san_attack.integrity_damage = maxi(0, int(san_attack.get("integrity_damage", 0)))
	definition.san_attack.deck_breach_power = maxi(0, int(san_attack.get("deck_breach_power", 0)))
	definition.san_attack.deck_breach_integrity_threshold = maxi(0, int(san_attack.get("deck_breach_integrity_threshold", 0)))
	definition.san_attack.physical_deck_damage = maxi(0, int(san_attack.get("physical_deck_damage", 0)))
	definition.san_attack.component_degradation = maxi(0, int(san_attack.get("component_degradation", 0)))
	definition.san_attack.temporary_disable_id = StringName(san_attack.get("temporary_disable_id", &""))
	definition.san_attack.temporary_disable_duration = maxf(0.0, float(san_attack.get("temporary_disable_duration", 0.0)))
	definition.san_attack.program_corruption_count = maxi(0, int(san_attack.get("program_corruption_count", 0)))
	definition.san_attack.force_disconnect_integrity_threshold = maxi(0, int(san_attack.get("force_disconnect_integrity_threshold", 0)))
	definition.san_attack.force_disconnect_on_san_destroy = bool(san_attack.get("force_disconnect_on_san_destroy", true))
	var binding: Dictionary = data.get("binding", {})
	definition.binding.mode = IceBindingProfileScript.Mode.HOST_BOUND if StringName(binding.get("mode", &"ROAMING")) == &"HOST_BOUND" else IceBindingProfileScript.Mode.ROAMING
	definition.binding.security_region_id = StringName(binding.get("security_region_id", &""))
	definition.binding.allowed_node_ids.assign(binding.get("allowed_node_ids", []))
	definition.binding.allowed_node_types.assign(binding.get("allowed_node_types", []))
	definition.binding.prohibited_node_ids.assign(binding.get("prohibited_node_ids", []))
	return definition


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
