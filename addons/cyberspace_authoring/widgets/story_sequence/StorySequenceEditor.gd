@tool
class_name StorySequenceEditor
extends VBoxContainer

signal entry_selected(entry_id: StringName)
signal document_changed

const Catalog := preload("res://core/story/MissionEventNodeCatalog.gd")
var document: CyberspaceContentDocument
var _sequence_picker: OptionButton
var _type_picker: OptionButton
var _nodes: ItemList
var _details: VBoxContainer

func _ready() -> void:
	var sequence_row := HBoxContainer.new(); add_child(sequence_row)
	_sequence_picker = OptionButton.new(); _sequence_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _sequence_picker.item_selected.connect(func(_i): _refresh_nodes()); sequence_row.add_child(_sequence_picker)
	var add_sequence := Button.new(); add_sequence.text = "+ SEQUENCE"; add_sequence.tooltip_text = "Create a reusable authored mission sequence."; add_sequence.pressed.connect(_add_sequence); sequence_row.add_child(add_sequence)
	var convert := Button.new(); convert.text = "CONVERT BEATS"; convert.tooltip_text = "Copy an older beat sequence into editable generic event nodes. Original beats remain preserved."; convert.pressed.connect(_convert_legacy); sequence_row.add_child(convert)
	var node_row := HBoxContainer.new(); add_child(node_row)
	_type_picker = OptionButton.new(); _type_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for type: StringName in Catalog.NODE_TYPES: _type_picker.add_item(String(type).replace("_", " ")); _type_picker.set_item_metadata(_type_picker.item_count - 1, type)
	node_row.add_child(_type_picker)
	var add_node := Button.new(); add_node.text = "+ EVENT NODE"; add_node.tooltip_text = "Add a generic story/mission event node."; add_node.pressed.connect(_add_node); node_row.add_child(add_node)
	for spec in [["UP", -1], ["DOWN", 1], ["DELETE", 0]]:
		var button := Button.new(); button.text = spec[0]; button.pressed.connect(_move_or_remove.bind(spec[1])); node_row.add_child(button)
	_nodes = ItemList.new(); _nodes.custom_minimum_size.y = 260; _nodes.size_flags_vertical = Control.SIZE_EXPAND_FILL; _nodes.item_selected.connect(_show_node); add_child(_nodes)
	_details = VBoxContainer.new(); add_child(_details)

func set_document(value: CyberspaceContentDocument) -> void: document = value; _refresh_sequences()

func _refresh_sequences() -> void:
	if _sequence_picker == null: return
	_sequence_picker.clear()
	if document != null:
		for sequence: Dictionary in document.story_sequences:
			_sequence_picker.add_item(String(sequence.get("display_name", sequence.id))); _sequence_picker.set_item_metadata(_sequence_picker.item_count - 1, sequence.id)
	_refresh_nodes()

func _selected_sequence() -> Dictionary:
	if document == null or _sequence_picker.selected < 0: return {}
	return document.find_entry(_sequence_picker.get_item_metadata(_sequence_picker.selected))

func _editable_nodes(sequence: Dictionary) -> Array:
	if sequence.has("event_nodes"): return sequence.event_nodes
	var views: Array = []
	for beat: Dictionary in sequence.get("beats", []): views.append(Catalog.legacy_beat_view(beat))
	return views

func _refresh_nodes() -> void:
	if _nodes == null: return
	_nodes.clear(); _clear_details()
	var sequence := _selected_sequence()
	for node: Dictionary in _editable_nodes(sequence): _nodes.add_item(Catalog.describe(node)); _nodes.set_item_metadata(_nodes.item_count - 1, node.id)
	if not sequence.is_empty(): entry_selected.emit(sequence.id)

func _add_sequence() -> void:
	if document == null: return
	var id := StringName("STORY_SEQUENCE_%03d" % [document.story_sequences.size() + 1])
	if document.add_entry(&"story_sequences", {"id": id, "display_name": "New Guided Sequence", "sequence_type": &"MISSION", "event_nodes": [], "entry_node_id": &"", "tags": [], "author_notes": ""}):
		document_changed.emit(); _refresh_sequences(); _sequence_picker.select(_sequence_picker.item_count - 1); _refresh_nodes()

func _add_node() -> void:
	var sequence := _selected_sequence()
	if sequence.is_empty() or not sequence.has("event_nodes"): return
	var nodes: Array = sequence.event_nodes.duplicate(true)
	var node_type: StringName = _type_picker.get_item_metadata(_type_picker.selected)
	var id := StringName("%s_%03d" % [node_type, nodes.size() + 1]); nodes.append(Catalog.create(node_type, id))
	document.update_entry(sequence.id, {"event_nodes": nodes}); document_changed.emit(); _refresh_nodes(); _nodes.select(_nodes.item_count - 1); _show_node(_nodes.item_count - 1)

func _convert_legacy() -> void:
	var sequence := _selected_sequence()
	if sequence.is_empty() or sequence.has("event_nodes") or sequence.get("beats", []).is_empty(): return
	var nodes: Array[Dictionary] = Catalog.convert_legacy_beats(sequence.beats, sequence.get("speaker_actor_id", &""))
	document.update_entry(sequence.id, {"event_nodes": nodes, "converted_from_beats": true})
	document_changed.emit(); _refresh_nodes()

func _move_or_remove(direction: int) -> void:
	var sequence: Dictionary = _selected_sequence()
	var index: int = _nodes.selected
	if sequence.is_empty() or not sequence.has("event_nodes") or index < 0: return
	var nodes: Array = sequence.event_nodes.duplicate(true)
	if direction == 0: nodes.remove_at(index)
	else:
		var destination: int = clampi(index + direction, 0, nodes.size() - 1)
		if destination == index: return
		var node = nodes.pop_at(index); nodes.insert(destination, node); index = destination
	document.update_entry(sequence.id, {"event_nodes": nodes}); document_changed.emit(); _refresh_nodes()
	if index >= 0 and index < _nodes.item_count: _nodes.select(index); _show_node(index)

func _show_node(index: int) -> void:
	_clear_details(); var sequence := _selected_sequence(); var nodes := _editable_nodes(sequence)
	if index < 0 or index >= nodes.size(): return
	var node: Dictionary = nodes[index]
	var heading := Label.new(); heading.text = "%s // %s" % [node.get("type", &"NODE"), node.id]; heading.add_theme_color_override("font_color", Color("56e8ff")); _details.add_child(heading)
	if node.get("type") == &"LEGACY_BEAT":
		var note := Label.new(); note.text = "Existing beat data is visible and remains editable in the structured inspector. New sequences use generic event nodes."; note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _details.add_child(note); return
	_add_text_field("ACTOR ID", node.get("actor_id", &""), "actor_id", index)
	_add_text_field("TARGET / NODE / OBJECTIVE ID", node.get("target_id", node.get("node_id", node.get("objective_id", &""))), _reference_key(node), index)
	_add_text_field("DIALOGUE / HINT TEXT", node.get("text", ""), "text", index)
	if node.type == &"WAIT_FOR": _add_event_picker(node.get("event_type", &"NODE_ENTERED"), index)

func _add_text_field(label_text: String, value: Variant, key: String, index: int) -> void:
	var label := Label.new(); label.text = label_text; _details.add_child(label)
	var field := LineEdit.new(); field.text = String(value)
	field.editing_toggled.connect(func(active):
		if not active: _patch_node(index, key, field.text)
	)
	_details.add_child(field)

func _add_event_picker(value: StringName, index: int) -> void:
	var label := Label.new(); label.text = "GAMEPLAY EVENT"; _details.add_child(label)
	var picker := OptionButton.new(); _details.add_child(picker)
	for event: StringName in Catalog.GAMEPLAY_EVENTS:
		picker.add_item(String(event).replace("_", " ")); picker.set_item_metadata(picker.item_count - 1, event)
		if event == value: picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(i): _patch_node(index, "event_type", picker.get_item_metadata(i)))

func _patch_node(index: int, key: String, value: Variant) -> void:
	var sequence := _selected_sequence(); if sequence.is_empty() or not sequence.has("event_nodes"): return
	var nodes: Array = sequence.event_nodes.duplicate(true); nodes[index][key] = StringName(value) if key.ends_with("_id") else value
	document.update_entry(sequence.id, {"event_nodes": nodes}); document_changed.emit(); _refresh_nodes()

func _reference_key(node: Dictionary) -> String:
	for key in ["target_id", "node_id", "objective_id", "reward_id", "ice_definition_id", "realtime_event_id", "flag_id"]:
		if node.has(key): return key
	return "target_id"
func _clear_details() -> void:
	if _details != null:
		for child in _details.get_children(): child.queue_free()
