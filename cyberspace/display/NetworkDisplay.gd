class_name NetworkDisplay
extends Control

const NODE_SCENE := preload("res://cyberspace/display/NodeVisual.tscn")
const SAN_SCENE := preload("res://cyberspace/display/SANVisual.tscn")
const LinkVisualScript := preload("res://cyberspace/display/LinkVisual.gd")
const CYAN := Color("48e8ff")
const AMBER := Color("ffc857")

@onready var link_layer: Node2D = %LinkLayer
@onready var node_layer: Control = %NodeLayer
@onready var location_label: Label = %LocationLabel
@onready var resource_label: Label = %ResourceLabel
@onready var status_label: Label = %StatusLabel
@onready var scan_button: Button = %ScanButton
@onready var service_list: VBoxContainer = %ServiceButtons
@onready var trace_label: Label = %TraceLabel
@onready var tick_label: Label = %TickLabel
@onready var risk_label: Label = %RiskLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var current_name: Label = %CurrentName
@onready var current_type: Label = %CurrentType
@onready var current_security: Label = %CurrentSecurity
@onready var current_authority: Label = %CurrentAuthority
@onready var services_label: Label = %ServicesLabel
@onready var local_scan_button: Button = %LocalScanButton
@onready var target_title: Label = %TargetTitle
@onready var target_details: Label = %TargetDetails
@onready var target_cost: Label = %TargetCost
@onready var confirm_button: Button = %ConfirmButton
@onready var target_scan_button: Button = %TargetScanButton
@onready var event_feed: Label = %EventFeed
@onready var program_cost_label: Label = %ProgramCostLabel
@onready var known_entities: VBoxContainer = %KnownEntities
@onready var attack_button: Button = %AttackButton
@onready var disrupt_button: Button = %DisruptButton
@onready var spoof_button: Button = %SpoofButton
@onready var hide_button: Button = %HideButton
@onready var scramble_button: Button = %ScrambleButton
@onready var retreat_button: Button = %RetreatButton
@onready var break_lock_button: Button = %BreakLockButton
@onready var redirect_button: Button = %RedirectButton
@onready var exploit_button: Button = %ExploitButton
@onready var extract_button: Button = %ExtractButton
@onready var wait_button: Button = %WaitButton
@onready var doorstop_button: Button = %DoorstopButton
@onready var doorstop_confirmation: ConfirmationDialog = %DoorstopConfirmation
@onready var jack_out_button: Button = %JackOutButton
@onready var doorstop_state_label: Label = %DoorstopStateLabel

var graph: NetworkGraph
var position_model: PlayerNetworkPosition
var knowledge: PlayerKnowledge
var node_visuals: Dictionary = {}
var link_visuals: Dictionary = {}
var san_visuals: Dictionary = {}
var scan_targets: Dictionary = {}
var target_views: Dictionary = {}
var target_order: Array[StringName] = []
var selected_target_id: StringName = &""
var event_lines: PackedStringArray = ["> SESSION READY"]
var _transition_active := false
var _pending_doorstop_instance_id: StringName = &""

func _ready() -> void:
	resized.connect(_on_resized)
	EventBus.session_started.connect(_on_session_started)
	EventBus.network_traversal_started.connect(_on_traversal_started)
	EventBus.network_position_changed.connect(_on_position_changed)
	EventBus.network_display_update_requested.connect(_on_display_update_requested)
	EventBus.action_resolved.connect(_on_action_resolved)
	EventBus.game_domain_changed.connect(_on_game_domain_changed)
	EventBus.san_defense_alert.connect(_on_san_defense_alert)
	scan_button.pressed.connect(_on_scan_pressed)
	local_scan_button.pressed.connect(_on_scan_pressed)
	confirm_button.pressed.connect(_confirm_selected_target)
	target_scan_button.pressed.connect(_scan_selected_target)
	var program_buttons := $BottomBar/Margin/Rows/Programs.get_children()
	for index in program_buttons.size():
		(program_buttons[index] as Button).pressed.connect(_on_program_selected.bind(index + 1))
	attack_button.pressed.connect(_submit_selected_confrontation.bind(ActionRequest.ActionType.ATTACK_PROCESS))
	disrupt_button.pressed.connect(_submit_selected_confrontation.bind(ActionRequest.ActionType.DISRUPT))
	spoof_button.pressed.connect(_submit_selected_confrontation.bind(ActionRequest.ActionType.SPOOF))
	hide_button.pressed.connect(_submit_self_confrontation.bind(ActionRequest.ActionType.HIDE))
	scramble_button.pressed.connect(_submit_self_confrontation.bind(ActionRequest.ActionType.TRACE_SCRAMBLE))
	retreat_button.pressed.connect(_submit_selected_confrontation.bind(ActionRequest.ActionType.RETREAT))
	break_lock_button.pressed.connect(_submit_selected_confrontation.bind(ActionRequest.ActionType.BREAK_LOCK))
	redirect_button.pressed.connect(_submit_selected_confrontation.bind(ActionRequest.ActionType.REDIRECT))
	exploit_button.pressed.connect(_submit_mission_action.bind(ActionRequest.ActionType.EXPLOIT))
	extract_button.pressed.connect(_submit_mission_action.bind(ActionRequest.ActionType.TRANSFER))
	wait_button.pressed.connect(_submit_wait)
	doorstop_confirmation.confirmed.connect(_confirm_doorstop_deployment)
	doorstop_confirmation.canceled.connect(_cancel_doorstop_deployment)
	jack_out_button.pressed.connect(_jack_out_through_doorstop)
	if Game.session_active:
		_on_session_started()
	queue_redraw()

func set_models(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge) -> void:
	graph = p_graph
	position_model = p_position
	knowledge = p_knowledge
	_rebuild_neighborhood()

func _on_session_started() -> void:
	set_models(Game.network_graph, Game.player_network_position, Game.player_knowledge)

func _rebuild_neighborhood() -> void:
	if graph == null or position_model == null or knowledge == null or size.x <= 1.0:
		return
	for child in link_layer.get_children():
		child.queue_free()
	for child in node_layer.get_children():
		child.queue_free()
	node_visuals.clear()
	link_visuals.clear()
	san_visuals.clear()
	scan_targets.clear()
	target_views.clear()
	target_order.clear()
	selected_target_id = &""

	var current_id := position_model.current_node_id
	var current_view := knowledge.get_node_view(current_id)
	if current_view.is_empty():
		status_label.text = "NO VALID NETWORK POSITION"
		return
	var map_left := 276.0
	var map_right := size.x - 316.0
	var map_top := 96.0
	var map_bottom := size.y - 154.0
	var center := Vector2((map_left + map_right) * 0.5, (map_top + map_bottom) * 0.5)
	_add_node_visual(current_view, center, true, false)

	var contacts := knowledge.get_local_contacts(current_id)
	var total_slots := contacts.size()
	var slot := 0
	for contact in contacts:
		var angle := _slot_angle(slot, maxi(total_slots, 1))
		var visual_position := center + Vector2(cos(angle) * minf((map_right - map_left) * 0.31, 245.0), sin(angle) * minf((map_bottom - map_top) * 0.31, 155.0))
		if contact.kind == &"NODE":
			_add_link_visual(contact.contact_id, center, visual_position, false)
			_add_node_visual(contact.node, visual_position, false, true)
			scan_targets[contact.node.id] = {"kind": ScanSystem.NODE, "node_id": contact.node.id}
			scan_targets[contact.contact_id] = {"kind": ScanSystem.LINK, "contact_id": contact.contact_id}
			target_views[contact.node.id] = {"kind": &"NODE", "title": contact.node.get("display_name", "UNKNOWN NODE"), "node": contact.node, "link": contact.link, "scan_target": scan_targets[contact.node.id]}
			target_views[contact.contact_id] = {"kind": &"LINK", "title": "NETWORK LINK", "link": contact.link, "scan_target": scan_targets[contact.contact_id], "confrontation_target": {"kind": &"LINK", "contact_id": contact.contact_id}}
			target_order.append(contact.node.id)
		else:
			var fragment_position := center.lerp(visual_position, 0.72)
			_add_link_visual(contact.contact_id, center, fragment_position, true)
			_add_unknown_visual(fragment_position, "UNKNOWN NODE" if contact.kind == &"UNKNOWN_NODE" else "UNKNOWN SIGNAL", contact.contact_id)
			scan_targets[contact.contact_id] = {"kind": ScanSystem.LINK, "contact_id": contact.contact_id}
			target_views[contact.contact_id] = {"kind": contact.kind, "title": "UNKNOWN NODE" if contact.kind == &"UNKNOWN_NODE" else "UNKNOWN SIGNAL", "scan_target": scan_targets[contact.contact_id]}
			target_order.append(contact.contact_id)
		slot += 1

	location_label.text = "CURRENT HOST  //  %s" % String(current_view.get("display_name", "UNKNOWN")).to_upper()
	resource_label.text = "TRAVERSAL UNITS  %02d    |    KNOWN CONTACTS  %02d" % [position_model.traversal_points, contacts.size()]
	status_label.text = "SELECT A CONNECTED HOST"
	_rebuild_services(current_id)
	_rebuild_known_entities(current_id, contacts)
	_update_current_panel(current_view)
	_update_top_bar()
	_update_program_bar()
	_clear_target_panel()

func _add_node_visual(node_view: Dictionary, center: Vector2, current: bool, selectable: bool) -> void:
	var visual := NODE_SCENE.instantiate() as NodeVisual
	node_layer.add_child(visual)
	visual.position = center - visual.size * 0.5
	var node_id: StringName = node_view.get("id", &"")
	visual.configure_view(node_view, current, selectable, _security_visible_at(node_id))
	visual.selected.connect(_on_node_selected)
	visual.scan_requested.connect(_on_scan_target_requested)
	node_visuals[node_id] = visual

func _add_unknown_visual(center: Vector2, unknown_title: String, contact_id: StringName) -> void:
	var visual := NODE_SCENE.instantiate() as NodeVisual
	node_layer.add_child(visual)
	visual.position = center - visual.size * 0.5
	visual.configure_unknown(contact_id)
	visual.title = unknown_title
	visual.scan_requested.connect(_on_scan_target_requested)

func _add_link_visual(link_id: StringName, start: Vector2, finish: Vector2, unknown: bool) -> void:
	var visual := LinkVisualScript.new() as LinkVisual
	link_layer.add_child(visual)
	visual.configure(link_id, start, finish, unknown)
	visual.scan_requested.connect(_on_scan_target_requested)
	visual.selected.connect(_select_target)
	link_visuals[link_id] = visual

func _rebuild_services(current_node_id: StringName) -> void:
	for child in service_list.get_children():
		child.queue_free()
	for service in knowledge.get_services_at(current_node_id):
		var button := Button.new()
		button.text = "SERVICE // %s" % String(service.get("display_name", "UNKNOWN SERVICE")).to_upper()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var target := {"kind": ScanSystem.SERVICE, "contact_id": service.contact_id}
		var contact_id: StringName = service.contact_id
		target_views[contact_id] = {"kind": &"SERVICE", "title": service.get("display_name", "UNKNOWN SERVICE"), "service": service, "scan_target": target, "mission_target": {"kind": &"SERVICE", "contact_id": contact_id}}
		target_order.append(contact_id)
		button.pressed.connect(func() -> void: _select_target(contact_id))
		service_list.add_child(button)

func _rebuild_known_entities(current_node_id: StringName, contacts: Array[Dictionary]) -> void:
	for child in known_entities.get_children():
		child.queue_free()
	var locally_known_nodes: Array[StringName] = [current_node_id]
	for contact in contacts:
		if contact.get("kind") == &"NODE":
			locally_known_nodes.append(contact.node.id)
	for ice_id in knowledge.ice_records:
		var record := knowledge.ice_records[ice_id] as Dictionary
		if int(record.get("level", 0)) < KnowledgeLevel.Value.IDENTIFIED or not locally_known_nodes.has(record.get("node_id", &"")):
			continue
		var contact_id: StringName = record.contact_id
		var button := Button.new()
		button.text = "ICE // %s [%s]" % [String(record.get("display_name", ice_id)), IceState.label(int(record.get("state", IceState.Value.DORMANT)))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: _select_target(contact_id))
		known_entities.add_child(button)
		var ice_target := {"kind": &"ICE", "contact_id": contact_id}
		target_views[contact_id] = {"kind": &"ICE", "title": record.get("display_name", "SECURITY PROCESS"), "ice": record, "confrontation_target": ice_target, "scan_target": {"kind": ScanSystem.ICE_SIGNAL, "contact_id": contact_id}}
		target_order.append(contact_id)
	for hacker: Dictionary in knowledge.get_visible_hackers_at(locally_known_nodes):
		var contact_id: StringName = hacker.contact_id
		var button := Button.new()
		button.text = "HACKER // %s [%s]" % [String(hacker.get("callsign", hacker.get("display_name", "REMOTE"))), "LOCAL" if hacker.get("node_id", &"") == current_node_id else "ADJACENT"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: _select_target(contact_id))
		known_entities.add_child(button)
		target_views[contact_id] = {"kind": &"HACKER", "title": hacker.get("callsign", "REMOTE HACKER"), "hacker": hacker}
		target_order.append(contact_id)
	for san_view: Dictionary in Game.get_visible_san_inspections():
		if not locally_known_nodes.has(san_view.get("host_node_id", &"")): continue
		var san_id: StringName = san_view.id
		var button := Button.new()
		button.text = "SAN // %s [%s]" % [String(san_view.get("owner_label", "UNKNOWN")), String(san_view.get("visual_state", "UNKNOWN"))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: _select_target(san_id))
		known_entities.add_child(button)
		target_views[san_id] = {"kind": &"SAN", "title": "SYSTEM ACCESS NODE", "san": san_view}
		target_order.append(san_id)
		_add_san_visual(san_view)

func _add_san_visual(san_view: Dictionary) -> void:
	var host := node_visuals.get(san_view.get("host_node_id", &"")) as NodeVisual
	if host == null: return
	var visual: Control = SAN_SCENE.instantiate() as Control
	host.add_child(visual)
	visual.position = Vector2(host.size.x - visual.size.x - 5.0, 2.0)
	visual.configure(san_view)
	visual.selected.connect(_select_target)
	san_visuals[san_view.id] = visual

func _on_node_selected(node_id: StringName) -> void:
	if _transition_active:
		return
	_select_target(node_id)

func _on_scan_pressed() -> void:
	if _transition_active or position_model == null:
		return
	var target := {"kind": ScanSystem.CURRENT_NODE, "node_id": position_model.current_node_id}
	_submit_scan(target)

func _on_scan_target_requested(contact_id: StringName) -> void:
	if _transition_active or not scan_targets.has(contact_id):
		return
	_submit_scan(scan_targets[contact_id])

func _submit_scan(target: Dictionary) -> void:
	var result := Game.request_scan(target)
	status_label.text = "SCAN COMPLETE" if result.success else "SCAN DENIED  //  %s" % result.reason.to_upper()

func _on_action_resolved(request: ActionRequest, result: ActionResult) -> void:
	_update_top_bar()
	_append_action_events(request, result)
	if not _transition_active:
		_rebuild_neighborhood()

func _on_traversal_started(_from_id: StringName, to_id: StringName, link_id: StringName) -> void:
	_transition_active = true
	status_label.text = "TRANSFERRING PROCESS  >>  %s" % to_id
	var link := link_visuals.get(link_id) as LinkVisual
	if link != null:
		link.set_highlighted(true)
	var destination := node_visuals.get(to_id) as NodeVisual
	if destination != null:
		destination.set_destination_emphasis(true)
		var tween := create_tween().set_loops(2)
		tween.tween_property(destination, "scale", Vector2(1.1, 1.1), 0.12)
		tween.tween_property(destination, "scale", Vector2.ONE, 0.12)

func _on_position_changed(_from_id: StringName, _to_id: StringName, _link_id: StringName) -> void:
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(_finish_transition)

func _finish_transition() -> void:
	_transition_active = false
	_rebuild_neighborhood()

func _on_display_update_requested() -> void:
	if not _transition_active:
		_rebuild_neighborhood()

func _on_resized() -> void:
	queue_redraw()
	if not _transition_active:
		_rebuild_neighborhood()

func _flash_status() -> void:
	status_label.modulate = Color("ff496c")
	create_tween().tween_property(status_label, "modulate", Color.WHITE, 0.35)

func _slot_angle(index: int, count: int) -> float:
	return -PI * 0.5 + TAU * float(index) / float(count)

func _security_visible_at(node_id: StringName) -> bool:
	if knowledge.knows_security_at(node_id):
		return true
	for record in knowledge.ice_records.values():
		if int(record.get("level", 0)) >= KnowledgeLevel.Value.IDENTIFIED and record.get("node_id", &"") == node_id:
			return true
	return false

func _select_target(target_id: StringName) -> void:
	if not target_views.has(target_id):
		return
	selected_target_id = target_id
	for node_id in node_visuals:
		(node_visuals[node_id] as NodeVisual).set_destination_emphasis(node_id == target_id)
	var view := target_views[target_id] as Dictionary
	target_title.text = String(view.get("title", "UNKNOWN")).to_upper()
	var kind: StringName = view.get("kind", &"UNKNOWN")
	var details: PackedStringArray = ["CLASS // %s" % kind]
	if kind == &"NODE":
		var node: Dictionary = view.node
		details.append("TYPE // %s" % _node_type_label(node))
		details.append("SECURITY // %s" % _known_value(node, "security_level"))
		details.append("AUTHORITY // %s" % String(node.get("owner_faction", "UNKNOWN")))
	elif kind == &"LINK":
		var link: Dictionary = view.link
		details.append("ROUTE COST // %s" % _known_value(link, "traversal_cost"))
		details.append("LOCK // %s" % _known_value(link, "locked"))
	elif kind == &"SERVICE":
		var service: Dictionary = view.service
		details.append("SECURITY // %s" % _known_value(service, "security_level"))
		details.append("STATE // DETECTABLE")
	elif kind == &"ICE":
		var ice: Dictionary = view.ice
		details.append("POSITION // %s" % String(ice.get("node_id", "UNKNOWN")))
		details.append("STATE // %s" % IceState.label(int(ice.get("state", IceState.Value.DORMANT))))
		details.append("KNOWLEDGE // %s" % KnowledgeLevel.label(int(ice.get("level", KnowledgeLevel.Value.UNKNOWN))))
	elif kind == &"HACKER":
		var hacker: Dictionary = view.hacker
		details.append("POSITION // %s" % String(hacker.get("node_id", "UNKNOWN")))
		details.append("RELATION // %s" % String(hacker.get("relationship", "UNKNOWN")))
		details.append("FACTION // %s" % String(hacker.get("faction", "UNKNOWN")))
	elif kind == &"SAN":
		var san: Dictionary = view.san
		details.clear()
		details.append("SYSTEM ACCESS NODE")
		details.append("OWNER: %s" % String(san.get("owner_label", "UNKNOWN")))
		var raw_link := String(san.get("deck_link_state", "UNKNOWN"))
		details.append("LINK: %s" % ("ACTIVE" if raw_link == "LINKED" else raw_link))
		details.append("INTEGRITY: %s" % ("%d%%" % int(san.integrity_percent) if san.has("integrity_percent") else "UNKNOWN"))
		details.append("STATE: %s" % String(san.get("visual_state", "UNKNOWN")).replace("_", " "))
		var defense_lines: PackedStringArray = []
		for defense: Dictionary in san.get("defenses", []): defense_lines.append(String(defense.display_name).to_upper())
		details.append("\nDEFENSE")
		details.append("\n".join(defense_lines) if not defense_lines.is_empty() else "UNKNOWN" if not san.get("is_local", false) else "NONE")
		details.append("\nDECK LINK")
		details.append("CONNECTED" if raw_link == "LINKED" else raw_link)
	else:
		details.append("IDENTITY // UNRESOLVED")
		details.append("SCAN REQUIRED")
	target_details.text = "\n".join(details)
	var scan_target: Dictionary = view.get("scan_target", {})
	var scan_cost := Game.scan_system.get_action_cost(scan_target) if not scan_target.is_empty() else -1
	var move_cost: Variant = view.get("link", {}).get("traversal_cost", "?") if kind == &"NODE" else "--"
	target_cost.text = "MOVE %s  //  SCAN %s" % [move_cost, scan_cost if scan_cost >= 0 else "--"]
	program_cost_label.text = "    ACTION COST MOVE %s / SCAN %s" % [move_cost, scan_cost if scan_cost >= 0 else "--"]
	confirm_button.disabled = false
	target_scan_button.disabled = scan_target.is_empty()
	status_label.text = "TARGET LOCKED  //  ENTER EXECUTES  //  R SCANS"

func _clear_target_panel() -> void:
	selected_target_id = &""
	target_title.text = "NO TARGET"
	target_details.text = "Q / TAB cycles contacts.\nClick a glyph or route to inspect."
	target_cost.text = "ACTION COST // --"
	program_cost_label.text = "    ACTION COST --"
	confirm_button.disabled = true
	target_scan_button.disabled = true

func _confirm_selected_target() -> void:
	if selected_target_id == &"" or not target_views.has(selected_target_id):
		return
	var view := target_views[selected_target_id] as Dictionary
	if view.get("kind") == &"NODE":
		var result := Game.request_traversal(selected_target_id)
		if not result.success:
			status_label.text = "ACCESS DENIED  //  %s" % result.reason.to_upper()
			_flash_status()
	else:
		_scan_selected_target()

func _scan_selected_target() -> void:
	if selected_target_id == &"" or not target_views.has(selected_target_id):
		return
	var target: Dictionary = target_views[selected_target_id].get("scan_target", {})
	if not target.is_empty():
		_submit_scan(target)

func _cycle_target(direction: int) -> void:
	if target_order.is_empty():
		return
	var index := target_order.find(selected_target_id)
	index = wrapi(index + direction, 0, target_order.size())
	_select_target(target_order[index])

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_Q:
			_cycle_target(-1)
		KEY_TAB:
			_cycle_target(1)
		KEY_ENTER, KEY_E:
			_confirm_selected_target()
		KEY_R:
			if selected_target_id == &"": _on_scan_pressed()
			else: _scan_selected_target()
		KEY_BACKSPACE:
			_clear_target_panel()
		KEY_J:
			_jack_out_through_doorstop()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_on_program_selected(int(event.physical_keycode - KEY_1 + 1))

func _on_program_selected(slot: int) -> void:
	if slot == 5:
		_request_doorstop_confirmation()
		return
	var names := ["SCANNER", "SPOOF", "GHOST", "DECRYPT"]
	status_label.text = "PROGRAM SLOT %d // %s SELECTED" % [slot, names[slot - 1]]


func _request_doorstop_confirmation() -> void:
	var installed := Game.installed_doorstop_instance_ids()
	if installed.is_empty():
		status_label.text = "DOORSTOP UNAVAILABLE // NO INSTALLED COPY"
		Game.notify_doorstop_invalid("No Doorstop copy is installed in the active deck.")
		_flash_status()
		return
	_pending_doorstop_instance_id = installed[0]
	Game.set_modal_action_selection_unresolved(true)
	var node := graph.get_node(position_model.current_node_id) if graph != null and position_model != null else null
	var node_label := node.display_name if node != null else String(position_model.current_node_id)
	doorstop_confirmation.dialog_text = "DEPLOY DOORSTOP?\nDisposable Backdoor Utility\n\nAnchor temporary backdoor to:\n%s\n\nTHIS COPY WILL BE DESTROYED.\nJacking back in consumes and closes the route." % node_label
	doorstop_confirmation.popup_centered(Vector2i(500, 240))


func _confirm_doorstop_deployment() -> void:
	# Confirmation resolves the modal before authoritative deployment validation.
	Game.set_modal_action_selection_unresolved(false)
	var instance_id := _pending_doorstop_instance_id
	_pending_doorstop_instance_id = &""
	var result := Game.request_doorstop_deployment(instance_id)
	status_label.text = "DOORSTOP DEPLOYED // RETURN ROUTE ARMED" if result.success else "DOORSTOP DENIED // %s" % result.reason.to_upper()
	if not result.success:
		_flash_status()
	_update_program_bar()


func _cancel_doorstop_deployment() -> void:
	_pending_doorstop_instance_id = &""
	Game.set_modal_action_selection_unresolved(false)
	status_label.text = "DOORSTOP DEPLOYMENT CANCELLED"


func _update_program_bar() -> void:
	if doorstop_button == null:
		return
	var installed := Game.installed_doorstop_instance_ids()
	if not installed.is_empty():
		var instance := Game.program_inventory.get_instance(installed[0])
		doorstop_button.text = "[5] DOORSTOP %s // DISPOSABLE" % instance.definition.version
	else:
		doorstop_button.text = "[5] DOORSTOP // NO COPY INSTALLED"
	doorstop_button.tooltip_text = "Disposable Backdoor Utility. Deployment destroys one specific copy."
	doorstop_button.disabled = installed.is_empty()
	var anchor := Game.doorstop_controller.get_anchor(Game.intrusion_run_id) if Game.doorstop_controller != null else null
	jack_out_button.disabled = anchor == null or not anchor.active
	if anchor != null and anchor.active:
		var node := Game.network_graph.get_node(anchor.cyberspace_node_id)
		doorstop_state_label.text = "BACKDOOR ACTIVE // %s // ONE RETURN" % (node.display_name.to_upper() if node != null else anchor.cyberspace_node_id)
	else:
		doorstop_state_label.text = "BACKDOOR // CLOSED"


func _jack_out_through_doorstop() -> void:
	var result: Dictionary = Game.jack_out_through_doorstop()
	if not result.success:
		status_label.text = "JACK OUT DENIED // %s" % String(result.reason).to_upper()
		Game.notify_doorstop_invalid(result.reason)
		_flash_status()


func _on_game_domain_changed(_previous_domain: int, current_domain: int) -> void:
	visible = current_domain == Game.GameDomain.CYBERSPACE

func _submit_selected_confrontation(action_type: ActionRequest.ActionType) -> void:
	if selected_target_id == &"" or not target_views.has(selected_target_id):
		status_label.text = "SELECT A VALID CONFRONTATION TARGET"
		return
	var view := target_views[selected_target_id] as Dictionary
	var target: Dictionary = {}
	if action_type == ActionRequest.ActionType.RETREAT and view.get("kind") == &"NODE":
		target = {"kind": &"NODE", "node_id": selected_target_id}
	else:
		target = view.get("confrontation_target", {})
	if action_type == ActionRequest.ActionType.REDIRECT and not target.is_empty():
		target["redirect_node_id"] = position_model.current_node_id
	if target.is_empty():
		status_label.text = "ACTION INCOMPATIBLE WITH TARGET"
		return
	var result := Game.request_confrontation(action_type, target)
	status_label.text = "ACTION COMPLETE" if result.success else "ACTION DENIED // %s" % result.reason.to_upper()

func _submit_self_confrontation(action_type: ActionRequest.ActionType) -> void:
	var result := Game.request_confrontation(action_type, {"kind": &"SELF"})
	status_label.text = "ACTION COMPLETE" if result.success else "ACTION DENIED // %s" % result.reason.to_upper()

func _submit_mission_action(action_type: ActionRequest.ActionType) -> void:
	if selected_target_id == &"" or not target_views.has(selected_target_id):
		status_label.text = "SELECT A SERVICE TARGET"
		return
	var target: Dictionary = target_views[selected_target_id].get("mission_target", {})
	if target.is_empty():
		status_label.text = "MISSION ACTION REQUIRES A SERVICE"
		return
	var result := Game.request_exploit(target) if action_type == ActionRequest.ActionType.EXPLOIT else Game.request_transfer(target)
	status_label.text = "ACTION COMPLETE" if result.success else "ACTION DENIED // %s" % result.reason.to_upper()

func _submit_wait() -> void:
	var result := Game.request_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 1))
	status_label.text = "WAIT COMPLETE" if result.success else result.reason.to_upper()

func _update_current_panel(view: Dictionary) -> void:
	current_name.text = String(view.get("display_name", "UNKNOWN")).to_upper()
	current_type.text = "TYPE // %s" % _node_type_label(view)
	current_security.text = "SECURITY // %s" % _known_value(view, "security_level")
	current_authority.text = "AUTHORITY // %s  |  PLAYER %d" % [String(view.get("owner_faction", "UNKNOWN")), position_model.authority_level]
	var service_names: PackedStringArray = []
	for service in knowledge.get_services_at(position_model.current_node_id):
		service_names.append(String(service.get("display_name", "UNKNOWN SERVICE")))
	services_label.text = "SERVICES\n  %s" % ("\n  ".join(service_names) if not service_names.is_empty() else "NO DATA")

func _update_top_bar() -> void:
	if Game.action_clock == null:
		return
	trace_label.text = "TRACE %03d" % Game.trace_level
	tick_label.text = "TICK %06d" % Game.action_clock.current_tick
	if Game.deep_exploration != null:
		risk_label.text = "DEPTH %d  RISK %03d" % [Game.deep_exploration.current_depth, Game.deep_exploration.risk_score]
	if Game.mission != null:
		if Game.failure_controller.crash_cache.active and int(Game.failure_controller.crash_cache.resources.get(PayrollMissionController.OBJECTIVE_RESOURCE, 0)) > 0:
			objective_label.text = "OBJECTIVE // RECOVER CRASH CACHE AT %s" % Game.failure_controller.crash_cache.node_id
		else:
			objective_label.text = "OBJECTIVE // %s" % Game.mission.objective_text()

func _append_action_events(request: ActionRequest, result: ActionResult) -> void:
	event_lines.append("> %s // %s" % [request.get_action_name(), "OK" if result.success else result.reason.to_upper()])
	for event in result.events_produced:
		if event.get("debug_only", false) or (event.has("player_visible") and not event.player_visible):
			continue
		event_lines.append("> %s" % _event_description(event))
	while event_lines.size() > 8:
		event_lines.remove_at(0)
	event_feed.text = "EVENT FEED\n%s" % "\n".join(event_lines)

func _on_san_defense_alert(event: Dictionary) -> void:
	status_label.text = "WATCHDOG ALERT // SAN INTERACTION DETECTED"
	event_lines.append("> WATCHDOG // %s CONTACT" % String(event.get("interacting_actor_id", "UNKNOWN")))
	while event_lines.size() > 8: event_lines.remove_at(0)
	event_feed.text = "EVENT FEED\n%s" % "\n".join(event_lines)

func _event_description(event: Dictionary) -> String:
	match StringName(event.get("type", &"EVENT")):
		&"NODE_IDENTIFIED": return "NODE IDENTITY RESOLVED"
		&"UNKNOWN_SIGNAL_DETECTED": return "UNKNOWN ROUTE SIGNAL DETECTED"
		&"SERVICE_COMPROMISED": return "SERVICE COMPROMISED // %s" % event.get("service_id", &"")
		&"PHYSICAL_ACCESS_UNLOCKED": return "PHYSICAL ROUTE OPEN // %s" % event.get("access_point_id", &"UNKNOWN")
		&"CAPABILITY_ACQUIRED": return "CAPABILITY ACQUIRED // %s" % event.get("capability_id", &"")
		&"CREDENTIAL_STOLEN": return "IDENTITY CREDENTIAL CAPTURED"
		&"SHORTCUT_ENABLED": return "PERSISTENT SHORTCUT ENABLED"
		&"DATA_EXTRACTED": return "VOLATILE DATA ACQUIRED // EMPLOYEE_LEDGER"
		&"MISSION_COMPLETE": return "MISSION COMPLETE // LEDGER SECURED"
		&"FORCED_DISCONNECT": return "TRACE LIMIT // FORCED DISCONNECT"
		&"CRASH_CACHE_CREATED": return "CRASH CACHE LEFT AT %s" % event.get("node_id", &"UNKNOWN")
		&"CRASH_CACHE_RECOVERED": return "CRASH CACHE RECOVERED"
		&"ROUTE_ACTIVITY": return "ROUTE ACTIVITY DETECTED NEARBY"
		&"SCAN_PULSE": return "SECURITY SCAN PULSE"
		&"PLAYER_SIGNAL_ACQUIRED": return "ICE ACQUIRED PLAYER SIGNAL"
		&"PLAYER_DETECTED": return "ICE DETECTION CONFIRMED"
		&"TRACE_UPDATED": return "TRACE %+d // TOTAL %d" % [int(event.get("increase", 0)), int(event.get("trace", 0))]
		&"DOORSTOP_DEPLOYED": return "DOORSTOP ARMED // %s" % event.get("node_id", &"UNKNOWN")
		&"ICE_INTEGRITY_DAMAGED": return "ICE PROCESS DAMAGED // %d REMAINS" % int(event.get("remaining", 0))
		_: return String(event.get("type", &"NETWORK EVENT")).replace("_", " ")

func _node_type_label(view: Dictionary) -> String:
	if not view.has("node_type"):
		return "UNKNOWN"
	return NetworkNodeDefinition.NodeType.keys()[int(view.node_type)].replace("_", " ")

func _known_value(record: Dictionary, field: String) -> String:
	return str(record[field]) if record.has(field) else "UNKNOWN"

func _draw() -> void:
	var spacing := 40.0
	for x in range(0, int(size.x) + 1, int(spacing)):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(CYAN, 0.035), 1.0)
	for y in range(0, int(size.y) + 1, int(spacing)):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(CYAN, 0.035), 1.0)
	draw_line(Vector2(28, 82), Vector2(size.x - 28, 82), Color(CYAN, 0.18), 1.0)
