class_name NetworkAuthoringController
extends Node

## Debug authoring adapts the live gameplay NetworkGraph. It never creates a
## parallel graph and never writes temporary selection/UI state into authored data.
var state := NetworkAuthoringState.new()
var selection := NetworkSelectionState.new()
var display: NetworkDisplay
var graph: NetworkGraph
var position: PlayerNetworkPosition
var hud: NetworkAuthoringHUD
var command_history: Array[NetworkAuthorCommand] = []
var redo_history: Array[NetworkAuthorCommand] = []
var saved_history: Array[NetworkAuthorCommand] = []
var _test_snapshot: Dictionary = {}
var _next_node_serial := 1
var _next_path_serial := 1
var _next_service_serial := 1
var _next_ice_serial := 1
var _next_sphere_serial := 1
var current_document_path := ""
var loaded_document_template: NetworkDocument
var _save_dialog: FileDialog
var _load_dialog: FileDialog

func configure(p_display: NetworkDisplay) -> void:
	display = p_display
	refresh_runtime_references()
	_adopt_active_network_document()
	set_process_unhandled_input(true)

func refresh_runtime_references() -> void:
	graph = Game.network_graph
	position = Game.player_network_position

func _adopt_active_network_document() -> void:
	## Story Mode and debug authoring share one package. Remember the loaded
	## document so Ctrl+S edits topology without discarding mission metadata.
	if loaded_document_template != null or not current_document_path.is_empty(): return
	var path := String(Game.active_content_profile.get("runtime_document_path", ""))
	if path.get_extension().to_lower() != "netspace": return
	var result := NetworkDocumentSerializer.load_file(path)
	if not bool(result.get("success", false)):
		push_error("Authoring could not adopt active network '%s': %s" % [path, JSON.stringify(result.get("issues", []))])
		return
	current_document_path = path
	loaded_document_template = result.document

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey) or not event.pressed or event.echo: return
	if event.keycode == KEY_F10:
		set_mode(NetworkAuthoringState.Mode.PLAYER if state.is_authoring() else NetworkAuthoringState.Mode.AUTHOR_GOD)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F9 and state.is_authoring():
		set_mode(NetworkAuthoringState.Mode.AUTHOR_TEST if state.is_god() else NetworkAuthoringState.Mode.AUTHOR_GOD)
		get_viewport().set_input_as_handled()
	elif state.is_authoring() and event.ctrl_pressed and event.keycode == KEY_S:
		if event.shift_pressed or current_document_path.is_empty(): _show_save_as()
		else: save_current_network(current_document_path)
		get_viewport().set_input_as_handled()
	elif state.is_authoring() and event.ctrl_pressed and event.keycode == KEY_O:
		_show_load(); get_viewport().set_input_as_handled()
	elif is_god_mode() and event.ctrl_pressed and event.keycode == KEY_Z:
		if event.shift_pressed: redo()
		else: undo()
		get_viewport().set_input_as_handled()
	elif is_god_mode() and event.keycode == KEY_DELETE:
		delete_selection(); get_viewport().set_input_as_handled()

func set_mode(next_mode: NetworkAuthoringState.Mode) -> bool:
	if next_mode != NetworkAuthoringState.Mode.PLAYER and not OS.is_debug_build():
		push_error("Network authoring entry rejected: this is not a debug build.")
		return false
	refresh_runtime_references()
	_adopt_active_network_document()
	if state.mode == NetworkAuthoringState.Mode.AUTHOR_GOD and next_mode == NetworkAuthoringState.Mode.AUTHOR_TEST:
		_begin_test_as_player()
	elif state.mode == NetworkAuthoringState.Mode.AUTHOR_TEST and next_mode != NetworkAuthoringState.Mode.AUTHOR_TEST:
		_end_test_as_player()
	state.mode = next_mode
	Game.set_debug_author_god_mode(state.is_god())
	if display != null: display.set_debug_authoring_reveal_all(state.is_god())
	if state.is_authoring():
		_ensure_hud()
		_refresh_hud()
	else:
		selection.clear()
		if hud != null: hud.queue_free(); hud = null
	return true

func is_god_mode() -> bool:
	return OS.is_debug_build() and state.is_god()

func select_object(kind: int, object_id: StringName) -> void:
	if not state.is_authoring(): return
	selection.select(kind as NetworkSelectionState.Kind, object_id)
	if display != null: display.set_debug_authoring_selection(kind, object_id)
	_refresh_hud()

func select_nodes(node_ids: Array[StringName]) -> void:
	if not state.is_authoring(): return
	selection.select_nodes(node_ids)
	if display != null: display.set_debug_authoring_node_selection(node_ids)
	_refresh_hud()

func jump_to_node(node_id: StringName) -> Dictionary:
	var normalized := StringName(String(node_id).strip_edges())
	if graph == null or graph.get_node(normalized) == null: return _feedback({"success": false, "reason": "Node ID not found: %s" % normalized})
	select_object(NetworkSelectionState.Kind.NODE, normalized)
	return move_author_to_node(normalized) if is_god_mode() else {"success": true, "reason": "Node selected"}

func move_author_to_node(node_id: StringName) -> Dictionary:
	if not is_god_mode(): return {"success": false, "reason": "AUTHOR_GOD required"}
	refresh_runtime_references()
	if graph == null or position == null or graph.get_node(node_id) == null: return {"success": false, "reason": "Unknown node"}
	# Direct relocation is an authoring operation: no traversal tick, lock check,
	# trace, ICE update, or persistent graph mutation is performed.
	position.relocate(node_id)
	EventBus.network_display_update_requested.emit()
	return {"success": true, "reason": "Author relocated"}

func _ensure_hud() -> void:
	if hud != null: return
	hud = NetworkAuthoringHUD.new()
	add_child(hud)
	hud.object_chosen.connect(select_object)
	hud.nodes_chosen.connect(select_nodes)
	hud.jump_to_node_requested.connect(jump_to_node)
	hud.undo_requested.connect(undo)
	hud.redo_requested.connect(redo)
	hud.duplicate_node_requested.connect(duplicate_selected_node)
	hud.delete_selection_requested.connect(delete_selection)
	hud.overlay_toggled.connect(_set_overlay)
	hud.move_requested.connect(func():
		if selection.kind == NetworkSelectionState.Kind.NODE: move_author_to_node(selection.object_id))
	hud.add_connected_node_requested.connect(add_connected_node)
	hud.delete_node_requested.connect(delete_selected_node)
	hud.delete_path_requested.connect(delete_selected_path)
	hud.node_type_requested.connect(set_selected_node_type)
	hud.path_lock_requested.connect(set_selected_path_locked)
	hud.add_service_requested.connect(add_service)
	hud.remove_service_requested.connect(remove_selected_service)
	hud.configure_service_requested.connect(configure_selected_service)
	hud.add_stationary_ice_requested.connect(add_stationary_ice)
	hud.add_mobile_ice_requested.connect(add_mobile_ice)
	hud.remove_ice_requested.connect(remove_context_ice)
	hud.configure_ice_requested.connect(configure_selected_ice)
	hud.create_sphere_requested.connect(create_sphere)
	hud.delete_sphere_requested.connect(delete_selected_sphere)
	hud.add_node_to_sphere_requested.connect(add_selected_node_to_sphere)
	hud.remove_node_from_sphere_requested.connect(remove_selected_node_from_sphere)
	hud.edit_sphere_security_requested.connect(modify_selected_sphere_security)
	hud.save_requested.connect(func(): save_current_network(current_document_path) if not current_document_path.is_empty() else _show_save_as())
	hud.save_as_requested.connect(_show_save_as)
	hud.load_requested.connect(_show_load)
	hud.mode_toggle_requested.connect(func(): set_mode(NetworkAuthoringState.Mode.AUTHOR_TEST if state.is_god() else NetworkAuthoringState.Mode.AUTHOR_GOD))
	hud.close_requested.connect(func(): set_mode(NetworkAuthoringState.Mode.PLAYER))

func _choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if graph == null: return result
	for node: NetworkNodeDefinition in graph.nodes.values(): result.append({"kind": NetworkSelectionState.Kind.NODE, "kind_label": "NODE", "id": node.id, "label": node.display_name})
	for link: NetworkLinkDefinition in graph.links.values(): result.append({"kind": NetworkSelectionState.Kind.PATH, "kind_label": "PATH", "id": link.id, "label": "%s -> %s" % [link.source, link.destination]})
	for sphere: SphereDefinition in graph.spheres.values(): result.append({"kind": NetworkSelectionState.Kind.SPHERE, "kind_label": "SPHERE", "id": sphere.id, "label": sphere.display_name})
	for sleeve: SecuritySleeve in graph.security_sleeves.values(): result.append({"kind": NetworkSelectionState.Kind.SECURITY_SLEEVE, "kind_label": "SLEEVE", "id": sleeve.id, "label": sleeve.display_name})
	for node: NetworkNodeDefinition in graph.nodes.values():
		for service: NodeServiceDefinition in node.service_definitions: result.append({"kind": NetworkSelectionState.Kind.SERVICE, "kind_label": "SERVICE", "id": service.id, "label": "%s @ %s" % [service.display_name, node.id]})
	if Game.ice_controller != null:
		for ice: IceInstance in Game.ice_controller.instances.values(): result.append({"kind": NetworkSelectionState.Kind.ICE, "kind_label": "ICE", "id": ice.instance_id, "label": ice.definition.display_name})
	return result

func _refresh_hud() -> void:
	if hud == null: return
	hud.set_mode(state.label())
	hud.set_history_state(command_history.size() > 0, redo_history.size() > 0, is_dirty())
	hud.set_choices(_choices(), selection.kind, selection.object_id)
	hud.set_node_choices(_node_choices(), selection.node_ids)
	hud.set_breadcrumbs(_selection_breadcrumbs())
	var node := graph.get_node(selection.object_id) if graph != null and selection.kind == NetworkSelectionState.Kind.NODE else null
	var path := graph.get_link(selection.object_id) if graph != null and selection.kind == NetworkSelectionState.Kind.PATH else null
	hud.set_inspector(_inspection_text(), state.is_god(), selection.kind, node.node_type if node != null else -1, path.locked if path != null else false)
	var service := _selected_service()
	var ice := Game.ice_controller.get_ice(selection.object_id) if Game.ice_controller != null and selection.kind == NetworkSelectionState.Kind.ICE else null
	hud.set_content_options(NodeServiceCatalog.ALL, _ice_definition_options(selection.kind in [NetworkSelectionState.Kind.SPHERE, NetworkSelectionState.Kind.SECURITY_SLEEVE]), _eligible_start_nodes(), service, ice)
	var current_sphere := _context_sphere()
	hud.set_sphere_options(_sphere_options(), current_sphere, graph.get_security_sleeve(current_sphere.original_security_sleeve_id) if current_sphere != null else null)

func create_sphere() -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.NODE: return _feedback({"success": false, "reason": "Select a node in AUTHOR_GOD mode"})
	var sphere_id := _unique_sphere_id()
	var sleeve_id := StringName("%s_SLEEVE" % sphere_id)
	var sphere := SphereDefinition.new(sphere_id, "Authored Sphere %d" % (_next_sphere_serial - 1), [], sleeve_id)
	var sleeve := SecuritySleeve.new(sleeve_id, "%s Security" % sphere.display_name, [selection.object_id])
	var result := _execute_command(CreateSphereCommand.new(_command_context(), sphere, sleeve, selection.object_id))
	if bool(result.get("success", false)): call_deferred("select_object", NetworkSelectionState.Kind.SPHERE, sphere_id)
	return _feedback(result)

func delete_selected_sphere() -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.SPHERE: return _feedback({"success": false, "reason": "Select a sphere in AUTHOR_GOD mode"})
	var result := _execute_command(DeleteSphereCommand.new(_command_context(), selection.object_id))
	if bool(result.get("success", false)): selection.clear()
	_refresh_hud(); return _feedback(result)

func add_selected_node_to_sphere(sphere_id: StringName) -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.NODE: return _feedback({"success": false, "reason": "Select a node in AUTHOR_GOD mode"})
	var result := _execute_command(AddNodeToSphereCommand.new(_command_context(), selection.object_id, sphere_id)); _refresh_hud(); return _feedback(result)

func remove_selected_node_from_sphere() -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.NODE: return _feedback({"success": false, "reason": "Select a node in AUTHOR_GOD mode"})
	if graph.get_node(selection.object_id).sphere_id == NetworkGraph.LEGACY_UNASSIGNED_SPHERE_ID: return _feedback({"success": false, "reason": "Node is already unassigned"})
	graph._ensure_legacy_sphere()
	var result := _execute_command(RemoveNodeFromSphereCommand.new(_command_context(), selection.object_id)); _refresh_hud(); return _feedback(result)

func modify_selected_sphere_security(values: Dictionary) -> Dictionary:
	if not is_god_mode(): return _feedback({"success": false, "reason": "AUTHOR_GOD required"})
	var sphere := _context_sphere()
	if sphere == null: return _feedback({"success": false, "reason": "Selection has no sphere"})
	var result := _execute_command(ModifySphereSecurityCommand.new(_command_context(), sphere.id, values)); _refresh_hud(); return _feedback(result)

func _context_sphere() -> SphereDefinition:
	if graph == null: return null
	if selection.kind == NetworkSelectionState.Kind.SPHERE: return graph.get_sphere(selection.object_id)
	if selection.kind == NetworkSelectionState.Kind.NODE:
		var node := graph.get_node(selection.object_id); return graph.get_sphere(node.sphere_id) if node != null else null
	if selection.kind == NetworkSelectionState.Kind.SECURITY_SLEEVE:
		for sphere: SphereDefinition in graph.spheres.values():
			if sphere.original_security_sleeve_id == selection.object_id: return sphere
	return null

func _sphere_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if graph != null:
		for sphere: SphereDefinition in graph.spheres.values(): result.append({"id": sphere.id, "label": "%s // %s" % [sphere.id, sphere.display_name]})
	return result

func _unique_sphere_id() -> StringName:
	while true:
		var candidate := StringName("AUTHOR_SPHERE_%03d" % _next_sphere_serial); _next_sphere_serial += 1
		if graph.get_sphere(candidate) == null and graph.get_security_sleeve(StringName("%s_SLEEVE" % candidate)) == null: return candidate
	return &""

func add_service(service_type: StringName) -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.NODE or not NodeServiceCatalog.is_supported(service_type): return _feedback({"success": false, "reason": "Select a node and registered service type"})
	var id := _unique_content_id(&"AUTHOR_SERVICE", true)
	var service := NodeServiceDefinition.new(id, String(service_type).replace("_", " ").capitalize(), service_type, 0)
	var result := _execute_command(AddServiceCommand.new(_command_context(), selection.object_id, service))
	if bool(result.get("success", false)): call_deferred("select_object", NetworkSelectionState.Kind.SERVICE, id)
	return _feedback(result)

func remove_selected_service() -> Dictionary:
	var owner := _service_owner(selection.object_id)
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.SERVICE or owner == null: return _feedback({"success": false, "reason": "Select a service in AUTHOR_GOD mode"})
	var result := _execute_command(RemoveServiceCommand.new(_command_context(), owner.id, selection.object_id))
	if bool(result.get("success", false)): selection.select(NetworkSelectionState.Kind.NODE, owner.id)
	EventBus.network_display_update_requested.emit(); _refresh_hud(); return _feedback(result)

func configure_selected_service(values: Dictionary) -> Dictionary:
	if not is_god_mode(): return _feedback({"success": false, "reason": "AUTHOR_GOD required"})
	var result := _execute_command(ConfigureServiceCommand.new(_command_context(), _selected_service(), values)); _refresh_hud(); return _feedback(result)

func add_stationary_ice(definition_id: StringName) -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.NODE: return _feedback({"success": false, "reason": "Select a node in AUTHOR_GOD mode"})
	return _add_ice(definition_id, selection.object_id, true)

func add_mobile_ice(definition_id: StringName, starting_node_id: StringName) -> Dictionary:
	if not is_god_mode() or selection.kind not in [NetworkSelectionState.Kind.SPHERE, NetworkSelectionState.Kind.SECURITY_SLEEVE]: return _feedback({"success": false, "reason": "Select a sphere or sleeve in AUTHOR_GOD mode"})
	if not _selected_members().has(starting_node_id): return _feedback({"success": false, "reason": "Starting node must belong to the selected boundary"})
	return _add_ice(definition_id, starting_node_id, false, selection.kind, selection.object_id)

func remove_selected_ice() -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.ICE: return _feedback({"success": false, "reason": "Select ICE in AUTHOR_GOD mode"})
	var result := _execute_command(RemoveIceCommand.new(_command_context(), selection.object_id))
	if bool(result.get("success", false)): selection.clear()
	EventBus.network_display_update_requested.emit(); _refresh_hud(); return _feedback(result)

func remove_context_ice() -> Dictionary:
	if selection.kind == NetworkSelectionState.Kind.ICE: return remove_selected_ice()
	if not is_god_mode() or selection.kind not in [NetworkSelectionState.Kind.SPHERE, NetworkSelectionState.Kind.SECURITY_SLEEVE]: return _feedback({"success": false, "reason": "Select ICE or its sphere"})
	if Game.ice_controller != null:
		for ice: IceInstance in Game.ice_controller.instances.values():
			if ice.definition.is_host_bound(): continue
			if (selection.kind == NetworkSelectionState.Kind.SPHERE and ice.sphere_id == selection.object_id) or (selection.kind == NetworkSelectionState.Kind.SECURITY_SLEEVE and ice.security_sleeve_id == selection.object_id):
				var result := _execute_command(RemoveIceCommand.new(_command_context(), ice.instance_id)); _refresh_hud(); return _feedback(result)
	return _feedback({"success": false, "reason": "No mobile ICE assigned to this boundary"})

func configure_selected_ice(values: Dictionary) -> Dictionary:
	var ice := Game.ice_controller.get_ice(selection.object_id) if Game.ice_controller != null and selection.kind == NetworkSelectionState.Kind.ICE else null
	if not is_god_mode() or ice == null: return _feedback({"success": false, "reason": "Select ICE in AUTHOR_GOD mode"})
	var allowed_nodes := _ice_boundary_members(ice)
	if graph.get_node(StringName(values.get("current_node_id", &""))) == null or (not allowed_nodes.is_empty() and not allowed_nodes.has(StringName(values.current_node_id))): values.erase("current_node_id")
	if not allowed_nodes.is_empty():
		var route: Array = values.get("patrol_route", [])
		if route.any(func(node_id): return not allowed_nodes.has(StringName(node_id))): return _feedback({"success": false, "reason": "Patrol route must remain inside the ICE boundary"})
	var result := _execute_command(ConfigureIceCommand.new(_command_context(), ice, values)); _refresh_hud(); return _feedback(result)

func _add_ice(definition_id: StringName, node_id: StringName, stationary: bool, boundary_kind := NetworkSelectionState.Kind.NONE, boundary_id: StringName = &"") -> Dictionary:
	var definition := _ice_definitions().get(definition_id) as IceDefinition
	if definition == null or definition.is_host_bound() != stationary: return _feedback({"success": false, "reason": "Choose a compatible registered ICE type"})
	var id := _unique_content_id(&"AUTHOR_ICE", false)
	var ice := IceInstance.new(id, definition, node_id, IceState.Value.DORMANT)
	if not stationary:
		if boundary_kind == NetworkSelectionState.Kind.SPHERE: ice.sphere_id = boundary_id
		elif boundary_kind == NetworkSelectionState.Kind.SECURITY_SLEEVE: ice.security_sleeve_id = boundary_id
	var result := _execute_command(AddIceCommand.new(_command_context(), ice))
	if bool(result.get("success", false)): call_deferred("select_object", NetworkSelectionState.Kind.ICE, id)
	return _feedback(result)

func _selected_service() -> NodeServiceDefinition:
	if selection.kind != NetworkSelectionState.Kind.SERVICE: return null
	var owner := _service_owner(selection.object_id)
	if owner != null:
		for service: NodeServiceDefinition in owner.service_definitions:
			if service.id == selection.object_id: return service
	return null

func _service_owner(service_id: StringName) -> NetworkNodeDefinition:
	if graph == null: return null
	for node: NetworkNodeDefinition in graph.nodes.values():
		for service: NodeServiceDefinition in node.service_definitions:
			if service.id == service_id: return node
	return null

func _ice_definitions() -> Dictionary:
	var definitions := {}
	if Game.ice_controller != null:
		for ice: IceInstance in Game.ice_controller.instances.values(): definitions[ice.definition.id] = ice.definition
	if Game.active_content_document != null:
		for data: Dictionary in Game.active_content_document.ice_definitions:
			var id := StringName(data.get("id", &""))
			if id == &"" or definitions.has(id): continue
			var definition := AuthoredIceFactory.create_definition(data)
			var binding := StringName(String(data.get("binding_mode", &"ROAMING")).to_upper())
			if definition != null and binding == &"HOST_BOUND": definition.binding_mode = IceDefinition.BindingMode.HOST_BOUND
			if definition != null: definitions[id] = definition
	return definitions

func _ice_definition_options(mobile: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition: IceDefinition in _ice_definitions().values():
		if definition.is_host_bound() == mobile: continue
		result.append({"id": definition.id, "label": "%s // %s" % [definition.display_name, "MOBILE" if mobile else "STATIONARY"]})
	return result

func _selected_members() -> Array[StringName]:
	if graph == null: return []
	if selection.kind == NetworkSelectionState.Kind.SPHERE:
		var sphere := graph.get_sphere(selection.object_id); return sphere.node_ids.duplicate() if sphere != null else []
	if selection.kind == NetworkSelectionState.Kind.SECURITY_SLEEVE:
		var sleeve := graph.get_security_sleeve(selection.object_id); return sleeve.current_members.duplicate() if sleeve != null else []
	return []

func _eligible_start_nodes() -> Array[Dictionary]:
	var ids: Array[StringName] = []
	ids.assign(_selected_members())
	if selection.kind == NetworkSelectionState.Kind.ICE and Game.ice_controller != null:
		ids.assign(_ice_boundary_members(Game.ice_controller.get_ice(selection.object_id)))
	if ids.is_empty() and graph != null: ids.assign(graph.nodes.keys())
	var result: Array[Dictionary] = []
	for id: StringName in ids:
		var node := graph.get_node(id)
		if node != null: result.append({"id": id, "label": node.display_name})
	return result

func _ice_boundary_members(ice: IceInstance) -> Array[StringName]:
	if ice == null or graph == null: return []
	if ice.security_sleeve_id != &"":
		var sleeve := graph.get_security_sleeve(ice.security_sleeve_id); return sleeve.current_members.duplicate() if sleeve != null else []
	if ice.sphere_id != &"":
		var sphere := graph.get_sphere(ice.sphere_id); return sphere.node_ids.duplicate() if sphere != null else []
	return []

func _unique_content_id(prefix: StringName, service: bool) -> StringName:
	while true:
		var serial := _next_service_serial if service else _next_ice_serial
		if service: _next_service_serial += 1
		else: _next_ice_serial += 1
		var candidate := StringName("%s_%03d" % [prefix, serial])
		if (_service_owner(candidate) == null if service else Game.ice_controller == null or Game.ice_controller.get_ice(candidate) == null): return candidate
	return &""

func add_connected_node() -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.NODE: return _feedback({"success": false, "reason": "Select a node in AUTHOR_GOD mode"})
	var source := graph.get_node(selection.object_id)
	if source == null: return _feedback({"success": false, "reason": "Selected node no longer exists"})
	var node_id := _unique_id(&"AUTHOR_NODE", true)
	var path_id := _unique_id(&"AUTHOR_PATH", false)
	var node := NetworkNodeDefinition.new(node_id, "Authored Node %d" % (_next_node_serial - 1), NetworkNodeDefinition.NodeType.ROUTER, 0, true, source.owner_faction, source.sphere_id)
	var link := NetworkLinkDefinition.new(path_id, source.id, node.id)
	var command := AddNodeCommand.new(_command_context(), source.id, node, link)
	var result := _execute_command(command)
	if bool(result.get("success", false)):
		selection.select(NetworkSelectionState.Kind.NODE, node.id)
		EventBus.network_display_update_requested.emit()
		call_deferred("select_object", NetworkSelectionState.Kind.NODE, node.id)
	return _feedback(result)

func duplicate_selected_node() -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.NODE: return _feedback({"success": false, "reason": "Select a node in AUTHOR_GOD mode"})
	var source := graph.get_node(selection.object_id)
	if source == null: return _feedback({"success": false, "reason": "Node not found"})
	var node_id := _unique_id(&"AUTHOR_NODE", true)
	var clone := NetworkNodeDefinition.new(node_id, "%s Copy" % source.display_name, source.node_type, source.security_level, true, source.owner_faction, source.sphere_id)
	clone.network_type = source.network_type; clone.security_family = source.security_family; clone.difficulty_rating = source.difficulty_rating
	clone.authored_position = source.authored_position + Vector3(2.0, 0.0, 1.0); clone.has_authored_position = true
	for service: NodeServiceDefinition in source.service_definitions:
		var record := service.to_record(); record["id"] = _unique_content_id(&"AUTHOR_SERVICE", true); clone.add_service_record(record)
	var path_id := _unique_id(&"AUTHOR_PATH", false)
	var link := NetworkLinkDefinition.new(path_id, source.id, node_id, false, false, false, false, true, 1)
	var result := _execute_command(AddNodeCommand.new(_command_context(), source.id, clone, link))
	if bool(result.get("success", false)): select_object(NetworkSelectionState.Kind.NODE, node_id)
	return _feedback(result)

func delete_selection() -> Dictionary:
	if not is_god_mode(): return _feedback({"success": false, "reason": "Delete requires AUTHOR_GOD"})
	if selection.kind == NetworkSelectionState.Kind.PATH: return delete_selected_path()
	if selection.kind == NetworkSelectionState.Kind.SPHERE: return delete_selected_sphere()
	if selection.kind != NetworkSelectionState.Kind.NODE: return _feedback({"success": false, "reason": "Select nodes, a path, or a sphere"})
	var commands: Array[NetworkAuthorCommand] = []
	for node_id: StringName in selection.node_ids: commands.append(DeleteNodeCommand.new(_command_context(), node_id))
	if commands.is_empty(): return _feedback({"success": false, "reason": "No nodes selected"})
	var result := _execute_command(CompositeAuthorCommand.new(_command_context(), commands, "Deleted %d selected node(s)" % commands.size()))
	if bool(result.get("success", false)): selection.clear()
	_refresh_hud(); return _feedback(result)

func delete_selected_node() -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.NODE: return _feedback({"success": false, "reason": "Select a node in AUTHOR_GOD mode"})
	var result := _execute_command(DeleteNodeCommand.new(_command_context(), selection.object_id))
	if bool(result.get("success", false)): selection.clear(); EventBus.network_display_update_requested.emit()
	_refresh_hud()
	return _feedback(result)

func delete_selected_path() -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.PATH: return _feedback({"success": false, "reason": "Select a path in AUTHOR_GOD mode"})
	var result := _execute_command(DeletePathCommand.new(_command_context(), selection.object_id))
	if bool(result.get("success", false)): selection.clear(); EventBus.network_display_update_requested.emit()
	_refresh_hud()
	return _feedback(result)

func set_selected_node_type(node_type: int) -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.NODE or node_type < 0 or node_type >= NetworkNodeDefinition.NodeType.size(): return _feedback({"success": false, "reason": "Invalid node type operation"})
	var result := _execute_command(SetNodeTypeCommand.new(_command_context(), selection.object_id, node_type as NetworkNodeDefinition.NodeType))
	_refresh_hud()
	return _feedback(result)

func set_selected_path_locked(locked: bool) -> Dictionary:
	if not is_god_mode() or selection.kind != NetworkSelectionState.Kind.PATH: return _feedback({"success": false, "reason": "Select a path in AUTHOR_GOD mode"})
	var result := _execute_command(SetPathLockedCommand.new(_command_context(), selection.object_id, locked))
	_refresh_hud()
	return _feedback(result)

func _execute_command(command: NetworkAuthorCommand) -> Dictionary:
	var command_result := command.execute()
	if bool(command_result.get("success", false)):
		command_history.append(command)
		redo_history.clear()
		EventBus.network_display_update_requested.emit()
		_refresh_hud()
	return command_result

func undo() -> Dictionary:
	if not is_god_mode() or command_history.is_empty(): return _feedback({"success": false, "reason": "Nothing to undo"})
	var command: NetworkAuthorCommand = command_history.pop_back()
	var undo_result: Dictionary = command.undo()
	if bool(undo_result.get("success", false)): redo_history.append(command)
	else: command_history.append(command)
	EventBus.network_display_update_requested.emit(); _refresh_hud()
	return _feedback(undo_result)

func redo() -> Dictionary:
	if not is_god_mode() or redo_history.is_empty(): return _feedback({"success": false, "reason": "Nothing to redo"})
	var command: NetworkAuthorCommand = redo_history.pop_back()
	var redo_result: Dictionary = command.execute()
	if bool(redo_result.get("success", false)): command_history.append(command)
	else: redo_history.append(command)
	EventBus.network_display_update_requested.emit(); _refresh_hud()
	return _feedback(redo_result)

func is_dirty() -> bool:
	if command_history.size() != saved_history.size(): return true
	for index in command_history.size():
		if command_history[index] != saved_history[index]: return true
	return false

func _command_context() -> Dictionary:
	return {"graph": graph, "position": position, "ice_controller": Game.ice_controller, "anchor_controller": Game.anchor_controller, "san_controller": Game.san_controller, "boss_encounter": Game.active_boss_encounter}

func _node_choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if graph != null:
		for node: NetworkNodeDefinition in graph.nodes.values(): result.append({"id": node.id, "label": "%s // %s" % [node.id, node.display_name]})
	return result

func _selection_breadcrumbs() -> String:
	if graph == null or selection.object_id == &"": return "Nothing selected"
	var node: NetworkNodeDefinition
	var leaf := ""
	match selection.kind:
		NetworkSelectionState.Kind.NODE: node = graph.get_node(selection.object_id)
		NetworkSelectionState.Kind.SERVICE: node = _service_owner(selection.object_id); leaf = "Service %s" % selection.object_id
		NetworkSelectionState.Kind.ICE:
			var ice := Game.ice_controller.get_ice(selection.object_id) if Game.ice_controller != null else null
			if ice != null: node = graph.get_node(ice.current_node_id); leaf = "ICE %s" % selection.object_id
		NetworkSelectionState.Kind.SPHERE: return "Sphere %s" % selection.object_id
		NetworkSelectionState.Kind.SECURITY_SLEEVE: return "Security Sleeve %s" % selection.object_id
		NetworkSelectionState.Kind.PATH: return "Path %s" % selection.object_id
	if node == null: return selection.kind_label()
	var parts: PackedStringArray = []
	if node.sphere_id != &"": parts.append("Sphere %s" % node.sphere_id)
	parts.append("Node %s" % node.id)
	if not leaf.is_empty(): parts.append(leaf)
	if selection.node_ids.size() > 1: parts.append("%d nodes selected" % selection.node_ids.size())
	return " > ".join(parts)

func _set_overlay(name: StringName, enabled: bool) -> void:
	if display != null: display.set_debug_authoring_overlay(name, enabled)

func _begin_test_as_player() -> void:
	if not _test_snapshot.is_empty(): return
	var authored := capture_document()
	_test_snapshot = {"document": authored, "author_node": position.current_node_id if position != null else &"", "persistent": Game.persistent_game_state.to_save_data(), "trace": Game.trace_level}
	if Game.program_inventory != null: _test_snapshot["inventory_instances"] = Game.program_inventory._instances.duplicate()
	if Game.program_loadout != null:
		_test_snapshot["installed_utilities"] = Game.program_loadout.installed_utility_ids.duplicate()
		_test_snapshot["active_slots"] = Game.program_loadout.active_slots.duplicate()
	if Game.meatspace_management != null and Game.meatspace_management.deck_reconfiguration != null: _test_snapshot["deck_operation"] = Game.meatspace_management.deck_reconfiguration.active_operation.duplicate(true)
	Game.debug_install_network_document(authored)
	Game.trace_level = 0
	refresh_runtime_references()

func _end_test_as_player() -> void:
	if _test_snapshot.is_empty(): return
	Game.debug_install_network_document(_test_snapshot.document)
	var restored := PersistentGameState.from_save_data(_test_snapshot.persistent)
	Game.persistent_game_state.campaign_state = restored.campaign_state
	Game.persistent_game_state.player_state = restored.player_state
	Game.persistent_game_state.world_state = restored.world_state
	Game.persistent_game_state.save_metadata = restored.save_metadata
	Game.trace_level = int(_test_snapshot.trace)
	if Game.program_inventory != null and _test_snapshot.has("inventory_instances"): Game.program_inventory._instances = _test_snapshot.inventory_instances.duplicate()
	if Game.program_loadout != null:
		Game.program_loadout.installed_utility_ids.assign(_test_snapshot.get("installed_utilities", []))
		Game.program_loadout.active_slots.assign(_test_snapshot.get("active_slots", []))
		Game.program_loadout._rebuild_installed_ids()
	if Game.meatspace_management != null and Game.meatspace_management.deck_reconfiguration != null: Game.meatspace_management.deck_reconfiguration.active_operation = (_test_snapshot.get("deck_operation", {}) as Dictionary).duplicate(true)
	refresh_runtime_references()
	if position != null and graph.get_node(StringName(_test_snapshot.author_node)) != null: position.relocate(StringName(_test_snapshot.author_node))
	_test_snapshot.clear()
	EventBus.network_display_update_requested.emit()

func _unique_id(prefix: StringName, node_id: bool) -> StringName:
	while true:
		var serial := _next_node_serial if node_id else _next_path_serial
		if node_id: _next_node_serial += 1
		else: _next_path_serial += 1
		var candidate := StringName("%s_%03d" % [prefix, serial])
		if (graph.get_node(candidate) == null if node_id else graph.get_link(candidate) == null): return candidate
	return &""

func _feedback(command_result: Dictionary) -> Dictionary:
	if hud != null: hud.show_feedback(String(command_result.get("reason", "")), bool(command_result.get("success", false)))
	return command_result

func capture_document() -> NetworkDocument:
	refresh_runtime_references()
	var resolver := Callable()
	if display != null: resolver = Callable(display, "debug_authored_world_position")
	var document := NetworkDocument.capture_runtime(graph, Game.ice_controller, position.current_node_id if position != null else &"", resolver)
	# Temporary authoring UI state never enters the document, while authored
	# mission/story metadata survives topology edits and save/reload cycles.
	if loaded_document_template != null:
		document.network_id = loaded_document_template.network_id
		document.display_name = loaded_document_template.display_name
		document.metadata.merge(loaded_document_template.metadata.duplicate(true), true)
		document.story_metadata = loaded_document_template.story_metadata.duplicate(true)
	elif not current_document_path.is_empty(): document.network_id = StringName(current_document_path.get_file().get_basename().to_snake_case().to_upper())
	return document

func save_current_network(path: String) -> Dictionary:
	if not is_god_mode(): return _feedback({"success": false, "reason": "Saving requires AUTHOR_GOD"})
	if path.is_empty(): return _feedback({"success": false, "reason": "Choose a .netspace path"})
	var save_result := NetworkDocumentSerializer.save_file(capture_document(), path)
	if bool(save_result.get("success", false)):
		current_document_path = String(save_result.path)
		loaded_document_template = capture_document()
		saved_history = command_history.duplicate()
		_refresh_hud()
	return _feedback({"success": save_result.get("success", false), "reason": "Saved %s" % save_result.get("path", path) if save_result.get("success", false) else _validation_message(save_result.get("issues", [])), "issues": save_result.get("issues", [])})

func load_network(path: String) -> Dictionary:
	if not is_god_mode(): return _feedback({"success": false, "reason": "Loading requires AUTHOR_GOD"})
	var load_result := NetworkDocumentSerializer.load_file(path)
	if not bool(load_result.get("success", false)): return _feedback({"success": false, "reason": _validation_message(load_result.get("issues", [])), "issues": load_result.get("issues", [])})
	var install_result := Game.debug_install_network_document(load_result.document)
	if not bool(install_result.get("success", false)): return _feedback({"success": false, "reason": _validation_message(install_result.get("issues", [])), "issues": install_result.get("issues", [])})
	current_document_path = path; loaded_document_template = load_result.document; refresh_runtime_references(); selection.clear(); command_history.clear(); redo_history.clear(); saved_history.clear()
	if display != null: display.reset_debug_authoring_runtime(); display.set_debug_authoring_reveal_all(true)
	_refresh_hud(); return _feedback({"success": true, "reason": "Loaded %s" % path})

func _show_save_as() -> void:
	if not is_god_mode(): return
	if _save_dialog == null:
		_save_dialog = FileDialog.new(); _save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE; _save_dialog.access = FileDialog.ACCESS_FILESYSTEM; _save_dialog.add_filter("*.netspace", "Netspace Network"); _save_dialog.file_selected.connect(save_current_network); add_child(_save_dialog)
	_save_dialog.popup_centered_ratio(0.7)

func _show_load() -> void:
	if not is_god_mode(): return
	if _load_dialog == null:
		_load_dialog = FileDialog.new(); _load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; _load_dialog.access = FileDialog.ACCESS_FILESYSTEM; _load_dialog.add_filter("*.netspace", "Netspace Network"); _load_dialog.file_selected.connect(load_network); add_child(_load_dialog)
	_load_dialog.popup_centered_ratio(0.7)

func _validation_message(issues: Array) -> String:
	if issues.is_empty(): return "Network document operation failed"
	var lines: PackedStringArray = []
	for issue in issues: lines.append("%s: %s" % [issue.get("path", "document"), issue.get("message", "Invalid data")])
	return "\n".join(lines)

func _inspection_text() -> String:
	if graph == null or selection.object_id == &"": return "Select a runtime object to inspect."
	match selection.kind:
		NetworkSelectionState.Kind.NODE:
			var node := graph.get_node(selection.object_id)
			if node != null: return "[b]NODE[/b]\nID: %s\nType: %s\nNetwork: %s\nSecurity: %s\nDifficulty: %d\nSphere: %s\nServices: %s" % [node.id, NetworkNodeDefinition.NodeType.keys()[node.node_type], node.network_type, node.security_family_name(), node.difficulty_rating, node.sphere_id, _service_names(node)]
		NetworkSelectionState.Kind.PATH:
			var link := graph.get_link(selection.object_id)
			if link != null: return "[b]PATH[/b]\nID: %s\nEndpoints: %s <-> %s\nLocked: %s\nHidden: %s\nDisabled: %s" % [link.id, link.source, link.destination, link.locked, link.hidden, link.disabled]
		NetworkSelectionState.Kind.SPHERE:
			var sphere := graph.get_sphere(selection.object_id)
			if sphere != null: return "[b]SPHERE[/b]\nID: %s\nName: %s\nMembers: %s\nOriginal sleeve: %s\n%s\nMobile ICE: %s\nMetadata: %s" % [sphere.id, sphere.display_name, ", ".join(sphere.node_ids), sphere.original_security_sleeve_id, _sleeve_summary(sphere.original_security_sleeve_id), _mobile_ice_names(sphere.id, sphere.original_security_sleeve_id), JSON.stringify(sphere.metadata)]
		NetworkSelectionState.Kind.SECURITY_SLEEVE:
			var sleeve := graph.get_security_sleeve(selection.object_id)
			if sleeve != null: return "[b]SECURITY SLEEVE[/b]\nID: %s\nName: %s\nMembers: %s\nState: %s\nMetadata: %s" % [sleeve.id, sleeve.display_name, ", ".join(sleeve.current_members), SecuritySleeve.State.keys()[sleeve.state], JSON.stringify(sleeve.metadata)]
		NetworkSelectionState.Kind.SERVICE:
			for node: NetworkNodeDefinition in graph.nodes.values():
				for service: NodeServiceDefinition in node.service_definitions:
					if service.id == selection.object_id: return "[b]SERVICE[/b]\nID: %s\nName: %s\nNode: %s\nType: %s\nSecurity: %d\nOperations: %s" % [service.id, service.display_name, node.id, service.service_type, service.security_level, ", ".join(service.supported_operations)]
		NetworkSelectionState.Kind.ICE:
			var ice := Game.ice_controller.get_ice(selection.object_id) if Game.ice_controller != null else null
			if ice != null: return "[b]ICE[/b]\nID: %s\nName: %s\nNode: %s\nRating: %d\nState: %s\nSphere: %s\nSleeve: %s" % [ice.instance_id, ice.definition.display_name, ice.current_node_id, ice.definition.defense, IceState.label(ice.state), ice.sphere_id, ice.security_sleeve_id]
	return "Object no longer exists."

func _service_names(node: NetworkNodeDefinition) -> String:
	var names: PackedStringArray = []
	for service: NodeServiceDefinition in node.service_definitions: names.append(service.display_name)
	return ", ".join(names) if not names.is_empty() else "None"

func _mobile_ice_names(sphere_id: StringName, sleeve_id: StringName) -> String:
	var names: PackedStringArray = []
	if Game.ice_controller != null:
		for ice: IceInstance in Game.ice_controller.instances.values():
			if ice.sphere_id == sphere_id or ice.security_sleeve_id == sleeve_id: names.append(ice.definition.display_name)
	return ", ".join(names) if not names.is_empty() else "None"

func _sleeve_summary(sleeve_id: StringName) -> String:
	var sleeve := graph.get_security_sleeve(sleeve_id) if graph != null else null
	if sleeve == null: return "Security: No sleeve"
	return "Security: %s // Escalation: %s // Count: %d" % [SecuritySleeve.State.keys()[sleeve.state], SecuritySleeve.EscalationLevel.keys()[sleeve.escalation_level], sleeve.security_count]
