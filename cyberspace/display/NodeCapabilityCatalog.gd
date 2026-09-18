class_name NodeCapabilityCatalog
extends Resource

@export var definitions: Array[Resource] = []

func definition_for(capability: Variant) -> Resource:
	var parsed := NodeCapabilityType.parse(capability)
	for definition: Resource in definitions:
		if definition != null and int(definition.get("capability_type")) == parsed:
			return definition
	return null

func derive_from_services(services: Array[Dictionary]) -> Array[int]:
	var result: Array[int] = []
	for service: Dictionary in services:
		for explicit: Variant in service.get("capability_types", []):
			_append_unique(result, NodeCapabilityType.parse(explicit))
		var tags: Array = service.get("tags", [])
		for definition: Resource in definitions:
			if definition == null:
				continue
			for source_tag: StringName in definition.get("source_tags"):
				if tags.has(source_tag) or tags.has(String(source_tag)):
					_append_unique(result, int(definition.get("capability_type")))
					break
	result.sort_custom(func(a: int, b: int) -> bool:
		var a_definition := definition_for(a)
		var b_definition := definition_for(b)
		return int(a_definition.get("priority")) < int(b_definition.get("priority")) if a_definition != null and b_definition != null else a < b)
	return result

func derive_counts_from_services(services: Array[Dictionary]) -> Dictionary:
	var counts := {}
	for service: Dictionary in services:
		var single_service: Array[Dictionary] = [service]
		for capability: int in derive_from_services(single_service):
			counts[capability] = int(counts.get(capability, 0)) + 1
	return counts

func sort_capabilities(capabilities: Array[int]) -> Array[int]:
	var result := capabilities.duplicate()
	result.sort_custom(func(a: int, b: int) -> bool:
		var a_definition := definition_for(a)
		var b_definition := definition_for(b)
		return int(a_definition.get("priority")) < int(b_definition.get("priority")) if a_definition != null and b_definition != null else a < b)
	return result

func _append_unique(values: Array[int], value: int) -> void:
	if value >= 0 and not values.has(value):
		values.append(value)
