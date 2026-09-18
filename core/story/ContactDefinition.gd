class_name ContactDefinition
extends Resource

@export var contact_id: StringName
@export var display_name := ""
@export var portrait_path := ""
@export var unlock_conditions: Dictionary = {}
@export var initial_reputation := 0.0
@export var available_interactions: Array[Dictionary] = []
@export var missions_offered: Array[StringName] = []
@export var comms_content: Array[StringName] = []
@export var story_tags: Array[StringName] = []

static func from_dict(data: Dictionary) -> ContactDefinition:
	var result := ContactDefinition.new(); result.contact_id = StringName(data.get("contact_id", &"")); result.display_name = String(data.get("display_name", "")); result.portrait_path = String(data.get("portrait", data.get("icon", ""))); result.unlock_conditions = (data.get("unlock_conditions", {}) as Dictionary).duplicate(true); result.initial_reputation = float(data.get("reputation", 0.0)); result.available_interactions.assign(data.get("available_interactions", [])); result.missions_offered.assign(data.get("missions_offered", [])); result.comms_content.assign(data.get("comms_content", [])); result.story_tags.assign(data.get("story_tags", [])); return result

func validate() -> Array[String]:
	var errors: Array[String] = []
	if contact_id.is_empty(): errors.append("Contact has no contact_id.")
	if display_name.strip_edges().is_empty(): errors.append("Contact '%s' has no display name." % contact_id)
	return errors
