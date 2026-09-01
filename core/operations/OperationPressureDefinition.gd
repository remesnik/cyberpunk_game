class_name OperationPressureDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var realtime_threat_label: String
@export_range(0.0, 86400.0, 0.1) var realtime_deadline_seconds: float = 0.0
@export var cyber_plan: Array[Dictionary] = []
@export var story_tags: Array[StringName] = []


func _init(operation_id: StringName = &"", operation_name: String = "") -> void:
	id = operation_id
	display_name = operation_name


func add_cyber_step(label: String, action_type: ActionRequest.ActionType, target: StringName, cost: int) -> void:
	cyber_plan.append({"label": label, "action_type": action_type, "target": target, "cost": maxi(0, cost)})

