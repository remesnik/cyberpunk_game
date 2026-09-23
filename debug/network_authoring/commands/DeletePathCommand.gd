class_name DeletePathCommand
extends NetworkAuthorCommand

var path_id: StringName
var removed_link: NetworkLinkDefinition

func _init(p_context: Dictionary = {}, p_path_id: StringName = &"") -> void:
	super(p_context); path_id = p_path_id

func execute() -> Dictionary:
	removed_link = graph().remove_link(path_id) if graph() != null else null
	result = {"success": removed_link != null, "reason": "Path deleted" if removed_link != null else "Path not found", "path_id": path_id}
	return result

func undo() -> Dictionary:
	var success := graph() != null and removed_link != null and graph().add_link(removed_link)
	return {"success": success, "reason": "Path restored" if success else "Could not restore path"}
