class_name CompositeAuthorCommand
extends NetworkAuthorCommand

var commands: Array[NetworkAuthorCommand] = []
var label := "Selection operation"
var executed_count := 0

func _init(p_context := {}, p_commands: Array[NetworkAuthorCommand] = [], p_label := "Selection operation") -> void:
	super(p_context)
	commands = p_commands
	label = p_label

func execute() -> Dictionary:
	executed_count = 0
	for command: NetworkAuthorCommand in commands:
		var child_result := command.execute()
		if not bool(child_result.get("success", false)):
			for index in range(executed_count - 1, -1, -1): commands[index].undo()
			return {"success": false, "reason": child_result.get("reason", "%s failed" % label)}
		executed_count += 1
	return {"success": true, "reason": label}

func undo() -> Dictionary:
	for index in range(executed_count - 1, -1, -1):
		var child_result := commands[index].undo()
		if not bool(child_result.get("success", false)): return child_result
	return {"success": true, "reason": "%s undone" % label}
