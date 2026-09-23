class_name NetworkAuthorCommand
extends RefCounted

## Mutations live in commands, not the HUD. Commands operate on the live
## runtime graph while retaining state needed by a future undo stack.
var context: Dictionary
var result: Dictionary = {"success": false, "reason": "Not executed"}

func _init(p_context: Dictionary = {}) -> void:
	context = p_context

func execute() -> Dictionary:
	return result

func undo() -> Dictionary:
	return {"success": false, "reason": "Undo not implemented"}

func graph() -> NetworkGraph:
	return context.get("graph") as NetworkGraph
