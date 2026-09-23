class_name NetworkAuthoringHUD
extends CanvasLayer

signal object_chosen(kind: int, object_id: StringName)
signal move_requested
signal add_connected_node_requested
signal delete_node_requested
signal delete_path_requested
signal node_type_requested(node_type: int)
signal path_lock_requested(locked: bool)
signal add_service_requested(service_type: StringName)
signal remove_service_requested
signal configure_service_requested(values: Dictionary)
signal add_stationary_ice_requested(definition_id: StringName)
signal add_mobile_ice_requested(definition_id: StringName, starting_node_id: StringName)
signal remove_ice_requested
signal configure_ice_requested(values: Dictionary)
signal create_sphere_requested
signal delete_sphere_requested
signal add_node_to_sphere_requested(sphere_id: StringName)
signal remove_node_from_sphere_requested
signal edit_sphere_security_requested(values: Dictionary)
signal save_requested
signal save_as_requested
signal load_requested
signal mode_toggle_requested
signal close_requested
signal undo_requested
signal redo_requested
signal duplicate_node_requested
signal delete_selection_requested
signal nodes_chosen(node_ids: Array[StringName])
signal jump_to_node_requested(node_id: StringName)
signal overlay_toggled(name: StringName, enabled: bool)

var indicator: Label
var picker: OptionButton
var inspector: RichTextLabel
var move_button: Button
var node_type_picker: OptionButton
var add_node_button: Button
var delete_node_button: Button
var lock_path_button: Button
var unlock_path_button: Button
var delete_path_button: Button
var feedback: Label
var service_type_picker: OptionButton
var add_service_button: Button
var service_name_edit: LineEdit
var service_security: SpinBox
var configure_service_button: Button
var remove_service_button: Button
var ice_type_picker: OptionButton
var ice_start_picker: OptionButton
var add_stationary_ice_button: Button
var add_mobile_ice_button: Button
var ice_state_picker: OptionButton
var ice_active: CheckBox
var ice_detection: SpinBox
var ice_patrol_edit: LineEdit
var configure_ice_button: Button
var remove_ice_button: Button
var _ice_definition_ids: Array[StringName] = []
var _ice_start_ids: Array[StringName] = []
var sphere_picker: OptionButton
var sphere_name_edit: LineEdit
var sphere_enabled: CheckBox
var sphere_tier: SpinBox
var sphere_access_modifier: SpinBox
var sphere_path_modifier: SpinBox
var sphere_trace_pressure: SpinBox
var create_sphere_button: Button
var delete_sphere_button: Button
var add_to_sphere_button: Button
var remove_from_sphere_button: Button
var edit_sphere_button: Button
var _sphere_ids: Array[StringName] = []
var _choices: Array[Dictionary] = []
var breadcrumbs: Label
var dirty_label: Label
var undo_button: Button
var redo_button: Button
var node_search: LineEdit
var node_multi_select: ItemList
var _node_choice_ids: Array[StringName] = []
var context_menu: MenuButton
var mode_button: Button

func _ready() -> void:
	layer = 90
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-380, 18)
	panel.size = Vector2(390, 820)
	add_child(panel)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
	var box := VBoxContainer.new(); box.custom_minimum_size.x = 360; scroll.add_child(box)
	indicator = Label.new()
	indicator.add_theme_color_override("font_color", Color("ffca3a"))
	indicator.add_theme_font_size_override("font_size", 20)
	box.add_child(indicator)
	var hint := Label.new()
	hint.text = "F9: GOD / TEST  F10: EXIT  Ctrl+S: SAVE  Ctrl+Z: UNDO"
	box.add_child(hint)
	breadcrumbs = Label.new(); breadcrumbs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(breadcrumbs)
	dirty_label = Label.new(); dirty_label.add_theme_color_override("font_color", Color("ffca3a")); box.add_child(dirty_label)
	var file_row := HBoxContainer.new(); box.add_child(file_row)
	var save_button := Button.new(); save_button.text = "SAVE"; save_button.pressed.connect(func(): save_requested.emit()); file_row.add_child(save_button)
	var save_as_button := Button.new(); save_as_button.text = "SAVE AS"; save_as_button.pressed.connect(func(): save_as_requested.emit()); file_row.add_child(save_as_button)
	var load_button := Button.new(); load_button.text = "LOAD"; load_button.pressed.connect(func(): load_requested.emit()); file_row.add_child(load_button)
	undo_button = Button.new(); undo_button.text = "UNDO"; undo_button.pressed.connect(func(): undo_requested.emit()); file_row.add_child(undo_button)
	redo_button = Button.new(); redo_button.text = "REDO"; redo_button.pressed.connect(func(): redo_requested.emit()); file_row.add_child(redo_button)
	var search_row := HBoxContainer.new(); box.add_child(search_row)
	node_search = LineEdit.new(); node_search.placeholder_text = "Jump to node ID"; node_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL; node_search.text_submitted.connect(func(value: String): jump_to_node_requested.emit(StringName(value))); search_row.add_child(node_search)
	var jump_button := Button.new(); jump_button.text = "JUMP"; jump_button.pressed.connect(func(): jump_to_node_requested.emit(StringName(node_search.text))); search_row.add_child(jump_button)
	var overlay_row := HBoxContainer.new(); box.add_child(overlay_row)
	_add_overlay_toggle(overlay_row, "IDs", &"IDS", true)
	_add_overlay_toggle(overlay_row, "Locks", &"PATH_LOCKS", true)
	_add_overlay_toggle(overlay_row, "Spheres", &"SPHERE_BOUNDARIES", true)
	_add_overlay_toggle(overlay_row, "ICE", &"ICE_ASSIGNMENTS", true)
	node_multi_select = ItemList.new(); node_multi_select.select_mode = ItemList.SELECT_MULTI; node_multi_select.custom_minimum_size.y = 90; node_multi_select.item_selected.connect(_emit_node_selection); box.add_child(node_multi_select)
	var selection_row := HBoxContainer.new(); box.add_child(selection_row)
	var duplicate_button := Button.new(); duplicate_button.text = "DUPLICATE NODE"; duplicate_button.pressed.connect(func(): duplicate_node_requested.emit()); selection_row.add_child(duplicate_button)
	var delete_selection_button := Button.new(); delete_selection_button.text = "DELETE SELECTION"; delete_selection_button.pressed.connect(func(): delete_selection_requested.emit()); selection_row.add_child(delete_selection_button)
	picker = OptionButton.new()
	picker.item_selected.connect(_on_item_selected)
	box.add_child(picker)
	inspector = RichTextLabel.new()
	inspector.fit_content = false
	inspector.custom_minimum_size = Vector2(350, 140)
	inspector.bbcode_enabled = true
	box.add_child(inspector)
	context_menu = MenuButton.new(); context_menu.text = "CONTEXT ACTIONS"; context_menu.get_popup().id_pressed.connect(_on_context_action); box.add_child(context_menu)
	node_type_picker = OptionButton.new()
	for type_name: String in NetworkNodeDefinition.NodeType.keys(): node_type_picker.add_item(type_name.capitalize())
	node_type_picker.item_selected.connect(func(index: int): node_type_requested.emit(index))
	box.add_child(node_type_picker)
	move_button = Button.new()
	move_button.text = "MOVE AUTHOR TO NODE"
	move_button.pressed.connect(func(): move_requested.emit())
	box.add_child(move_button)
	add_node_button = Button.new(); add_node_button.text = "ADD CONNECTED NODE"; add_node_button.pressed.connect(func(): add_connected_node_requested.emit()); box.add_child(add_node_button)
	delete_node_button = Button.new(); delete_node_button.text = "DELETE NODE"; delete_node_button.pressed.connect(func(): delete_node_requested.emit()); box.add_child(delete_node_button)
	var path_row := HBoxContainer.new(); box.add_child(path_row)
	lock_path_button = Button.new(); lock_path_button.text = "LOCK PATH"; lock_path_button.pressed.connect(func(): path_lock_requested.emit(true)); path_row.add_child(lock_path_button)
	unlock_path_button = Button.new(); unlock_path_button.text = "UNLOCK PATH"; unlock_path_button.pressed.connect(func(): path_lock_requested.emit(false)); path_row.add_child(unlock_path_button)
	delete_path_button = Button.new(); delete_path_button.text = "DELETE PATH"; delete_path_button.pressed.connect(func(): delete_path_requested.emit()); box.add_child(delete_path_button)
	service_type_picker = OptionButton.new(); box.add_child(service_type_picker)
	add_service_button = Button.new(); add_service_button.text = "ADD SERVICE"; add_service_button.pressed.connect(func(): add_service_requested.emit(StringName(service_type_picker.get_item_metadata(service_type_picker.selected)))); box.add_child(add_service_button)
	service_name_edit = LineEdit.new(); service_name_edit.placeholder_text = "Service name"; box.add_child(service_name_edit)
	service_security = SpinBox.new(); service_security.min_value = 0; service_security.max_value = 99; service_security.prefix = "Security "; box.add_child(service_security)
	configure_service_button = Button.new(); configure_service_button.text = "CONFIGURE SERVICE"; configure_service_button.pressed.connect(func(): configure_service_requested.emit({"display_name": service_name_edit.text, "service_type": StringName(service_type_picker.get_item_metadata(service_type_picker.selected)), "security_level": int(service_security.value)})); box.add_child(configure_service_button)
	remove_service_button = Button.new(); remove_service_button.text = "REMOVE SERVICE"; remove_service_button.pressed.connect(func(): remove_service_requested.emit()); box.add_child(remove_service_button)
	ice_type_picker = OptionButton.new(); box.add_child(ice_type_picker)
	ice_start_picker = OptionButton.new(); box.add_child(ice_start_picker)
	add_stationary_ice_button = Button.new(); add_stationary_ice_button.text = "ADD STATIONARY ICE"; add_stationary_ice_button.pressed.connect(func(): add_stationary_ice_requested.emit(_selected_ice_definition())); box.add_child(add_stationary_ice_button)
	add_mobile_ice_button = Button.new(); add_mobile_ice_button.text = "ADD MOBILE ICE"; add_mobile_ice_button.pressed.connect(func(): add_mobile_ice_requested.emit(_selected_ice_definition(), _selected_ice_start())); box.add_child(add_mobile_ice_button)
	ice_state_picker = OptionButton.new()
	for state_name: String in IceState.Value.keys(): ice_state_picker.add_item(state_name.capitalize())
	box.add_child(ice_state_picker)
	ice_active = CheckBox.new(); ice_active.text = "Initially active / enabled"; box.add_child(ice_active)
	ice_detection = SpinBox.new(); ice_detection.min_value = 0; ice_detection.max_value = 99; ice_detection.prefix = "Detection / aggression "; box.add_child(ice_detection)
	ice_patrol_edit = LineEdit.new(); ice_patrol_edit.placeholder_text = "Patrol node IDs, comma separated"; box.add_child(ice_patrol_edit)
	configure_ice_button = Button.new(); configure_ice_button.text = "CONFIGURE ICE"; configure_ice_button.pressed.connect(_emit_ice_configuration); box.add_child(configure_ice_button)
	remove_ice_button = Button.new(); remove_ice_button.text = "REMOVE ICE"; remove_ice_button.pressed.connect(func(): remove_ice_requested.emit()); box.add_child(remove_ice_button)
	sphere_picker = OptionButton.new(); box.add_child(sphere_picker)
	create_sphere_button = Button.new(); create_sphere_button.text = "CREATE SPHERE"; create_sphere_button.pressed.connect(func(): create_sphere_requested.emit()); box.add_child(create_sphere_button)
	add_to_sphere_button = Button.new(); add_to_sphere_button.text = "ADD NODE TO SPHERE"; add_to_sphere_button.pressed.connect(func(): add_node_to_sphere_requested.emit(_selected_sphere_id())); box.add_child(add_to_sphere_button)
	remove_from_sphere_button = Button.new(); remove_from_sphere_button.text = "REMOVE NODE FROM SPHERE"; remove_from_sphere_button.pressed.connect(func(): remove_node_from_sphere_requested.emit()); box.add_child(remove_from_sphere_button)
	delete_sphere_button = Button.new(); delete_sphere_button.text = "DELETE SPHERE"; delete_sphere_button.pressed.connect(func(): delete_sphere_requested.emit()); box.add_child(delete_sphere_button)
	sphere_name_edit = LineEdit.new(); sphere_name_edit.placeholder_text = "Sphere authoring name"; box.add_child(sphere_name_edit)
	sphere_enabled = CheckBox.new(); sphere_enabled.text = "Security Sleeve enabled"; box.add_child(sphere_enabled)
	sphere_tier = SpinBox.new(); sphere_tier.min_value = 0; sphere_tier.max_value = 99; sphere_tier.prefix = "Security tier "; box.add_child(sphere_tier)
	sphere_access_modifier = SpinBox.new(); sphere_access_modifier.min_value = 0; sphere_access_modifier.max_value = 99; sphere_access_modifier.prefix = "Access difficulty +"; box.add_child(sphere_access_modifier)
	sphere_path_modifier = SpinBox.new(); sphere_path_modifier.min_value = 0; sphere_path_modifier.max_value = 99; sphere_path_modifier.prefix = "Path difficulty +"; box.add_child(sphere_path_modifier)
	sphere_trace_pressure = SpinBox.new(); sphere_trace_pressure.min_value = 0; sphere_trace_pressure.max_value = 99; sphere_trace_pressure.prefix = "Trace pressure "; box.add_child(sphere_trace_pressure)
	edit_sphere_button = Button.new(); edit_sphere_button.text = "EDIT SPHERE SECURITY"; edit_sphere_button.pressed.connect(_emit_sphere_security); box.add_child(edit_sphere_button)
	feedback = Label.new(); feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(feedback)
	var row := HBoxContainer.new()
	box.add_child(row)
	mode_button = Button.new(); mode_button.text = "[ GOD MODE ]  <->  [ TEST AS PLAYER ]"; mode_button.pressed.connect(func(): mode_toggle_requested.emit()); row.add_child(mode_button)
	var close_button := Button.new(); close_button.text = "EXIT AUTHORING"; close_button.pressed.connect(func(): close_requested.emit()); row.add_child(close_button)

func set_mode(mode_label: String) -> void:
	indicator.text = "DEBUG AUTHORING // %s" % mode_label
	mode_button.text = "[ GOD MODE ]  <->  [ TEST AS PLAYER ]\nCURRENT: %s" % mode_label.replace("AUTHOR_", "")

func set_history_state(can_undo: bool, can_redo: bool, dirty: bool) -> void:
	undo_button.disabled = not can_undo
	redo_button.disabled = not can_redo
	dirty_label.text = "● UNSAVED CHANGES" if dirty else "SAVED"

func set_breadcrumbs(value: String) -> void:
	breadcrumbs.text = value

func set_node_choices(nodes: Array[Dictionary], selected_ids: Array[StringName]) -> void:
	_node_choice_ids.clear(); node_multi_select.clear()
	for index in nodes.size():
		_node_choice_ids.append(StringName(nodes[index].id)); node_multi_select.add_item(String(nodes[index].label))
		if selected_ids.has(StringName(nodes[index].id)): node_multi_select.select(index, false)

func set_choices(choices: Array[Dictionary], selected_kind: int, selected_id: StringName) -> void:
	_choices = choices.duplicate(true)
	picker.clear()
	var chosen := -1
	for index in _choices.size():
		var choice := _choices[index]
		picker.add_item("%s // %s" % [choice.kind_label, choice.label])
		if int(choice.kind) == selected_kind and StringName(choice.id) == selected_id: chosen = index
	if chosen >= 0: picker.select(chosen)

func set_inspector(text: String, can_mutate: bool, selected_kind: int, node_type: int = -1, path_locked := false) -> void:
	inspector.text = text
	var node_selected := selected_kind == NetworkSelectionState.Kind.NODE
	var path_selected := selected_kind == NetworkSelectionState.Kind.PATH
	move_button.visible = can_mutate and node_selected
	add_node_button.visible = can_mutate and node_selected
	delete_node_button.visible = can_mutate and node_selected
	node_type_picker.visible = can_mutate and node_selected
	if node_selected and node_type >= 0: node_type_picker.select(node_type)
	lock_path_button.visible = can_mutate and path_selected and not path_locked
	unlock_path_button.visible = can_mutate and path_selected and path_locked
	delete_path_button.visible = can_mutate and path_selected
	var service_selected := selected_kind == NetworkSelectionState.Kind.SERVICE
	var ice_selected := selected_kind == NetworkSelectionState.Kind.ICE
	service_type_picker.visible = can_mutate and (node_selected or service_selected)
	add_service_button.visible = can_mutate and node_selected
	service_name_edit.visible = can_mutate and service_selected
	service_security.visible = can_mutate and service_selected
	configure_service_button.visible = can_mutate and service_selected
	remove_service_button.visible = can_mutate and service_selected
	ice_type_picker.visible = can_mutate and (node_selected or selected_kind in [NetworkSelectionState.Kind.SPHERE, NetworkSelectionState.Kind.SECURITY_SLEEVE])
	ice_start_picker.visible = can_mutate and (ice_selected or selected_kind in [NetworkSelectionState.Kind.SPHERE, NetworkSelectionState.Kind.SECURITY_SLEEVE])
	add_stationary_ice_button.visible = can_mutate and node_selected
	add_mobile_ice_button.visible = can_mutate and selected_kind in [NetworkSelectionState.Kind.SPHERE, NetworkSelectionState.Kind.SECURITY_SLEEVE]
	for control in [ice_state_picker, ice_active, ice_detection, ice_patrol_edit, configure_ice_button, remove_ice_button]: control.visible = can_mutate and ice_selected
	var sphere_context := selected_kind in [NetworkSelectionState.Kind.SPHERE, NetworkSelectionState.Kind.SECURITY_SLEEVE] or node_selected
	sphere_picker.visible = can_mutate and node_selected
	create_sphere_button.visible = can_mutate and node_selected
	add_to_sphere_button.visible = can_mutate and node_selected
	remove_from_sphere_button.visible = can_mutate and node_selected
	delete_sphere_button.visible = can_mutate and selected_kind == NetworkSelectionState.Kind.SPHERE
	for control in [sphere_name_edit, sphere_enabled, sphere_tier, sphere_access_modifier, sphere_path_modifier, sphere_trace_pressure, edit_sphere_button]: control.visible = can_mutate and sphere_context
	_rebuild_context_menu(can_mutate, selected_kind, path_locked)

func _rebuild_context_menu(can_mutate: bool, selected_kind: int, path_locked: bool) -> void:
	var popup := context_menu.get_popup(); popup.clear(); context_menu.visible = can_mutate and selected_kind != NetworkSelectionState.Kind.NONE
	if selected_kind == NetworkSelectionState.Kind.NODE:
		popup.add_item("Add Connected Node", 1); popup.add_item("Duplicate Node", 2); popup.add_item("Change Node Type (use list below)", 3)
		popup.add_separator("Services >"); popup.add_item("Add Selected Service", 4)
		popup.add_separator("Stationary ICE >"); popup.add_item("Add Selected Stationary ICE", 5)
		popup.add_separator("Sphere >"); popup.add_item("Add to Selected Sphere", 6); popup.add_item("Create Sphere", 7)
		popup.add_separator(); popup.add_item("Delete Node / Selection", 8)
	elif selected_kind == NetworkSelectionState.Kind.PATH:
		popup.add_item("Unlock" if path_locked else "Lock", 9); popup.add_item("Delete Path", 10)
	elif selected_kind in [NetworkSelectionState.Kind.SPHERE, NetworkSelectionState.Kind.SECURITY_SLEEVE]:
		popup.add_item("Edit Security Sleeve", 11); popup.add_item("Add Mobile ICE", 12); popup.add_item("Remove Selected Mobile ICE", 13); popup.add_item("Delete Sphere", 14)

func _on_context_action(id: int) -> void:
	match id:
		1: add_connected_node_requested.emit()
		2: duplicate_node_requested.emit()
		3: node_type_picker.grab_focus()
		4: add_service_requested.emit(StringName(service_type_picker.get_item_metadata(service_type_picker.selected)))
		5: add_stationary_ice_requested.emit(_selected_ice_definition())
		6: add_node_to_sphere_requested.emit(_selected_sphere_id())
		7: create_sphere_requested.emit()
		8: delete_selection_requested.emit()
		9: path_lock_requested.emit(lock_path_button.visible)
		10: delete_path_requested.emit()
		11: _emit_sphere_security()
		12: add_mobile_ice_requested.emit(_selected_ice_definition(), _selected_ice_start())
		13: remove_ice_requested.emit()
		14: delete_sphere_requested.emit()

func _add_overlay_toggle(parent: Control, label: String, key: StringName, enabled: bool) -> void:
	var toggle := CheckBox.new(); toggle.text = label; toggle.button_pressed = enabled; toggle.toggled.connect(func(value: bool): overlay_toggled.emit(key, value)); parent.add_child(toggle)

func _emit_node_selection(_index: int) -> void:
	var ids: Array[StringName] = []
	for selected_index in node_multi_select.get_selected_items(): ids.append(_node_choice_ids[selected_index])
	nodes_chosen.emit(ids)

func show_feedback(message: String, success: bool) -> void:
	feedback.text = message
	feedback.add_theme_color_override("font_color", Color("8dffb0") if success else Color("ff7676"))

func set_content_options(service_types: Array[StringName], ice_definitions: Array[Dictionary], start_nodes: Array[Dictionary], selected_service: NodeServiceDefinition, selected_ice: IceInstance) -> void:
	service_type_picker.clear()
	for service_type in service_types: service_type_picker.add_item(String(service_type).replace("_", " ").capitalize()); service_type_picker.set_item_metadata(service_type_picker.item_count - 1, service_type)
	_ice_definition_ids.clear(); ice_type_picker.clear()
	for record in ice_definitions: _ice_definition_ids.append(record.id); ice_type_picker.add_item(record.label)
	_ice_start_ids.clear(); ice_start_picker.clear()
	for record in start_nodes: _ice_start_ids.append(record.id); ice_start_picker.add_item(record.label)
	if selected_service != null:
		service_name_edit.text = selected_service.display_name; service_security.value = selected_service.security_level
		for index in service_type_picker.item_count:
			if StringName(service_type_picker.get_item_metadata(index)) == selected_service.service_type: service_type_picker.select(index); break
	if selected_ice != null:
		ice_state_picker.select(int(selected_ice.state)); ice_active.button_pressed = selected_ice.operational; ice_detection.value = selected_ice.definition.detection_capability
		ice_patrol_edit.text = ", ".join(selected_ice.definition.patrol_route)
		for index in _ice_start_ids.size():
			if _ice_start_ids[index] == selected_ice.current_node_id: ice_start_picker.select(index); break

func set_sphere_options(spheres: Array[Dictionary], current_sphere: SphereDefinition, sleeve: SecuritySleeve) -> void:
	_sphere_ids.clear(); sphere_picker.clear()
	for record in spheres: _sphere_ids.append(record.id); sphere_picker.add_item(record.label)
	if current_sphere != null:
		sphere_name_edit.text = current_sphere.display_name
		for index in _sphere_ids.size():
			if _sphere_ids[index] == current_sphere.id: sphere_picker.select(index); break
	if sleeve != null:
		sphere_enabled.button_pressed = sleeve.state != SecuritySleeve.State.DISABLED
		sphere_tier.visible = edit_sphere_button.visible and sleeve.metadata.has("security_tier")
		sphere_tier.value = int(sleeve.metadata.get("security_tier", 0))
		sphere_access_modifier.value = int(sleeve.metadata.get("access_difficulty_modifier", 0))
		sphere_path_modifier.value = int(sleeve.metadata.get("path_unlock_difficulty_modifier", 0))
		sphere_trace_pressure.value = int(sleeve.metadata.get("system_trace_pressure", 0))

func _selected_ice_definition() -> StringName:
	return _ice_definition_ids[ice_type_picker.selected] if ice_type_picker.selected >= 0 and ice_type_picker.selected < _ice_definition_ids.size() else &""

func _selected_ice_start() -> StringName:
	return _ice_start_ids[ice_start_picker.selected] if ice_start_picker.selected >= 0 and ice_start_picker.selected < _ice_start_ids.size() else &""

func _emit_ice_configuration() -> void:
	var patrol: Array[StringName] = []
	for value in ice_patrol_edit.text.split(",", false): patrol.append(StringName(value.strip_edges()))
	configure_ice_requested.emit({"current_node_id": _selected_ice_start(), "state": ice_state_picker.selected, "operational": ice_active.button_pressed, "detection_capability": int(ice_detection.value), "patrol_route": patrol})

func _selected_sphere_id() -> StringName:
	return _sphere_ids[sphere_picker.selected] if sphere_picker.selected >= 0 and sphere_picker.selected < _sphere_ids.size() else &""

func _emit_sphere_security() -> void:
	var values := {"display_name": sphere_name_edit.text, "enabled": sphere_enabled.button_pressed, "access_difficulty_modifier": int(sphere_access_modifier.value), "path_unlock_difficulty_modifier": int(sphere_path_modifier.value), "system_trace_pressure": int(sphere_trace_pressure.value)}
	if sphere_tier.visible: values["security_tier"] = int(sphere_tier.value)
	edit_sphere_security_requested.emit(values)

func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _choices.size(): return
	var choice := _choices[index]
	object_chosen.emit(int(choice.kind), StringName(choice.id))
