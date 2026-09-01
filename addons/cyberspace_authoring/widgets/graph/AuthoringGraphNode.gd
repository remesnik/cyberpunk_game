@tool
extends GraphNode

var authored_id: StringName


func configure(entry: Dictionary) -> void:
	authored_id = entry.get("id", &"")
	name = String(authored_id)
	title = "%s // %s" % [entry.get("display_name", authored_id), entry.get("node_type", &"CONTENT")]

