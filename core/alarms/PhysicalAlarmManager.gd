class_name PhysicalAlarmManager
extends Node

signal alarms_changed
signal alarm_state_changed(alarm_id: StringName, previous_state: PhysicalAlarmInstance.State, current_state: PhysicalAlarmInstance.State)
signal alarm_command_resolved(alarm_id: StringName, command: PhysicalAlarmDefinition.Command, success: bool, reason: String)
signal monitoring_changed

var definitions: Dictionary = {}
var instances: Dictionary = {}
var _process_manager: RealtimeProcessManager
var _knowledge: PlayerKnowledge
var _position: PlayerNetworkPosition
var monitored_alarm_ids: Array[StringName] = []


func configure(process_manager: RealtimeProcessManager, knowledge: PlayerKnowledge, position: PlayerNetworkPosition) -> void:
	_process_manager = process_manager
	_knowledge = knowledge
	_position = position
	if not _process_manager.processes_updated.is_connected(_on_realtime_updated):
		_process_manager.processes_updated.connect(_on_realtime_updated)
	if not _knowledge.knowledge_changed.is_connected(_on_knowledge_changed):
		_knowledge.knowledge_changed.connect(_on_knowledge_changed)


func add_alarm(definition: PhysicalAlarmDefinition) -> bool:
	if definition == null or definition.id == &"" or definitions.has(definition.id) or _process_manager.get_process(definition.realtime_process_id) == null:
		return false
	definitions[definition.id] = definition
	var instance := PhysicalAlarmInstance.new(definition)
	instances[definition.id] = instance
	instance.state_changed.connect(_on_instance_state_changed)
	return true


func get_discovered_alarms() -> Array[PhysicalAlarmInstance]:
	var result: Array[PhysicalAlarmInstance] = []
	for value: Variant in instances.values():
		var instance := value as PhysicalAlarmInstance
		if _knowledge.knows_realtime_process(instance.definition.realtime_process_id):
			result.append(instance)
	result.sort_custom(func(a: PhysicalAlarmInstance, b: PhysicalAlarmInstance) -> bool: return String(a.definition.id) < String(b.definition.id))
	return result

func start_monitoring(alarm_id: StringName) -> bool:
	var instance := instances.get(alarm_id) as PhysicalAlarmInstance
	if instance == null or _knowledge == null or not _knowledge.knows_realtime_process(instance.definition.realtime_process_id): return false
	if alarm_id not in monitored_alarm_ids: monitored_alarm_ids.append(alarm_id)
	monitoring_changed.emit()
	return true

func stop_monitoring(alarm_id: StringName) -> void:
	monitored_alarm_ids.erase(alarm_id)
	monitoring_changed.emit()

func get_monitored_alarms() -> Array[PhysicalAlarmInstance]:
	var result: Array[PhysicalAlarmInstance] = []
	for alarm_id: StringName in monitored_alarm_ids:
		var instance := instances.get(alarm_id) as PhysicalAlarmInstance
		if instance != null and _knowledge != null and _knowledge.knows_realtime_process(instance.definition.realtime_process_id): result.append(instance)
	return result


func evaluate_command(alarm_id: StringName, command: PhysicalAlarmDefinition.Command) -> Dictionary:
	var instance := instances.get(alarm_id) as PhysicalAlarmInstance
	if instance == null or not _knowledge.knows_realtime_process(instance.definition.realtime_process_id):
		return {"success": false, "reason": "Alarm endpoint has not been discovered."}
	var policy: Dictionary = instance.definition.action_policies.get(command, {})
	var authority := int(policy.get("authority", 0))
	var capability: StringName = policy.get("capability", &"")
	if _position.authority_level < authority:
		return {"success": false, "reason": "Authority %d required." % authority}
	if capability != &"" and not _position.has_capability(capability):
		return {"success": false, "reason": "%s capability required." % capability}
	return {"success": true, "reason": "Available."}


func execute_command(alarm_id: StringName, command: PhysicalAlarmDefinition.Command) -> Dictionary:
	var validation := evaluate_command(alarm_id, command)
	if not validation.success:
		alarm_command_resolved.emit(alarm_id, command, false, validation.reason)
		return validation
	var instance := instances[alarm_id] as PhysicalAlarmInstance
	var success := instance.apply_command(command)
	var reason := "%s applied in realtime." % PhysicalAlarmDefinition.Command.keys()[command] if success else "Command is invalid for the current alarm state."
	alarm_command_resolved.emit(alarm_id, command, success, reason)
	alarms_changed.emit()
	return {"success": success, "reason": reason, "state": instance.state, "realtime": instance.elapsed_time}


func get_reaction_view(alarm_id: StringName) -> Dictionary:
	var instance := instances.get(alarm_id) as PhysicalAlarmInstance
	return instance.reaction_view() if instance != null else {}


func _on_realtime_updated(_session_time: float) -> void:
	for value: Variant in instances.values():
		var instance := value as PhysicalAlarmInstance
		var process := _process_manager.get_process(instance.definition.realtime_process_id)
		if process != null:
			instance.advance_to(process.elapsed_time)
	alarms_changed.emit()


func _on_instance_state_changed(alarm_id: StringName, previous: PhysicalAlarmInstance.State, current: PhysicalAlarmInstance.State) -> void:
	alarm_state_changed.emit(alarm_id, previous, current)
	alarms_changed.emit()


func _on_knowledge_changed() -> void:
	alarms_changed.emit()
