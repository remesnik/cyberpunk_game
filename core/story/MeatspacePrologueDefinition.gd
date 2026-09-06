class_name MeatspacePrologueDefinition
extends Resource

@export var id: StringName = &"STORY_PROLOGUE"
@export var display_name := "Prologue"
@export_multiline var opening_text := ""
@export var initial_phase: StringName = &"CLAN_SELECTION"
@export var room_objects: Array[Dictionary] = []
@export var interactions: Array[Dictionary] = []

func interactions_for_phase(phase: StringName, flags: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for interaction: Dictionary in interactions:
		if StringName(interaction.get("phase", &"")) != phase: continue
		var required: Array = interaction.get("required_flags", [])
		if required.all(func(flag: Variant) -> bool: return bool(flags.get(StringName(flag), false))):
			result.append(interaction.duplicate(true))
	return result

func validate() -> Array[String]:
	var issues: Array[String] = []
	var ids := {}
	var object_ids := {}
	for object: Dictionary in room_objects:
		var object_id := StringName(object.get("id", &""))
		if object_id.is_empty(): issues.append("Room object has no ID.")
		elif object_ids.has(object_id): issues.append("Duplicate room object ID: %s" % object_id)
		else: object_ids[object_id] = true
		if String(object.get("interaction_text", "")).is_empty(): issues.append("%s has no contextual interaction text." % object_id)
	for interaction: Dictionary in interactions:
		var interaction_id := StringName(interaction.get("id", &""))
		if interaction_id.is_empty(): issues.append("Interaction has no ID.")
		elif ids.has(interaction_id): issues.append("Duplicate interaction ID: %s" % interaction_id)
		else: ids[interaction_id] = true
		if StringName(interaction.get("phase", &"")).is_empty(): issues.append("%s has no phase." % interaction_id)
		if (interaction.get("choices", []) as Array).is_empty(): issues.append("%s has no authored choices." % interaction_id)
	return issues
