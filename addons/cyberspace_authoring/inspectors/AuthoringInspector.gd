@tool
extends ScrollContainer

signal entry_changed

const ConditionEditor := preload("res://addons/cyberspace_authoring/widgets/condition_editor/StructuredConditionEditor.gd")
const ActionEditor := preload("res://addons/cyberspace_authoring/widgets/action_editor/StructuredActionEditor.gd")
const DoorstopInspector := preload("res://addons/cyberspace_authoring/inspectors/DoorstopDefinitionInspector.gd")
const SphereInspector := preload("res://addons/cyberspace_authoring/inspectors/SphereInspector.gd")

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
	if entry.get("_collection", &"") == &"program_definitions" and entry.get("program_type", &"") == &"DOORSTOP":
		var doorstop := DoorstopInspector.new(); _body.add_child(doorstop); doorstop.set_definition(entry)
		doorstop.definition_changed.connect(func(patch): document.update_entry(selected_id, patch); entry_changed.emit())
		return
	if entry.get("_collection", &"") == &"spheres":
		var sphere_inspector := SphereInspector.new(); _body.add_child(sphere_inspector); sphere_inspector.set_sphere(document, entry_id)
		sphere_inspector.definition_changed.connect(func(): entry_changed.emit())
		return
	_add_field("ID", String(entry.id), false)
	_add_field("DISPLAY NAME", String(entry.get("display_name", entry.get("title", ""))), true, "display_name")
	_add_field("DESCRIPTION / TEXT", String(entry.get("description", entry.get("text", entry.get("summary", "")))), true, "description")
	_add_choice("GAME MODE AVAILABILITY", [&"AVAILABLE_IN_ALL_MODES", &"STORY_ONLY", &"FREE_ROAM_ONLY", &"MODE_SPECIFIC_VARIANT"], StringName(entry.get("availability", document.availability)), "availability")
	var collection: StringName = entry.get("_collection", &"")
	if collection == &"network_nodes": _add_node_sphere_field(entry)
	elif collection == &"program_definitions": _add_program_definition_fields(entry)
	elif collection == &"rewards": _add_reward_fields(entry)
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


func _add_program_definition_fields(entry: Dictionary) -> void:
	_add_choice("PROGRAM TYPE", [&"GENERIC", &"DOORSTOP"], entry.get("program_type", &"GENERIC"), "program_type")
	_add_field("VERSION", String(entry.get("version", "1.0")), true, "version")
	_add_field("RARITY", String(entry.get("rarity", &"COMMON")), true, "rarity")
	_add_number("PROGRAMMING DURATION (REALTIME SECONDS)", float(entry.get("programming_duration", 0.0)), 0.0, 86400.0, 0.1, "programming_duration")


func _add_node_sphere_field(entry: Dictionary) -> void:
	var label := Label.new(); label.text = "PERSISTENT SPHERE"; _body.add_child(label)
	var picker := OptionButton.new(); picker.tooltip_text = "Persistent subnet membership. Current Security Sleeve state is edited independently."; _body.add_child(picker)
	picker.add_item("UNASSIGNED"); picker.set_item_metadata(0, &"")
	var selected: StringName = entry.get("sphere_id", &"")
	for sphere: Dictionary in document.spheres:
		picker.add_item("%s // %s" % [sphere.get("display_name", sphere.id), sphere.id]); picker.set_item_metadata(picker.item_count - 1, sphere.id)
		if sphere.id == selected: picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index): document.assign_node_to_sphere(selected_id, picker.get_item_metadata(index)); entry_changed.emit())


func _add_reward_fields(entry: Dictionary) -> void:
	var heading := Label.new(); heading.text = "PROGRAM / ITEM REWARD"; heading.add_theme_color_override("font_color", Color("56e8ff")); _body.add_child(heading)
	var program_picker := OptionButton.new(); _body.add_child(program_picker)
	var selected_program: StringName = entry.get("program_definition_id", &"")
	for program: Dictionary in document.program_definitions:
		program_picker.add_item("%s %s // %s" % [program.get("display_name", program.id), program.get("version", ""), program.id])
		program_picker.set_item_metadata(program_picker.item_count - 1, program.id)
		if program.id == selected_program: program_picker.select(program_picker.item_count - 1)
	program_picker.item_selected.connect(func(index): document.update_entry(selected_id, {"program_definition_id": program_picker.get_item_metadata(index)}); entry_changed.emit())
	_add_choice("SOURCE TYPE", [&"NETWORK_NODE", &"HIDDEN_CACHE", &"SUCCESSFUL_HACK", &"STORY_EVENT", &"MEATSPACE_INTERACTION", &"OPTIONAL_OBJECTIVE"], entry.get("source_type", &"NETWORK_NODE"), "source_type")
	_add_field("SOURCE ID", String(entry.get("source_id", &"")), true, "source_id")
	_add_number("QUANTITY", float(entry.get("quantity", 1)), 1.0, 99.0, 1.0, "quantity", true)
	_add_number("PROBABILITY / CHANCE", float(entry.get("probability", 1.0)), 0.0, 1.0, 0.01, "probability")
	_add_toggle("REPEATABLE", bool(entry.get("repeatable", false)), "repeatable")
	_add_flag_list(entry.get("prerequisite_flags", []))
	_add_field("DISCOVERY TEXT", String(entry.get("discovery_text", "Software cache discovered.")), true, "discovery_text")
	_add_field("PICKUP TEXT", String(entry.get("pickup_text", "Program acquired.")), true, "pickup_text")


func _add_number(label_text: String, value: float, minimum: float, maximum: float, step: float, key: String, integer := false) -> void:
	var label := Label.new(); label.text = label_text; _body.add_child(label)
	var field := SpinBox.new(); field.min_value = minimum; field.max_value = maximum; field.step = step; field.value = value; _body.add_child(field)
	field.value_changed.connect(func(next): document.update_entry(selected_id, {key: int(next) if integer else next}); entry_changed.emit())


func _add_toggle(label_text: String, value: bool, key: String) -> void:
	var field := CheckBox.new(); field.text = label_text; field.button_pressed = value; _body.add_child(field)
	field.toggled.connect(func(next): document.update_entry(selected_id, {key: next}); entry_changed.emit())


func _add_choice(label_text: String, values: Array[StringName], value: StringName, key: String) -> void:
	var label := Label.new(); label.text = label_text; _body.add_child(label)
	var field := OptionButton.new(); _body.add_child(field)
	for option: StringName in values:
		field.add_item(String(option).replace("_", " ")); field.set_item_metadata(field.item_count - 1, option)
		if option == value: field.select(field.item_count - 1)
	field.item_selected.connect(func(index): document.update_entry(selected_id, {key: field.get_item_metadata(index)}); entry_changed.emit())


func _add_flag_list(values: Array) -> void:
	var label := Label.new(); label.text = "PREREQUISITE FLAGS (COMMA SEPARATED)"; _body.add_child(label)
	var field := LineEdit.new(); field.text = ", ".join(values); _body.add_child(field)
	field.text_submitted.connect(func(text):
		var flags: Array[StringName] = []
		for part in text.split(","):
			var flag := StringName(part.strip_edges())
			if not flag.is_empty(): flags.append(flag)
		document.update_entry(selected_id, {"prerequisite_flags": flags}); entry_changed.emit()
	)


func _clear() -> void:
	for child in _body.get_children(): child.queue_free()
func _empty() -> void:
	if _body == null: return
	_clear(); var label := Label.new(); label.text = "INSPECTOR\nNothing selected\n\nEditor selection and graph layout are never stored in runtime Resources."; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _body.add_child(label)
