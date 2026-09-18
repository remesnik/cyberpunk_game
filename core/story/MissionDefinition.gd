class_name MissionDefinition
extends Resource
## Authored reason, goals, outcomes, rewards, and presentation for a Netspace run.

@export var mission_id: StringName
@export var title := ""
@export_multiline var briefing := ""
@export var primary_objectives: Array[ObjectiveDefinition] = []
@export var optional_objectives: Array[ObjectiveDefinition] = []
@export var hidden_objectives: Array[ObjectiveDefinition] = []
@export var success_conditions: Dictionary = {"primary_objectives_complete": true}
@export var failure_conditions: Array[Dictionary] = []
@export var reward_definition: Dictionary = {}
@export var story_result_rules: Array[Dictionary] = []
@export var entry_network: StringName
@export var story_metadata: Dictionary = {}
@export var known_constraints: Array[String] = []
@export var aliases: Array[StringName] = []

static func from_dict(data: Dictionary) -> MissionDefinition:
	var definition := MissionDefinition.new()
	definition.mission_id = StringName(data.get("mission_id", &"")); definition.title = String(data.get("title", "")); definition.briefing = String(data.get("briefing", ""))
	definition.primary_objectives = _objectives(data.get("primary_objectives", []), &"primary")
	definition.optional_objectives = _objectives(data.get("optional_objectives", []), &"optional")
	definition.hidden_objectives = _objectives(data.get("hidden_objectives", []), &"hidden")
	definition.success_conditions = (data.get("success_conditions", {"primary_objectives_complete": true}) as Dictionary).duplicate(true)
	definition.failure_conditions.assign((data.get("failure_conditions", []) as Array).map(func(value: Variant) -> Dictionary: return (value as Dictionary).duplicate(true)))
	definition.reward_definition = (data.get("reward_definition", {}) as Dictionary).duplicate(true)
	definition.story_result_rules.assign((data.get("story_result_rules", []) as Array).map(func(value: Variant) -> Dictionary: return (value as Dictionary).duplicate(true)))
	definition.entry_network = StringName(data.get("entry_network", &"")); definition.story_metadata = (data.get("story_metadata", {}) as Dictionary).duplicate(true)
	definition.known_constraints.assign(data.get("known_constraints", []))
	definition.aliases.assign(data.get("aliases", []))
	return definition

static func _objectives(values: Array, category: StringName) -> Array[ObjectiveDefinition]:
	var result: Array[ObjectiveDefinition] = []
	for value: Variant in values:
		if value is Dictionary: result.append(ObjectiveDefinition.from_dict(value, category))
	return result

func all_objectives() -> Array[ObjectiveDefinition]: return primary_objectives + optional_objectives + hidden_objectives
func validate() -> Array[String]:
	var errors: Array[String] = []; var ids: Dictionary = {}
	if mission_id.is_empty(): errors.append("Mission has no mission_id.")
	if title.strip_edges().is_empty(): errors.append("Mission '%s' has no title." % mission_id)
	if entry_network.is_empty(): errors.append("Mission '%s' has no entry_network." % mission_id)
	if primary_objectives.is_empty(): errors.append("Mission '%s' has no primary objective." % mission_id)
	for objective: ObjectiveDefinition in all_objectives():
		errors.append_array(objective.validate())
		if ids.has(objective.objective_id): errors.append("Mission '%s' repeats objective '%s'." % [mission_id, objective.objective_id])
		ids[objective.objective_id] = true
	return errors

func briefing_view() -> Dictionary:
	return {"mission_id": mission_id, "title": title, "briefing": briefing, "entry_network": entry_network, "primary_objectives": primary_objectives.map(func(item: ObjectiveDefinition) -> Dictionary: return {"objective_id": item.objective_id, "description": item.description}), "optional_objectives": optional_objectives.map(func(item: ObjectiveDefinition) -> Dictionary: return {"objective_id": item.objective_id, "description": item.description}), "known_constraints": known_constraints.duplicate(), "reward": reward_definition.duplicate(true), "story_metadata": story_metadata.duplicate(true)}
