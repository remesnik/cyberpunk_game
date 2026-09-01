@tool
extends ScrollContainer

signal entry_changed

const ConditionEditor := preload("res://addons/cyberspace_authoring/widgets/condition_editor/StructuredConditionEditor.gd")
const ActionEditor := preload("res://addons/cyberspace_authoring/widgets/action_editor/StructuredActionEditor.gd")

var document: CyberspaceContentDocument
var selected_id: StringName
var _body: VBoxContainer


func _ready() -> void:
	_body = VBoxContainer.new(); _body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; add_child(_body); _empty()


func set_document(value: CyberspaceContentDocument) -> void: document = value; _empty()
func show_selection(path: String) -> void: show_entry(StringName(path.get_slice(" / ", path.get_slice_count(" / ") - 1)))
func show_entry(entry_id: StringName) -> void:
	selected_id = entry_id; _clear(); var entry := document.find_entry(entry_id) if document != null else {}
	if entry.is_empty(): _empty(); return
	var heading := Label.new(); heading.text = "INSPECTOR // %s" % entry.get("_collection", &"CONTENT"); heading.add_theme_color_override("font_color", Color("ffcc66")); _body.add_child(heading)
	_add_field("ID", String(entry.id), false)
	_add_field("DISPLAY NAME", String(entry.get("display_name", entry.get("title", ""))), true, "display_name")
	_add_field("DESCRIPTION / TEXT", String(entry.get("description", entry.get("text", entry.get("summary", "")))), true, "description")
	var raw := Label.new(); raw.text = "STRUCTURED DATA\n%s" % JSON.stringify(entry, "  "); raw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; raw.add_theme_font_size_override("font_size", 10); _body.add_child(raw)
	if entry.has("conditions") or entry.has("trigger_conditions"):
		var conditions := ConditionEditor.new(); _body.add_child(conditions); conditions.set_conditions(entry.get("conditions", entry.get("trigger_conditions", []))); conditions.conditions_changed.connect(func(value): document.update_entry(selected_id, {"conditions": value}); entry_changed.emit())
	if entry.has("actions") or entry.has("activation_actions"):
		var actions := ActionEditor.new(); _body.add_child(actions); actions.set_actions(entry.get("actions", entry.get("activation_actions", []))); actions.actions_changed.connect(func(value): document.update_entry(selected_id, {"actions": value}); entry_changed.emit())


func _add_field(label_text: String, value: String, editable: bool, key: String = "") -> void:
	var label := Label.new(); label.text = label_text; _body.add_child(label)
	if not editable:
		var readonly := Label.new(); readonly.text = value; _body.add_child(readonly); return
	var field := LineEdit.new(); field.text = value; _body.add_child(field); field.text_submitted.connect(func(text): document.update_entry(selected_id, {key: text}); entry_changed.emit())


func _clear() -> void:
	for child in _body.get_children(): child.queue_free()
func _empty() -> void:
	if _body == null: return
	_clear(); var label := Label.new(); label.text = "INSPECTOR\nNothing selected\n\nEditor selection and graph layout are never stored in runtime Resources."; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _body.add_child(label)
