@tool
class_name AuthoringContentWorkspace
extends VBoxContainer

signal entry_selected(entry_id: StringName)
signal document_changed

var document: CyberspaceContentDocument
var collections: Array[StringName] = []
var _type: OptionButton
var _list: ItemList


func _ready() -> void:
	var row := HBoxContainer.new(); add_child(row)
	_type = OptionButton.new(); _type.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _type.item_selected.connect(func(_i): _refresh()); row.add_child(_type)
	var add := Button.new(); add.text = "+ ENTRY"; add.pressed.connect(_add); row.add_child(add)
	var remove := Button.new(); remove.text = "DELETE"; remove.pressed.connect(_remove); row.add_child(remove)
	_list = ItemList.new(); _list.size_flags_vertical = Control.SIZE_EXPAND_FILL; _list.item_activated.connect(_select); _list.item_selected.connect(_select); add_child(_list)


func set_document(value: CyberspaceContentDocument) -> void: document = value; _refresh()
func set_collections(value: Array[StringName]) -> void:
	collections = value; _type.clear()
	for collection in collections: _type.add_item(String(collection).replace("_", " ").to_upper())
	_refresh()


func _collection() -> StringName: return collections[_type.selected] if _type != null and _type.selected >= 0 and _type.selected < collections.size() else &""
func _refresh() -> void:
	if _list == null: return
	_list.clear()
	if document == null or _collection() == &"": return
	for entry: Dictionary in document.collection(_collection()):
		_list.add_item("%s  //  %s" % [entry.get("id", &"NO_ID"), entry.get("display_name", entry.get("title", entry.get("text", "")))]); _list.set_item_metadata(_list.item_count - 1, entry.get("id", &""))


func _add() -> void:
	if document == null or _collection() == &"": return
	var id := StringName("%s_%03d" % [String(_collection()).to_upper(), document.collection(_collection()).size() + 1])
	var entry := _default_entry(_collection(), id)
	if document.add_entry(_collection(), entry): _refresh(); document_changed.emit(); entry_selected.emit(id)


func _default_entry(collection_name: StringName, id: StringName) -> Dictionary:
	var entry := {"id": id, "display_name": "New %s" % String(collection_name).replace("_", " ").capitalize(), "title": "New Entry", "text": "", "conditions": [], "actions": [], "tags": [], "author_notes": ""}
	if collection_name == &"program_definitions":
		entry.merge({"program_type": &"GENERIC", "version": "1.0", "description": "", "rarity": &"COMMON", "programming_recipe": {}, "programming_requirements": {}, "programming_duration": 0.0, "deployment_properties": {}, "trace_modifiers": {}, "security_modifiers": {}}, true)
	elif collection_name == &"rewards":
		entry.merge({"reward_type": &"PROGRAM", "program_definition_id": &"", "quantity": 1, "probability": 1.0, "repeatable": false, "prerequisite_flags": [], "source_type": &"NETWORK_NODE", "source_id": &"", "discovery_text": "Software cache discovered.", "pickup_text": "Program acquired.", "optional": true}, true)
	elif collection_name == &"hidden_caches":
		entry.merge({"node_id": &"", "hidden": true, "discovery_conditions": [], "reward_ids": []}, true)
	elif collection_name == &"objectives":
		entry.merge({"optional": true, "completion_conditions": [], "reward_ids": []}, true)
	elif collection_name == &"meatspace_interactions":
		entry.merge({"physical_location_id": &"", "conditions": [], "actions": [], "reward_ids": []}, true)
	return entry


func _remove() -> void:
	if _list.selected >= 0 and document.remove_entry(_list.get_item_metadata(_list.selected)): _refresh(); document_changed.emit()
func _select(index: int) -> void:
	if index >= 0: entry_selected.emit(_list.get_item_metadata(index))
