@tool
extends VBoxContainer

signal item_selected(path: String)

var document: CyberspaceContentDocument
var _tree: Tree
var _search: LineEdit


func _ready() -> void:
	add_theme_constant_override("separation", 5)
	var heading := Label.new(); heading.text = "CONTENT BROWSER"; heading.add_theme_color_override("font_color", Color("7df7c5")); add_child(heading)
	_search = LineEdit.new(); _search.placeholder_text = "type:comms node:PBX text:\"watcher\""; _search.text_changed.connect(func(_q): refresh()); add_child(_search)
	_tree = Tree.new(); _tree.hide_root = true; _tree.size_flags_vertical = Control.SIZE_EXPAND_FILL; _tree.item_selected.connect(_selected); _tree.item_activated.connect(_selected); add_child(_tree); refresh()


func set_document(value: CyberspaceContentDocument) -> void: document = value; refresh()


func refresh() -> void:
	if _tree == null: return
	_tree.clear(); var root := _tree.create_item()
	if document == null:
		var empty := _tree.create_item(root); empty.set_text(0, "NO DOCUMENT OPEN"); return
	var groups: Dictionary = {}
	for entry: Dictionary in document.all_entries():
		if not _matches(entry, _search.text): continue
		var collection: StringName = entry._collection
		if not groups.has(collection):
			var group := _tree.create_item(root)
			group.set_text(0, String(collection).replace("_", " ").to_upper())
			group.set_selectable(0, false)
			groups[collection] = group
		var item := _tree.create_item(groups[collection]); item.set_text(0, "%s // %s" % [entry.id, entry.get("display_name", entry.get("title", entry.get("text", "")))]); item.set_metadata(0, entry.id)


func _matches(entry: Dictionary, query: String) -> bool:
	var q := query.strip_edges().to_lower()
	if q.is_empty(): return true
	var serialized := JSON.stringify(entry).to_lower()
	for token in q.split(" ", false):
		var pair := token.split(":", true, 1)
		if pair.size() == 1 and not serialized.contains(pair[0]): return false
		if pair.size() == 2:
			var value := pair[1].trim_prefix("\"").trim_suffix("\"")
			match pair[0]:
				"type":
					if not String(entry._collection).contains(value): return false
				"tag":
					if not JSON.stringify(entry.get("tags", [])).to_lower().contains(value): return false
				"node":
					if String(entry.get("network_node_id", entry.get("target_id", &""))).to_lower() != value: return false
				"location":
					if String(entry.get("physical_location_id", entry.get("target_id", &""))).to_lower() != value: return false
				_:
					if not serialized.contains(value): return false
	return true


func _selected() -> void:
	var item := _tree.get_selected()
	if item != null and item.get_metadata(0) != null: item_selected.emit(String(item.get_metadata(0)))
