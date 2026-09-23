class_name AddPathCommand
extends NetworkAuthorCommand

var link: NetworkLinkDefinition

func _init(p_context: Dictionary = {}, p_link: NetworkLinkDefinition = null) -> void:
	super(p_context); link = p_link

func execute() -> Dictionary:
	var live_graph := graph()
	var success := live_graph != null and link != null and live_graph.add_link(link)
	result = {"success": success, "reason": "Path added" if success else "Could not add path", "path_id": link.id if link != null else &""}
	return result

func undo() -> Dictionary:
	var removed := graph().remove_link(link.id) if graph() != null and link != null else null
	return {"success": removed != null, "reason": "Path removed" if removed != null else "Path no longer exists"}
