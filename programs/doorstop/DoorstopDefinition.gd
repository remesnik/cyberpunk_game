class_name DoorstopDefinition
extends ProgramDefinition

@export var deployment_restrictions: Dictionary = {}
@export var allowed_node_types: Array[StringName] = []
@export var prohibited_encounter_tags: Array[StringName] = []
@export var required_programming_capability: StringName
@export var required_programming_tool: StringName
@export var programming_prerequisites: Array[StringName] = []
@export var trace_modifiers: Dictionary = {}
@export var security_modifiers: Dictionary = {}
@export var burn_on_deploy := true
@export var one_active_anchor_per_intrusion := true
@export var suspension_policy: DoorstopSuspensionPolicy
@export var return_to_exact_node := true
@export var destroy_anchor_on_return := true


func _init(
		p_id: StringName = &"DOORSTOP",
		p_display_name: String = "Doorstop",
		p_version: String = "1.0"
) -> void:
	super(p_id, p_display_name, p_version)
	description = "A one-shot program that leaves a temporary return point at the current cyberspace node."
	suspension_policy = DoorstopSuspensionPolicy.forgiving()


func validate_deployment(context: Dictionary) -> String:
	if bool(context.get("node_transition_unresolved", false)):
		return "Cannot deploy Doorstop during an unresolved node transition."
	if bool(context.get("modal_action_unresolved", false)):
		return "Resolve the current modal or action selection first."
	if bool(context.get("jack_out_prohibited", false)):
		return "This encounter prohibits Jack Out and Doorstop deployment."
	var encounter_tags: Array = context.get("encounter_tags", [])
	for tag in prohibited_encounter_tags:
		if encounter_tags.has(tag):
			return "Doorstop deployment is prohibited during this encounter."
	var node_id: StringName = context.get("node_id", &"")
	if node_id.is_empty() or not bool(context.get("node_is_valid", false)):
		return "Player is not occupying a valid cyberspace node."
	var node_type: StringName = context.get("node_type", &"")
	if not allowed_node_types.is_empty() and node_type not in allowed_node_types:
		return "Doorstop cannot be deployed on this node type."
	var allowed_nodes: Array = deployment_restrictions.get("allowed_node_ids", [])
	if not allowed_nodes.is_empty() and not allowed_nodes.has(node_id):
		return "Doorstop cannot be deployed at this node."
	var prohibited_nodes: Array = deployment_restrictions.get("prohibited_node_ids", [])
	if prohibited_nodes.has(node_id):
		return "Doorstop deployment is prohibited at this node."
	return ""
