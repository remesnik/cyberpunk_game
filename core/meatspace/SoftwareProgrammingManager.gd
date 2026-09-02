class_name SoftwareProgrammingManager
extends RefCounted

var inventory: ProgramInventory
var realtime_clock: RealtimeWorldClock
var tasks: Dictionary = {}
var resources: Dictionary = {}
var maximum_queued_tasks := 4
var _instance_serial := 0


func configure(program_inventory: ProgramInventory, clock: RealtimeWorldClock) -> void:
	inventory = program_inventory
	realtime_clock = clock


func add_resource(resource_id: StringName, amount: int) -> void:
	if not resource_id.is_empty() and amount > 0:
		resources[resource_id] = int(resources.get(resource_id, 0)) + amount


func can_start(definition: ProgramDefinition) -> Dictionary:
	if definition == null:
		return _failure("Program definition is missing.")
	var queued := 0
	for task: SoftwareProgrammingTask in tasks.values():
		if task.state == SoftwareProgrammingTask.State.PROGRAMMING:
			queued += 1
	if queued >= maximum_queued_tasks:
		return _failure("Software programming queue is full.")
	for resource_id in definition.programming_recipe:
		var required := int(definition.programming_recipe[resource_id])
		if int(resources.get(resource_id, 0)) < required:
			return _failure("Programming requires %d %s." % [required, resource_id])
	return {"success": true, "reason": "Programming requirements met."}


func start_task(task_id: StringName, definition: ProgramDefinition, duration_override := -1.0) -> Dictionary:
	if task_id.is_empty() or tasks.has(task_id):
		return _failure("Programming task ID is invalid or already exists.")
	var validation := can_start(definition)
	if not validation.success:
		return validation
	for resource_id in definition.programming_recipe:
		resources[resource_id] = int(resources.get(resource_id, 0)) - int(definition.programming_recipe[resource_id])
	var duration := float(duration_override) if duration_override >= 0.0 else definition.programming_duration
	var output_id := _next_instance_id(definition.id)
	var now := realtime_clock.elapsed_seconds if realtime_clock != null else 0.0
	var task := SoftwareProgrammingTask.new(task_id, definition, output_id, now, duration)
	tasks[task_id] = task
	return {"success": true, "reason": "Programming task started.", "task_id": task_id, "output_instance_id": output_id, "duration": duration}


func update() -> void:
	var now := realtime_clock.elapsed_seconds if realtime_clock != null else 0.0
	for task: SoftwareProgrammingTask in tasks.values():
		task.update(now)


func collect(task_id: StringName) -> Dictionary:
	var task := tasks.get(task_id) as SoftwareProgrammingTask
	if task == null:
		return _failure("Programming task does not exist.")
	update()
	if task.state != SoftwareProgrammingTask.State.COMPLETED:
		return _failure("Programming task is not complete.")
	var instance := ProgramInstance.new(task.output_instance_id, task.program_definition, {"source": &"SOFTWARE_PROGRAMMING", "task_id": task.id})
	if not inventory.add_instance(instance):
		return _failure("Program output could not be added to inventory.")
	task.state = SoftwareProgrammingTask.State.COLLECTED
	return {"success": true, "reason": "Program collected.", "program_instance_id": instance.instance_id, "definition_id": instance.definition_id()}


func grant_loot(definition: ProgramDefinition, source_id: StringName = &"") -> Dictionary:
	if definition == null or inventory == null:
		return _failure("Program reward is invalid.")
	var instance := ProgramInstance.new(_next_instance_id(definition.id), definition, {"source": &"LEVEL_REWARD", "source_id": source_id})
	if not inventory.add_instance(instance):
		return _failure("Program reward could not be added to inventory.")
	return {"success": true, "reason": "Program reward collected.", "program_instance_id": instance.instance_id, "definition_id": instance.definition_id()}


func _next_instance_id(definition_id: StringName) -> StringName:
	while true:
		_instance_serial += 1
		var candidate := StringName("%s_INSTANCE_%06d" % [definition_id, _instance_serial])
		if inventory == null or not inventory.has_instance(candidate):
			return candidate
	return &""


func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
