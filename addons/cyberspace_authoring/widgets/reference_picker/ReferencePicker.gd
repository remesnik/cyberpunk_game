@tool
class_name AuthoringReferencePicker
extends OptionButton

signal reference_selected(id: StringName)

var _ids: Array[StringName] = []


func set_references(entries: Array[Dictionary], allow_empty: bool = true) -> void:
	clear()
	_ids.clear()
	if allow_empty:
		add_item("-- NONE --")
		_ids.append(&"")
	for entry: Dictionary in entries:
		var id: StringName = entry.get("id", &"")
		if id == &"": continue
		add_item("%s  [%s]" % [entry.get("display_name", entry.get("title", id)), id])
		_ids.append(id)
	if not item_selected.is_connected(_on_item_selected):
		item_selected.connect(_on_item_selected)


func select_reference(id: StringName) -> void:
	var index := _ids.find(id)
	if index >= 0: select(index)


func selected_reference() -> StringName:
	return _ids[selected] if selected >= 0 and selected < _ids.size() else &""


func _on_item_selected(index: int) -> void:
	if index >= 0 and index < _ids.size(): reference_selected.emit(_ids[index])

