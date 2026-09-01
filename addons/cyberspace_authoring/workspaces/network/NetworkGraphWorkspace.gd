@tool
class_name NetworkGraphWorkspace
extends VBoxContainer

signal entry_selected(entry_id: StringName)
signal document_changed

var document: CyberspaceContentDocument
var editor_state: AuthoringEditorState
var graph: GraphEdit


func _ready() -> void:
	var tools := HBoxContainer.new(); add_child(tools)
	for caption: String in ["+ NODE", "DUPLICATE", "DELETE", "FRAME ALL"]:
		var button := Button.new(); button.text = caption; tools.add_child(button)
		if caption == "+ NODE": button.pressed.connect(_add_node)
		elif caption == "DUPLICATE": button.pressed.connect(_duplicate_selected)
		elif caption == "DELETE": button.pressed.connect(_delete_selected)
		elif caption == "FRAME ALL": button.pressed.connect(_frame_all)
	var hint := Label.new(); hint.text = "Drag ports to connect // positions are editor metadata only"; hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tools.add_child(hint)
	graph = GraphEdit.new(); graph.size_flags_vertical = Control.SIZE_EXPAND_FILL; graph.show_grid = true; graph.show_zoom_label = true; graph.minimap_enabled = true; add_child(graph)
	graph.connection_request.connect(_connect_nodes)
	graph.disconnection_request.connect(_disconnect_nodes)
	graph.delete_nodes_request.connect(func(nodes): _delete_nodes(nodes))


func set_models(value: CyberspaceContentDocument, state: AuthoringEditorState) -> void:
	document = value; editor_state = state; rebuild()


func rebuild() -> void:
	if graph == null: return
	graph.clear_connections()
	for child in graph.get_children():
		if child is GraphNode: child.queue_free()
	if document == null: return
	var index := 0
	for entry: Dictionary in document.network_nodes:
		_add_visual(entry, editor_state.position_for(entry.id, Vector2(60 + (index % 4) * 230, 50 + (index / 4) * 160)))
		index += 1
	for link: Dictionary in document.network_links:
		var source := StringName(link.get("source", &"")); var destination := StringName(link.get("destination", &""))
		if graph.has_node(NodePath(String(source))) and graph.has_node(NodePath(String(destination))): graph.connect_node(source, 0, destination, 0)


func _add_visual(entry: Dictionary, position: Vector2) -> void:
	var node := GraphNode.new(); node.name = String(entry.id); node.title = "%s // %s" % [entry.get("display_name", entry.id), entry.get("node_type", &"UNKNOWN")]; node.position_offset = position; node.custom_minimum_size = Vector2(205, 105)
	var summary := Label.new(); summary.text = "ID: %s\nSEC: %s  OWNER: %s\nENDPOINTS: %d" % [entry.id, entry.get("security_level", 0), entry.get("owner", &"UNKNOWN"), _endpoint_count(entry.id)]; node.add_child(summary); node.set_slot(0, true, 0, Color("56e8ff"), true, 0, Color("ffcc66"))
	node.node_selected.connect(func(): entry_selected.emit(StringName(node.name)))
	node.position_offset_changed.connect(func(): editor_state.set_position(StringName(node.name), node.position_offset))
	graph.add_child(node)


func _endpoint_count(node_id: StringName) -> int:
	var count := 0
	for endpoint: Dictionary in document.realtime_endpoints:
		if endpoint.get("network_node_id", &"") == node_id: count += 1
	return count


func _add_node() -> void:
	if document == null: return
	var serial := document.network_nodes.size() + 1; var id := StringName("NODE_%03d" % serial)
	while not document.find_entry(id).is_empty(): serial += 1; id = StringName("NODE_%03d" % serial)
	document.add_entry(&"network_nodes", {"id": id, "display_name": "New Network Node", "node_type": &"SERVER", "owner": &"", "faction": &"", "security_level": 0, "description": "", "tags": [], "region_id": &"", "services": [], "starting_discovery_state": &"UNKNOWN", "graffiti": [], "flavor_text": [], "story_hooks": [], "author_notes": ""})
	editor_state.set_position(id, graph.scroll_offset + Vector2(180, 120)); rebuild(); document_changed.emit()


func _connect_nodes(from: StringName, _from_port: int, to: StringName, _to_port: int) -> void:
	if from == to or document == null: return
	var id := StringName("%s_TO_%s" % [from, to])
	if document.add_entry(&"network_links", {"id": id, "source": from, "destination": to, "one_way": false, "hidden": false, "locked": false, "disabled": false, "traversal_cost": 1, "authority_requirement": 0, "capability_requirement": &"", "tags": [], "story_hooks": [], "author_notes": ""}): rebuild(); document_changed.emit()


func _disconnect_nodes(from: StringName, _from_port: int, to: StringName, _to_port: int) -> void:
	for link: Dictionary in document.network_links.duplicate():
		if link.get("source") == from and link.get("destination") == to: document.remove_entry(link.id)
	rebuild(); document_changed.emit()


func _selected() -> Array[StringName]:
	var result: Array[StringName] = []
	for child in graph.get_children():
		if child is GraphNode and child.selected: result.append(StringName(child.name))
	return result


func _duplicate_selected() -> void:
	for id in _selected():
		var source := document.find_entry(id); var copy := source.duplicate(true); copy.erase("_collection"); copy.id = StringName("%s_COPY" % id); copy.display_name = "%s Copy" % source.get("display_name", id)
		if document.add_entry(&"network_nodes", copy): editor_state.set_position(copy.id, editor_state.position_for(id, Vector2.ZERO) + Vector2(35, 35))
	rebuild(); document_changed.emit()


func _delete_selected() -> void: _delete_nodes(_selected())
func _delete_nodes(nodes: Array[StringName]) -> void:
	for id in nodes:
		for link: Dictionary in document.network_links.duplicate():
			if link.get("source") == id or link.get("destination") == id: document.remove_entry(link.id)
		document.remove_entry(id); editor_state.graph_positions.erase(id)
	rebuild(); document_changed.emit()
func _frame_all() -> void: graph.set_deferred("scroll_offset", Vector2.ZERO)
