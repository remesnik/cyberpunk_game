class_name SetPathLockedCommand
extends NetworkAuthorCommand

var path_id: StringName
var locked: bool
var previous_locked := false
var previous_direction_states: Dictionary = {}

func _init(p_context: Dictionary = {}, p_path_id: StringName = &"", p_locked := true) -> void:
	super(p_context); path_id = p_path_id; locked = p_locked

func execute() -> Dictionary:
	var link := graph().get_link(path_id) if graph() != null else null
	if link == null: return {"success": false, "reason": "Path not found"}
	previous_locked = link.locked; previous_direction_states.clear()
	for key: Variant in link.traversal_directions:
		var direction := link.traversal_directions[key] as TraversalDirectionDefinition
		previous_direction_states[key] = direction.state
		if locked and direction.state != TraversalDirectionDefinition.State.HIDDEN: direction.state = TraversalDirectionDefinition.State.LOCKED
		elif not locked and direction.state == TraversalDirectionDefinition.State.LOCKED and direction.gate_type == TraversalDirectionDefinition.GateType.NONE: direction.state = TraversalDirectionDefinition.State.UNLOCKED
	link.locked = locked; graph().display_update_requested.emit()
	result = {"success": true, "reason": "Path locked" if locked else "Path unlocked", "path_id": path_id}
	return result

func undo() -> Dictionary:
	var link := graph().get_link(path_id) if graph() != null else null
	if link == null: return {"success": false, "reason": "Path not found"}
	link.locked = previous_locked
	for key: Variant in previous_direction_states:
		if link.traversal_directions.has(key): (link.traversal_directions[key] as TraversalDirectionDefinition).state = int(previous_direction_states[key]) as TraversalDirectionDefinition.State
	graph().display_update_requested.emit()
	return {"success": true, "reason": "Path lock restored"}
