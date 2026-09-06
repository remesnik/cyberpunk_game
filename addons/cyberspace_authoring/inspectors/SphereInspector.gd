@tool
class_name SphereAuthoringInspector
extends VBoxContainer

signal definition_changed

var document: CyberspaceContentDocument
var sphere_id: StringName

func set_sphere(p_document: CyberspaceContentDocument, p_sphere_id: StringName) -> void:
	document = p_document
	sphere_id = p_sphere_id
	_rebuild()

func _rebuild() -> void:
	for child in get_children(): child.queue_free()
	if document == null: return
	var sphere := document.find_entry(sphere_id)
	if sphere.is_empty(): return
	_heading("SPHERE IDENTITY")
	_readonly("STABLE ID", String(sphere_id), "IDs are immutable after creation so node and story references remain stable.")
	var name_field := LineEdit.new(); name_field.text = sphere.get("display_name", sphere_id); name_field.tooltip_text = "Designer-facing subnet name. This does not change the stable ID."; add_child(name_field)
	name_field.text_submitted.connect(func(value): document.update_entry(sphere_id, {"display_name": value}); definition_changed.emit(); _rebuild())

	_heading("INITIAL SECURITY")
	var sleeve_picker := OptionButton.new(); sleeve_picker.tooltip_text = "Security Sleeve originally associated with this persistent Sphere."; add_child(sleeve_picker)
	sleeve_picker.add_item("NONE"); sleeve_picker.set_item_metadata(0, &"")
	var selected_sleeve: StringName = sphere.get("original_security_sleeve_id", &"")
	for sleeve: Dictionary in document.security_sleeves:
		sleeve_picker.add_item("%s // %s" % [sleeve.get("display_name", sleeve.id), sleeve.id]); sleeve_picker.set_item_metadata(sleeve_picker.item_count - 1, sleeve.id)
		if sleeve.id == selected_sleeve: sleeve_picker.select(sleeve_picker.item_count - 1)
	sleeve_picker.item_selected.connect(func(index): document.update_entry(sphere_id, {"original_security_sleeve_id": sleeve_picker.get_item_metadata(index)}); definition_changed.emit(); _rebuild())
	if selected_sleeve == &"":
		var create_sleeve := Button.new(); create_sleeve.text = "CREATE INITIAL SECURITY SLEEVE"; create_sleeve.tooltip_text = "Creates an intact Sleeve from the Sphere's current derived members and associates it as historical origin."; add_child(create_sleeve)
		create_sleeve.pressed.connect(_create_initial_sleeve)
	if selected_sleeve != &"":
		var sleeve := document.find_entry(selected_sleeve)
		var grouping := "INVALID REFERENCE"
		if not sleeve.is_empty(): grouping = "%s // %s" % [sleeve.get("state", &"MISSING"), sleeve.get("current_members", [])]
		_readonly("CURRENT GROUPING", grouping)

	_heading("MEMBERS // DERIVED FROM NODE sphere_id")
	var members := document.sphere_members(sphere_id)
	_readonly("MEMBER COUNT", str(members.size()))
	for node: Dictionary in document.network_nodes:
		var toggle := CheckBox.new(); toggle.text = "%s // %s" % [node.id, node.get("display_name", node.id)]; toggle.button_pressed = members.has(node.id); toggle.tooltip_text = "Assign this node to the Sphere. A node can belong to exactly one Sphere."; add_child(toggle)
		toggle.toggled.connect(_on_node_membership_toggled.bind(node.id))

	_heading("EXTERNAL CONNECTIONS // DERIVED FROM LINKS")
	var connections := document.sphere_connections(sphere_id)
	if connections.is_empty(): _readonly("STATUS", "No authored cross-Sphere links")
	for link: Dictionary in connections:
		_readonly(String(link.id), "%s (%s)  ->  %s (%s)" % [link.source, link.source_sphere_id, link.destination, link.destination_sphere_id])

func _heading(text: String) -> void:
	var label := Label.new(); label.text = text; label.add_theme_color_override("font_color", Color("56e8ff")); add_child(label)

func _readonly(label_text: String, value: String, tooltip := "") -> void:
	var label := Label.new(); label.text = "%s\n%s" % [label_text, value]; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.tooltip_text = tooltip; add_child(label)

func _on_node_membership_toggled(enabled: bool, node_id: StringName) -> void:
	document.assign_node_to_sphere(node_id, sphere_id if enabled else &"")
	definition_changed.emit()
	_rebuild()

func _create_initial_sleeve() -> void:
	var candidate := StringName("%s_SLEEVE" % sphere_id)
	var serial := 2
	while not document.find_entry(candidate).is_empty():
		candidate = StringName("%s_SLEEVE_%02d" % [sphere_id, serial]); serial += 1
	document.add_entry(&"security_sleeves", {"id": candidate, "display_name": "%s Security Sleeve" % document.find_entry(sphere_id).get("display_name", sphere_id), "current_members": document.sphere_members(sphere_id), "state": &"INTACT", "metadata": {}})
	document.update_entry(sphere_id, {"original_security_sleeve_id": candidate})
	definition_changed.emit()
	_rebuild()
