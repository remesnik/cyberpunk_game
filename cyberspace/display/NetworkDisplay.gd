class_name NetworkDisplay
extends Control

enum NetspaceFocusMode { NODE, LOCAL_TARGET }

const NODE_SCENE := preload("res://cyberspace/display/NodeVisual.tscn")
const LinkVisualScript := preload("res://cyberspace/display/LinkVisual.gd")
const DEFAULT_VISUALIZATION_CONFIG := preload("res://cyberspace/display/cyberspace_visualization_config.tres")
const DEFAULT_ACCESSIBILITY_CONFIG := preload("res://ui/frontend/accessibility/frontend_accessibility_config.tres")
const GameplayBindingRequestScript := preload("res://core/input/GameplayBindingRequest.gd")
const ClassSkillExecutorScript := preload("res://core/skills/ClassSkillExecutor.gd")
const SpatialLayoutScript := preload("res://cyberspace/display/CyberspaceSpatialLayout.gd")
const CYAN := Color("48e8ff")
const AMBER := Color("ffc857")

@onready var link_layer: Node2D = %LinkLayer
@onready var node_layer: Control = %NodeLayer
@onready var spatial_backdrop: CyberspaceSpatialBackdrop = %SpatialBackdrop
@onready var spatial_world: CyberspaceWorld3D = %SpatialWorld3D
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
@onready var contextual_target_label: Label = %ContextualTargetLabel
@onready var contextual_command_label: Label = %ContextualCommandLabel
@onready var command_dial: HBoxContainer = %CommandDial
@onready var control_hints: ControlHintBar = $ControlHints
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
@onready var security_level_legend: Control = %SecurityLevelLegend
@onready var capability_glossary: Control = %CapabilityGlossary
@onready var sphere_minimap: SphereMinimap = %SphereMinimap
@onready var left_panel: PanelContainer = %LeftPanel
@onready var right_panel: PanelContainer = %RightPanel
@onready var current_panel_toggle: Button = %CurrentPanelToggle
@onready var event_feed_toggle: Button = %EventFeedToggle
@export var visualization_config: Resource = DEFAULT_VISUALIZATION_CONFIG
@export var accessibility_config: Resource = DEFAULT_ACCESSIBILITY_CONFIG
@export var debug_sensor_topology := false
@export var debug_spatial_layout := false

var graph: NetworkGraph
var position_model: PlayerNetworkPosition
var knowledge: PlayerKnowledge
var sensor_topology: SensorTopologyController
var node_visuals: Dictionary = {}
var link_visuals: Dictionary = {}
var scan_targets: Dictionary = {}
var target_views: Dictionary = {}
var local_target_visuals: Dictionary = {}
var target_order: Array[StringName] = []
var selected_target_id: StringName = &""
var netspace_focus_mode := NetspaceFocusMode.NODE
var focused_node_id: StringName = &""
var focused_local_target_id: StringName = &""
var selected_command_id: StringName = &""
var _last_local_target_by_node: Dictionary = {}
var class_skill_executor: RefCounted = ClassSkillExecutorScript.new()
var _valid_contextual_commands: Array[StringName] = []
var _selected_contextual_command := &""
var event_lines: PackedStringArray = ["> SESSION READY"]
var _transition_active := false
var _spatial_layout: CyberspaceSpatialLayout = SpatialLayoutScript.new()
var _camera_tween: Tween
var _camera_motion_from := Vector3.ZERO
var _camera_motion_to := Vector3.ZERO
var _camera_view_motion_active := false
var _focus_gesture_armed := true
var _selected_active_slot := 0

var selected_active_slot: int:
	get: return _selected_active_slot
	set(value): _selected_active_slot = value
var _slot_management_panel: PanelContainer
var _slot_management_title: Label
var _slot_management_options: VBoxContainer
var _slot_management_confirmation: ConfirmationDialog
var _pending_doorstop_instance_id: StringName = &""
var _knowledge_view_history: Dictionary = {}
var _graph_zoom := 1.0
var _visible_node_count := 1
var _current_summary_expanded := false
var _event_log_expanded := false
var _context_panel_requested := false
var _monitor_full_visible := false
var _tutorial_hud_objective_id: StringName = &""

func _ready() -> void:
	security_level_legend.set_visualization_config(visualization_config)
	capability_glossary.set_visualization_config(visualization_config)
	resized.connect(_on_resized)
	EventBus.session_started.connect(_on_session_started)
	EventBus.network_traversal_started.connect(_on_traversal_started)
	EventBus.network_position_changed.connect(_on_position_changed)
	EventBus.network_display_update_requested.connect(_on_display_update_requested)
	EventBus.network_node_focus_requested.connect(_on_minimap_node_focus_requested)
	EventBus.action_resolved.connect(_on_action_resolved)
	EventBus.game_domain_changed.connect(_on_game_domain_changed)
	EventBus.san_relocated.connect(_on_san_relocated)
	EventBus.monitor_presentation_changed.connect(_on_monitor_presentation_changed)
	HudState.widget_state_changed.connect(_on_hud_state_changed)
	HudState.widget_open_requested.connect(_on_hud_widget_open_requested)
	HudState.action_feedback.connect(_on_hud_action_feedback)
	HudState.widget_emphasis_requested.connect(_on_hud_widget_emphasis_requested)
	HudState.diegetic_lesson_requested.connect(_on_diegetic_hud_lesson)
	HudState.tutorial_objective_requested.connect(_on_hud_tutorial_objective_requested)
	HudState.tutorial_objective_completed.connect(_on_hud_tutorial_objective_completed)
	sphere_minimap.collapsed_changed.connect(_on_minimap_collapsed_changed)
	HudState.set_context_active(HudState.Widget.ALERTS, true)
	HudState.set_context_active(HudState.Widget.NODE_INSPECTOR, false)
	GameplayBindings.binding_triggered.connect(_on_gameplay_binding)
	GameplayBindings.bindings_changed.connect(_on_bindings_changed)
	GameplayBindings.semantic_action_triggered.connect(_on_semantic_action)
	GameplayBindings.device_mode_changed.connect(_on_device_mode_changed)
	_create_slot_management_ui()
	_create_debug_hud()
	if Game.game_domain == Game.GameDomain.CYBERSPACE and is_visible_in_tree():
		GameplayBindings.set_context(GameplayBindings.Context.CYBERSPACE)
	scan_button.pressed.connect(_on_scan_pressed)
	local_scan_button.pressed.connect(_on_scan_pressed)
	confirm_button.pressed.connect(_confirm_selected_target)
	target_scan_button.pressed.connect(_scan_selected_target)
	_update_program_bar()
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
	current_panel_toggle.pressed.connect(_toggle_current_summary)
	event_feed_toggle.pressed.connect(_toggle_event_log)
	_apply_hud_layout()
	_apply_all_hud_states()
	if Game.session_active:
		_on_session_started()
	queue_redraw()

	EventBus.san_relocated.connect(_on_san_relocated)
	EventBus.monitor_presentation_changed.connect(_on_monitor_presentation_changed)
	HudState.widget_state_changed.connect(_on_hud_state_changed)
	HudState.widget_open_requested.connect(_on_hud_widget_open_requested)
	HudState.action_feedback.connect(_on_hud_action_feedback)
	HudState.widget_emphasis_requested.connect(_on_hud_widget_emphasis_requested)
	HudState.diegetic_lesson_requested.connect(_on_diegetic_hud_lesson)
	HudState.tutorial_objective_requested.connect(_on_hud_tutorial_objective_requested)
	HudState.tutorial_objective_completed.connect(_on_hud_tutorial_objective_completed)
	sphere_minimap.collapsed_changed.connect(_on_minimap_collapsed_changed)
	HudState.set_context_active(HudState.Widget.ALERTS, true)
	HudState.set_context_active(HudState.Widget.NODE_INSPECTOR, false)
	GameplayBindings.binding_triggered.connect(_on_gameplay_binding)
	GameplayBindings.bindings_changed.connect(_on_bindings_changed)
	GameplayBindings.semantic_action_triggered.connect(_on_semantic_action)
	GameplayBindings.device_mode_changed.connect(_on_device_mode_changed)
	_create_slot_management_ui()
	if Game.game_domain == Game.GameDomain.CYBERSPACE and is_visible_in_tree():
		GameplayBindings.set_context(GameplayBindings.Context.CYBERSPACE)
	scan_button.pressed.connect(_on_scan_pressed)
	local_scan_button.pressed.connect(_on_scan_pressed)
	confirm_button.pressed.connect(_confirm_selected_target)
	target_scan_button.pressed.connect(_scan_selected_target)
	_update_program_bar()
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
	current_panel_toggle.pressed.connect(_toggle_current_summary)
	event_feed_toggle.pressed.connect(_toggle_event_log)
	_apply_hud_layout()
	_apply_all_hud_states()
	if Game.session_active:
		_on_session_started()
	queue_redraw()

func set_models(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge, p_sensors: SensorTopologyController = null) -> void:
	graph = p_graph
	position_model = p_position
	knowledge = p_knowledge
	sensor_topology = p_sensors if p_sensors != null else (Game.sensor_topology if Game.network_graph == p_graph else null)
	_spatial_layout.configure(graph, position_model.current_node_id if position_model != null else &"")
	if position_model != null: _spatial_layout.snap_to(position_model.current_node_id)
	if spatial_world != null:
		spatial_world.configure(graph, _spatial_layout)
		spatial_world.set_camera_anchor(_spatial_layout.camera_anchor)
	if sphere_minimap != null:
		sphere_minimap.set_models(graph, position_model, knowledge, Game.sphere_tracker if Game.network_graph == graph else null)
		if Game.network_graph == graph:
			sphere_minimap.set_trail_source(Game.trail_system, &"PLAYER", Game.intrusion_run_id, func() -> int: return Game.action_clock.current_tick if Game.action_clock != null else 0)
	_rebuild_neighborhood()

func apply_accessibility(config: Resource) -> void:
	if config != null:
		accessibility_config = config
	for visual: NodeVisual in node_visuals.values():
		visual.set_reduced_animation(_reduced_animation_enabled())

func _reduced_animation_enabled() -> bool:
	return accessibility_config != null and bool(accessibility_config.get("reduced_animation"))

func _on_session_started() -> void:
	visible = Game.game_domain == Game.GameDomain.CYBERSPACE
	if visible:
		HudState.set_policy(HudState.Widget.PROGRAM_QUICKBAR, HudState.Policy.ALWAYS)
		HudState.set_user_visible(HudState.Widget.PROGRAM_QUICKBAR, true)
	HudState.set_context_active(HudState.Widget.ALERTS, true)
	_apply_all_hud_states()
	set_models(Game.network_graph, Game.player_network_position, Game.player_knowledge, Game.sensor_topology)
	if OS.is_debug_build():
		print("\n========== NETSPACE SCENE TRACE ==========")
		print("LIVE_ROOT_PATH: %s" % get_path())
		print("VIEWPORT_NAME: %s" % get_viewport().name)
		print("VISIBLE_IN_TREE: %s | SELF_VISIBLE: %s" % [is_visible_in_tree(), visible])
		print("BOTTOMBAR_CHILD_EXISTS: %s" % has_node("BottomBar"))
		if has_node("BottomBar"):
			var bb = get_node("BottomBar") as Control
			print("BOTTOMBAR_VISIBLE: %s | BOTTOMBAR_POSITION: %s | SIZE: %s" % [bb.visible, bb.position, bb.size])
			print("BOTTOMBAR_RECT: %s" % bb.get_global_rect())
		print("COMMAND_DIAL_EXISTS: %s" % has_node("CommandDial"))
		if has_node("CommandDial"):
			var cd = get_node("CommandDial") as Control
			print("COMMAND_DIAL_VISIBLE: %s | POSITION: %s | SIZE: %s" % [cd.visible, cd.position, cd.size])
		print("=========================================\n")
	_log_live_hud_state("session_started")

func _rebuild_neighborhood() -> void:
	if graph == null or position_model == null or knowledge == null or size.x <= 1.0:
		return
	var restore_local_mode := netspace_focus_mode == NetspaceFocusMode.LOCAL_TARGET
	var restore_local_target := focused_local_target_id
	for child in link_layer.get_children():
		child.queue_free()
	for child in node_layer.get_children():
		child.queue_free()
	node_visuals.clear()
	link_visuals.clear()
	local_target_visuals.clear()
	scan_targets.clear()
	target_views.clear()
	target_order.clear()
	selected_target_id = &""
	netspace_focus_mode = NetspaceFocusMode.NODE
	focused_node_id = position_model.current_node_id
	focused_local_target_id = &""

	var current_id := position_model.current_node_id
	var current_view := knowledge.get_node_view(current_id)
	if current_view.is_empty():
		status_label.text = "NO VALID NETWORK POSITION"
		return
	var map_rect := get_primary_graph_rect()
	var map_left := map_rect.position.x
	var map_right := map_rect.end.x
	var map_top := map_rect.position.y
	var map_bottom := map_rect.end.y
	var center := _spatial_screen_position(current_id, map_rect)
	var contacts := knowledge.get_local_contacts(current_id)
	var sensor_view := sensor_topology.current_view() if sensor_topology != null else {"nodes": [], "edges": []}
	var current_global_depth := int(_spatial_layout.depths.get(current_id, 0))
	var distant_nodes: Array = sensor_view.get("nodes", []).filter(func(item: Dictionary) -> bool:
		return int(item.depth) > 1 and int(_spatial_layout.depths.get(StringName(item.node_id), -1)) > current_global_depth
	)
	var total_slots := contacts.size() + distant_nodes.size()
	_visible_node_count = total_slots + 1
	var detail_level: int = visualization_config.detail_level_for(_graph_zoom, _visible_node_count)
	var current_radius: float = visualization_config.radius_for_lod(true, detail_level)
	var connected_radius: float = visualization_config.radius_for_lod(false, detail_level)
	_add_node_visual(current_view, center, true, true)
	target_views[current_id] = {"kind": &"NODE", "title": current_view.get("display_name", "CURRENT NODE"), "node": current_view, "current": true, "scan_target": {"kind": ScanSystem.CURRENT_NODE, "node_id": current_id}}
	target_order.append(current_id)
	var required_orbit: float = visualization_config.minimum_center_spacing / maxf(0.45, 2.0 * sin(PI / maxf(3.0, float(total_slots))))
	var orbit_x: float = maxf(visualization_config.preferred_horizontal_orbit, required_orbit)
	var orbit_y: float = maxf(visualization_config.preferred_vertical_orbit, required_orbit * 0.72)
	orbit_x = minf(orbit_x, maxf(0.0, (map_right - map_left) * 0.5 - visualization_config.visual_size().x * 0.5 - visualization_config.map_edge_padding))
	orbit_y = minf(orbit_y, maxf(0.0, (map_bottom - map_top) * 0.5 - visualization_config.visual_size().y * 0.5 - visualization_config.map_edge_padding))
	var positions: Dictionary = {current_id: center}
	for contact in contacts:
		var contact_node_id: StringName = contact.node.id if contact.kind == &"NODE" else &""
		var visual_position: Vector2 = _spatial_screen_position(contact_node_id, map_rect) if contact_node_id != &"" else center.lerp(map_rect.get_center(), 0.35)
		if contact.kind == &"NODE":
			positions[StringName(contact.node.id)] = visual_position
			_add_link_visual(contact.contact_id, center, visual_position, false, current_radius, connected_radius)
			_add_node_visual(contact.node, visual_position, false, true)
			scan_targets[contact.node.id] = {"kind": ScanSystem.NODE, "node_id": contact.node.id}
			scan_targets[contact.contact_id] = {"kind": ScanSystem.LINK, "contact_id": contact.contact_id}
			target_views[contact.node.id] = {"kind": &"NODE", "title": contact.node.get("display_name", "UNKNOWN NODE"), "node": contact.node, "link": contact.link, "scan_target": scan_targets[contact.node.id]}
			target_views[contact.contact_id] = {"kind": &"LINK", "title": "NETWORK LINK", "link": contact.link, "scan_target": scan_targets[contact.contact_id], "confrontation_target": {"kind": &"LINK", "contact_id": contact.contact_id}}
			target_order.append(contact.node.id)
		else:
			var fragment_position := center.lerp(visual_position, 0.72)
			_add_link_visual(contact.contact_id, center, fragment_position, true, current_radius, connected_radius)
			_add_unknown_visual(fragment_position, "UNKNOWN NODE" if contact.kind == &"UNKNOWN_NODE" else "UNKNOWN SIGNAL", contact.contact_id)
			scan_targets[contact.contact_id] = {"kind": ScanSystem.LINK, "contact_id": contact.contact_id}
			target_views[contact.contact_id] = {"kind": contact.kind, "title": "UNKNOWN NODE" if contact.kind == &"UNKNOWN_NODE" else "UNKNOWN SIGNAL", "scan_target": scan_targets[contact.contact_id]}
			target_order.append(contact.contact_id)

	# Distant topology is deliberately non-interactive. The renderer consumes only
	# sanitized knowledge views; no NetworkNodeDefinition reaches these visuals.
	var depth_groups: Dictionary = {}
	for item: Dictionary in distant_nodes:
		var depth := int(item.depth)
		var group: Array = depth_groups.get(depth, [])
		group.append(item)
		depth_groups[depth] = group
	for depth_value: Variant in depth_groups:
		var depth := int(depth_value)
		var group: Array = depth_groups[depth]
		for index in group.size():
			var item: Dictionary = group[index]
			var sensor_position := _spatial_screen_position(StringName(item.node_id), map_rect)
			positions[StringName(item.node_id)] = sensor_position
			_add_sensor_unknown_visual(sensor_position, StringName(item.node_id), depth)
	for edge: Dictionary in sensor_view.get("edges", []):
		if int(edge.depth) <= 1 or not positions.has(edge.source) or not positions.has(edge.destination): continue
		_add_link_visual(StringName(edge.link_id), positions[edge.source], positions[edge.destination], true, connected_radius, connected_radius)
	# Knowledge is cumulative. Nodes that were revealed or visited earlier stay
	# rendered even after the live sensor origin moves elsewhere.
	for known_value: Variant in knowledge.node_records.keys():
		var known_id := StringName(known_value)
		if node_visuals.has(known_id) or not _spatial_layout.anchors.has(known_id): continue
		var known_view := knowledge.get_node_view(known_id)
		if known_view.is_empty(): continue
		var known_position := _spatial_screen_position(known_id, map_rect)
		if bool(known_view.get("identity_known", false)): _add_node_visual(known_view, known_position, false, false)
		else: _add_sensor_unknown_visual(known_position, known_id, int(_spatial_layout.depths.get(known_id, 0)))
	var discovered_ids := _discovered_node_ids()
	if spatial_world != null: spatial_world.set_discovered_nodes(discovered_ids, graph)

	location_label.text = "CURRENT HOST  //  %s" % String(current_view.get("display_name", "UNKNOWN")).to_upper()
	var sensor_rating := sensor_topology.sensors_rating if sensor_topology != null else 0
	resource_label.text = "TRAVERSAL UNITS  %02d    |    SENSORS %d    |    KNOWN CONTACTS  %02d" % [position_model.traversal_points, sensor_rating, contacts.size() + distant_nodes.size()]
	if debug_sensor_topology and sensor_topology != null:
		status_label.text = "\n".join(sensor_topology.debug_lines())
	elif debug_spatial_layout:
		var final_lines := spatial_world.debug_final_lines() if spatial_world != null else _spatial_layout.debug_lines()
		status_label.text = "\n".join(final_lines)
		print("\n".join(final_lines))
	else: status_label.text = "SELECT A CONNECTED HOST"
	_rebuild_services(current_id)
	_rebuild_known_entities(current_id, contacts)
	_update_current_panel(current_view)
	_update_top_bar()
	_update_program_bar()
	_update_binding_labels()
	_clear_target_panel()
	if restore_local_mode:
		focused_local_target_id = restore_local_target
		_enter_local_target_mode()

func _add_node_visual(node_view: Dictionary, center: Vector2, current: bool, selectable: bool) -> void:
	var visual := NODE_SCENE.instantiate() as NodeVisual
	node_layer.add_child(visual)
	visual.apply_visualization_config(visualization_config)
	visual.set_reduced_animation(_reduced_animation_enabled())
	visual.set_view_context(_graph_zoom, _visible_node_count)
	visual.position = center - visual.size * 0.5
	var node_id: StringName = node_view.get("id", &"")
	visual.configure_view(node_view, current, selectable, _security_visible_at(node_id))
	if _knowledge_view_history.has(node_id):
		visual.play_knowledge_resolution(_knowledge_view_history[node_id])
	_knowledge_view_history[node_id] = node_view.duplicate(true)
	visual.selected.connect(_on_node_selected)
	visual.scan_requested.connect(_on_scan_target_requested)
	visual.capability_selected.connect(_on_node_capability_selected)
	node_visuals[node_id] = visual
	_apply_spatial_scale(visual, node_id)

func _add_unknown_visual(center: Vector2, unknown_title: String, contact_id: StringName) -> void:
	var visual := NODE_SCENE.instantiate() as NodeVisual
	node_layer.add_child(visual)
	visual.apply_visualization_config(visualization_config)
	visual.set_reduced_animation(_reduced_animation_enabled())
	visual.set_view_context(_graph_zoom, _visible_node_count)
	visual.position = center - visual.size * 0.5
	visual.configure_unknown(contact_id)
	visual.title = unknown_title
	visual.scan_requested.connect(_on_scan_target_requested)

func _add_sensor_unknown_visual(center: Vector2, node_id: StringName, depth: int) -> void:
	var visual := NODE_SCENE.instantiate() as NodeVisual
	node_layer.add_child(visual)
	visual.apply_visualization_config(visualization_config)
	visual.set_reduced_animation(_reduced_animation_enabled())
	visual.set_view_context(_graph_zoom, _visible_node_count)
	visual.position = center - visual.size * 0.5
	visual.configure_unknown(&"")
	visual.title = "UNKNOWN NODE"
	visual.tooltip_text = "UNKNOWN NODE\nDetected by deck sensors."
	visual.modulate = Color(0.72, 0.8, 0.86, 0.58)
	visual.set_meta(&"sensor_node_id", node_id)
	visual.set_meta(&"sensor_depth", depth)
	node_visuals[node_id] = visual
	_apply_spatial_scale(visual, node_id)

func _spatial_screen_position(node_id: StringName, map_rect: Rect2) -> Vector2:
	if spatial_world != null and spatial_world.anchors.has(node_id): return spatial_world.screen_position(node_id)
	return (_spatial_layout.project(node_id, map_rect) as Dictionary).position

func _apply_spatial_scale(visual: Control, node_id: StringName) -> void:
	var distance := spatial_world.camera_distance(node_id) if spatial_world != null else CyberspaceSpatialLayout.CAMERA_DISTANCE
	var compensated_scale := clampf(CyberspaceSpatialLayout.FOCAL_LENGTH / distance / 66.0, 0.88, 1.30)
	visual.scale = Vector2.ONE * compensated_scale
	visual.pivot_offset = visual.size * 0.5
	visual.z_index = clampi(int(4000.0 - distance * 10.0), -4096, 4096)

func _update_spatial_projection() -> void:
	var map_rect := get_primary_graph_rect()
	for node_id: StringName in node_visuals:
		var visual := node_visuals[node_id] as Control
		visual.position = _spatial_screen_position(node_id, map_rect) - visual.size * 0.5
		_apply_spatial_scale(visual, node_id)
	spatial_backdrop.set_camera_offset(Vector2(spatial_world.view_anchor.x, spatial_world.view_anchor.z) if spatial_world != null else Vector2.ZERO)

func _discovered_node_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in knowledge.node_records.keys():
		var id := StringName(value)
		if _spatial_layout.anchors.has(id): result.append(id)
	if position_model != null and not result.has(position_model.current_node_id): result.append(position_model.current_node_id)
	return result

func _add_link_visual(link_id: StringName, start: Vector2, finish: Vector2, unknown: bool, start_radius: float, finish_radius: float) -> void:
	var visual := LinkVisualScript.new() as LinkVisual
	link_layer.add_child(visual)
	var clipped_start := _hex_endpoint(start, finish, start_radius + visualization_config.endpoint_clearance)
	var clipped_finish := _hex_endpoint(finish, start, finish_radius + visualization_config.endpoint_clearance)
	visual.configure(link_id, clipped_start, clipped_finish, unknown, visualization_config)
	visual.set_view_context(_graph_zoom, _visible_node_count, visualization_config)
	visual.scan_requested.connect(_on_scan_target_requested)
	visual.selected.connect(_select_target)
	link_visuals[link_id] = visual

func _hex_endpoint(center: Vector2, toward: Vector2, radius: float) -> Vector2:
	var direction := (toward - center).normalized()
	if direction == Vector2.ZERO: return center
	var ray_end := center + direction * radius * 3.0
	var nearest := ray_end
	var nearest_distance := INF
	var vertices := PackedVector2Array()
	for index in 6:
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)
	for index in 6:
		var hit: Variant = Geometry2D.segment_intersects_segment(center, ray_end, vertices[index], vertices[(index + 1) % 6])
		if hit is Vector2:
			var distance := center.distance_to(hit)
			if distance < nearest_distance:
				nearest = hit
				nearest_distance = distance
	return nearest

func _rebuild_services(current_node_id: StringName) -> void:
	for child in service_list.get_children():
		child.queue_free()
	for service in knowledge.get_services_at(current_node_id):
		var button := Button.new()
		button.text = "SERVICE // %s" % String(service.get("display_name", "UNKNOWN SERVICE")).to_upper()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var target := {"kind": ScanSystem.SERVICE, "contact_id": service.contact_id}
		var contact_id: StringName = service.contact_id
		target_views[contact_id] = {"kind": &"SERVICE", "title": service.get("display_name", "UNKNOWN SERVICE"), "service": service, "scanned": bool(service.get("scanned", false)), "connectable": bool(service.get("connectable", false)), "disableable": bool(service.get("disableable", false)), "interceptable": bool(service.get("interceptable", false)), "scan_target": target, "mission_target": {"kind": &"SERVICE", "contact_id": contact_id}}
		target_order.append(contact_id)
		button.pressed.connect(func() -> void: _select_target(contact_id))
		service_list.add_child(button)


func _local_target_ids_for_node(node_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if target_views.has(node_id): result.append(node_id)
	for target_id: StringName in target_views:
		var view := target_views[target_id] as Dictionary
		var kind: StringName = view.get("kind", &"")
		if kind == &"SERVICE":
			result.append(target_id)
		elif kind == &"ICE" and StringName((view.get("ice", {}) as Dictionary).get("node_id", &"")) == node_id:
			result.append(target_id)
	return result


func _create_local_target_visual(target_id: StringName, index: int, count: int) -> void:
	var view := target_views[target_id] as Dictionary
	var button := Button.new()
	button.name = "LocalTarget_%s" % target_id
	button.text = "[%s]\n%s" % [String(view.get("kind", "TARGET")), String(view.get("title", "LOCAL TARGET")).to_upper()]
	button.tooltip_text = button.text.replace("\n", " // ")
	button.icon = load(_target_icon_path(StringName(view.get("kind", &"UNKNOWN")))) as Texture2D
	button.custom_minimum_size = Vector2(150, 58)
	button.size = Vector2(150, 58)
	button.set_meta("local_target_id", target_id)
	button.pressed.connect(func() -> void: _select_local_target(target_id))
	node_layer.add_child(button)
	local_target_visuals[target_id] = button
	var center_visual := node_visuals.get(focused_node_id) as Control
	var center := center_visual.position + center_visual.size * center_visual.scale * 0.5 if center_visual != null else get_primary_graph_rect().get_center()
	var angle := -PI * 0.5 + TAU * float(index) / float(maxi(1, count))
	button.position = center + Vector2(cos(angle), sin(angle)) * 150.0 - button.size * 0.5


func _enter_local_target_mode() -> bool:
	if position_model == null or focused_node_id != position_model.current_node_id:
		return false
	var local_ids := _local_target_ids_for_node(focused_node_id)
	if local_ids.is_empty():
		status_label.text = "NO LOCAL TARGETS"
		return false
	netspace_focus_mode = NetspaceFocusMode.LOCAL_TARGET
	var remembered_id := StringName(_last_local_target_by_node.get(focused_node_id, &""))
	var remembered := focused_local_target_id if focused_local_target_id in local_ids else (remembered_id if remembered_id in local_ids else local_ids[0])
	focused_local_target_id = remembered
	for index in local_ids.size(): _create_local_target_visual(local_ids[index], index, local_ids.size())
	_select_local_target(focused_local_target_id)
	return true


func _exit_local_target_mode() -> void:
	if netspace_focus_mode != NetspaceFocusMode.LOCAL_TARGET: return
	if not focused_local_target_id.is_empty(): _last_local_target_by_node[focused_node_id] = focused_local_target_id
	for visual: Button in local_target_visuals.values(): visual.queue_free()
	local_target_visuals.clear()
	netspace_focus_mode = NetspaceFocusMode.NODE
	focused_local_target_id = &""
	selected_target_id = focused_node_id
	_valid_contextual_commands.clear()
	_selected_contextual_command = &""
	selected_command_id = &""
	_select_target(focused_node_id) if target_views.has(focused_node_id) else _clear_target_panel()


func _select_local_target(target_id: StringName) -> void:
	if netspace_focus_mode != NetspaceFocusMode.LOCAL_TARGET or not local_target_visuals.has(target_id): return
	focused_local_target_id = target_id
	selected_target_id = target_id
	for id_value: Variant in local_target_visuals:
		var visual := local_target_visuals[id_value] as Button
		visual.modulate = Color("ffc857") if StringName(id_value) == target_id else Color.WHITE
	_select_target(target_id)

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
		target_views[contact_id] = {"kind": &"ICE", "title": record.get("display_name", "SECURITY PROCESS"), "ice": record, "scanned": bool(record.get("scanned", false)), "attackable": bool(record.get("attackable", true)), "bypassable": bool(record.get("bypassable", false)), "confrontation_target": ice_target, "scan_target": {"kind": ScanSystem.ICE_SIGNAL, "contact_id": contact_id}}
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

func _on_node_selected(node_id: StringName) -> void:
	if _transition_active:
		return
	if not target_views.has(node_id) or (target_views[node_id] as Dictionary).get("kind") != &"NODE": return
	focused_node_id = node_id
	_select_target(node_id)
	if node_id == position_model.current_node_id:
		if netspace_focus_mode == NetspaceFocusMode.NODE: _enter_local_target_mode()
		return
	var result := Game.request_traversal(node_id)
	if not result.success:
		status_label.text = "ACCESS DENIED  //  %s" % result.reason.to_upper()
		_flash_status()

func _on_node_capability_selected(node_id: StringName, capability_type: int) -> void:
	var definition: Resource = visualization_config.capability_catalog.definition_for(capability_type)
	if definition == null:
		return
	selected_target_id = &""
	_valid_contextual_commands.clear()
	_selected_contextual_command = &""
	selected_command_id = &""
	_context_panel_requested = true
	_refresh_context_panel_visibility()
	for visual_id in node_visuals:
		(node_visuals[visual_id] as NodeVisual).set_destination_emphasis(visual_id == node_id)
	target_title.text = "%s // %s" % [String(definition.display_name).to_upper(), String(node_id)]
	var count: int = int(knowledge.get_known_node_capability_counts(node_id).get(capability_type, 1))
	var details: PackedStringArray = [String(definition.tooltip_description), "DISCOVERED // %d" % int(count)]
	var matching_services: PackedStringArray = []
	for service: Dictionary in knowledge.get_services_at(node_id):
		if (service.get("capability_types", []) as Array).has(capability_type):
			matching_services.append(String(service.get("display_name", "KNOWN SERVICE")))
	if not matching_services.is_empty():
		details.append("KNOWN SERVICES")
		for service_name in matching_services: details.append("  %s" % service_name)
	target_details.text = "\n".join(details)
	target_cost.text = "CAPABILITY FILTER // ACTIVE"
	program_cost_label.text = "    INSPECTION // %s" % String(definition.display_name).to_upper()
	confirm_button.disabled = true
	target_scan_button.disabled = true
	_update_contextual_command_hud()
	_refresh_contextual_command_buttons()
	status_label.text = "NODE INSPECTOR // CAPABILITY FILTERED"

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

func _on_traversal_started(from_id: StringName, to_id: StringName, link_id: StringName) -> void:
	_transition_active = true
	_spatial_layout.begin_transition(from_id, to_id)
	_camera_motion_from = spatial_world.view_anchor
	_camera_motion_to = _spatial_layout.world_position(to_id)
	spatial_world.begin_camera_motion(&"TRAVERSAL")
	status_label.text = "TRANSFERRING PROCESS  >>  %s" % to_id
	var link := link_visuals.get(link_id) as LinkVisual
	if link != null:
		link.set_highlighted(true)
	var destination := node_visuals.get(to_id) as NodeVisual
	if destination != null:
		destination.set_destination_emphasis(true)

func _on_position_changed(_from_id: StringName, _to_id: StringName, _link_id: StringName) -> void:
	if _reduced_animation_enabled():
		_spatial_layout.set_transition_progress(1.0)
		spatial_world.set_camera_anchor(_camera_motion_to)
		_update_spatial_projection()
		_finish_transition()
		return
	_camera_tween = create_tween()
	_camera_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_method(_set_camera_transition_progress, 0.0, 1.0, 0.5)
	_camera_tween.tween_callback(_finish_transition)

func _set_camera_transition_progress(progress: float) -> void:
	_spatial_layout.set_transition_progress(progress)
	spatial_world.set_camera_anchor(_camera_motion_from.lerp(_camera_motion_to, progress * progress * (3.0 - 2.0 * progress)))
	_update_spatial_projection()

func _finish_transition() -> void:
	_transition_active = false
	spatial_world.finish_camera_motion()
	_rebuild_neighborhood()

func _process(delta: float) -> void:
	if not visible or spatial_world == null or _transition_active or _camera_view_motion_active: return
	var direction := GameplayBindings.camera_pan_vector()
	if spatial_world.pan(direction, delta, _discovered_node_ids()):
		_update_spatial_projection()
		_update_camera_debug_status()
	var focus_direction := GameplayBindings.focus_vector()
	if focus_direction.length() < 0.3: _focus_gesture_armed = true
	elif _focus_gesture_armed:
		_focus_gesture_armed = false
		_focus_local_target(focus_direction) if netspace_focus_mode == NetspaceFocusMode.LOCAL_TARGET else _focus_spatial_node(focus_direction)

func _focus_spatial_node(direction: Vector2) -> void:
	var candidates: Array[Dictionary] = []
	for id_value: Variant in node_visuals:
		var id := StringName(id_value); var visual := node_visuals[id] as NodeVisual
		var priority := 500.0 if target_views.has(id) and (target_views[id] as Dictionary).get("kind") == &"NODE" else (100.0 if visual.is_current else 0.0)
		candidates.append({"id": id, "position": visual.position + visual.size * visual.scale * 0.5, "priority": priority, "enabled": visual.visible})
	var next := DirectionalFocusSelector.choose(selected_target_id, direction, candidates)
	if next == &"": return
	if target_views.has(next): _select_target(next)
	else:
		selected_target_id = next
		for id_value: Variant in node_visuals: (node_visuals[id_value] as NodeVisual).set_destination_emphasis(StringName(id_value) == next)
		status_label.text = "FOCUS // %s // INSPECTION ONLY" % next
	focused_node_id = next


func _focus_local_target(direction: Vector2) -> void:
	if local_target_visuals.is_empty(): return
	var candidates: Array[Dictionary] = []
	for id_value: Variant in local_target_visuals:
		var visual := local_target_visuals[id_value] as Button
		candidates.append({"id": StringName(id_value), "position": visual.position + visual.size * 0.5, "priority": 0.0, "enabled": true})
	var next := DirectionalFocusSelector.choose(focused_local_target_id, direction, candidates)
	if next != "": _select_local_target(next)

func recenter_camera() -> void:
	if spatial_world == null or position_model == null or _transition_active: return
	if _camera_tween != null and _camera_tween.is_running(): _camera_tween.kill()
	_camera_view_motion_active = true
	_camera_motion_from = spatial_world.view_anchor
	_camera_motion_to = _spatial_layout.world_position(position_model.current_node_id)
	spatial_world.begin_camera_motion(&"RECENTER")
	_camera_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_method(_set_recenter_progress, 0.0, 1.0, 0.5)
	_camera_tween.tween_callback(_finish_recenter)

func _set_recenter_progress(progress: float) -> void:
	spatial_world.set_camera_anchor(_camera_motion_from.lerp(_camera_motion_to, progress))
	_update_spatial_projection()

func _finish_recenter() -> void:
	spatial_world.set_camera_anchor(_camera_motion_to)
	spatial_world.finish_camera_motion(); _camera_view_motion_active = false
	_update_spatial_projection(); _update_camera_debug_status()

func _update_camera_debug_status() -> void:
	if not debug_spatial_layout or position_model == null: return
	var player_anchor := _spatial_layout.world_position(position_model.current_node_id)
	var offset := spatial_world.view_anchor - player_anchor
	status_label.text = "PLAYER NODE: %s\nCAMERA OFFSET: x=%.1f z=%.1f\nCAMERA MODE: %s\nDISCOVERED NODES: %d\nRENDERED DISCOVERED NODES: %d" % [position_model.current_node_id, offset.x, offset.z, spatial_world.camera_mode, _discovered_node_ids().size(), node_visuals.size()]

func _on_semantic_action(action_id: StringName) -> void:
	if not visible: return
	if OS.is_debug_build() and action_id in [&"previous_context_command", &"next_context_command"]:
		print("[Input] action=%s pressed=true" % action_id)
	match action_id:
		&"primary_action":
			if netspace_focus_mode == NetspaceFocusMode.LOCAL_TARGET:
				if not _valid_contextual_commands.is_empty(): _execute_selected_contextual_command()
			elif target_views.has(selected_target_id) and (target_views[selected_target_id] as Dictionary).get("kind") == &"NODE":
				_on_node_selected(selected_target_id)
		&"back_action": _close_slot_management() if _slot_management_panel != null and _slot_management_panel.visible else (_exit_local_target_mode() if netspace_focus_mode == NetspaceFocusMode.LOCAL_TARGET else _clear_target_panel())
		&"recenter_camera": recenter_camera()
		&"previous_slot": select_previous_active_slot()
		&"next_slot": select_next_active_slot()
		&"previous_context_command": _handle_context_command_input(-1)
		&"next_context_command": _handle_context_command_input(1)
		&"class_skill": _handle_class_skill_input()
		&"execute_program": execute_active_slot()
		&"open_slot_management": open_selected_slot_management()
		&"open_loadout": HudState.widget_open_requested.emit(HudState.Widget.PROGRAM_QUICKBAR)


func _handle_context_command_input(direction: int) -> void:
	if selected_target_id.is_empty():
		_focus_spatial_node(Vector2.LEFT if direction < 0 else Vector2.RIGHT)
		return
	cycle_contextual_command(direction)


func _handle_class_skill_input() -> void:
	if selected_target_id.is_empty():
		_focus_spatial_node(Vector2.UP)
		return
	execute_class_skill()


func cycle_contextual_command(direction: int) -> void:
	if _valid_contextual_commands.is_empty(): return
	var index := _valid_contextual_commands.find(_selected_contextual_command)
	if index < 0: index = 0
	else: index = posmod(index + direction, _valid_contextual_commands.size())
	_selected_contextual_command = _valid_contextual_commands[index]
	selected_command_id = _selected_contextual_command
	_update_contextual_command_hud()


func execute_class_skill() -> void:
	var player_class := StringName(Game.persistent_game_state.player_state.get("player_class", &"")) if Game.persistent_game_state != null else &""
	var target := target_views.get(selected_target_id, {}) as Dictionary
	var result: Dictionary = class_skill_executor.execute(player_class, target, {"focus_mode": netspace_focus_mode, "current_node_id": position_model.current_node_id if position_model != null else &""})
	status_label.text = result.reason.to_upper()


func _execute_selected_contextual_command() -> void:
	match _selected_contextual_command:
		&"ENTER":
			var move_result := Game.request_traversal(selected_target_id)
			_set_action_feedback(move_result)
		&"SCAN", &"PROBE": _scan_selected_target()
		&"ATTACK": _submit_selected_confrontation(ActionRequest.ActionType.ATTACK_PROCESS)
		_: status_label.text = "%s NOT AVAILABLE" % _contextual_command_label(_selected_contextual_command)


func _set_action_feedback(result: ActionResult) -> void:
	status_label.text = "ACTION COMPLETE" if result.success else "ACTION DENIED // %s" % result.reason.to_upper()
	if not result.success: _flash_status()

func select_previous_active_slot() -> void:
	var count := Game.program_loadout.capacity if Game.program_loadout != null else 0
	if count > 0: _selected_active_slot = posmod(_selected_active_slot - 1, count); _update_program_bar()
func select_next_active_slot() -> void:
	var count := Game.program_loadout.capacity if Game.program_loadout != null else 0
	if count > 0: _selected_active_slot = posmod(_selected_active_slot + 1, count); _update_program_bar()
func execute_active_slot() -> void:
	execute_selected_active_program()


func execute_selected_active_program() -> void:
	var instance_id := Game.program_loadout.instance_at(_selected_active_slot) if Game.program_loadout != null else &""
	if instance_id.is_empty():
		status_label.text = "EMPTY SLOT"
		return
	var instance := Game.program_inventory.get_instance(instance_id) if Game.program_inventory != null else null
	if instance == null:
		status_label.text = "PROGRAM INSTANCE UNAVAILABLE"
		return
	if netspace_focus_mode == NetspaceFocusMode.LOCAL_TARGET and (selected_target_id.is_empty() or not selected_target_id in local_target_visuals):
		status_label.text = "PROGRAM INCOMPATIBLE WITH TARGET"
		_flash_status()
		return
	if instance.definition is DoorstopDefinition:
		var result := Game.request_doorstop_deployment(instance_id)
		status_label.text = "PROGRAM EXECUTED" if result.success else "PROGRAM DENIED // %s" % result.reason.to_upper()
		if not result.success: _flash_status()
		_update_program_bar()
		return
	status_label.text = "NO TARGET SELECTED" if selected_target_id.is_empty() else "PROGRAM HAS NO ACTION FOR TARGET"
	_flash_status()
func _on_device_mode_changed(_mode: int) -> void:
	_update_binding_labels()

func _on_display_update_requested() -> void:
	if not _transition_active:
		_rebuild_neighborhood()

func _on_minimap_node_focus_requested(node_id: StringName) -> void:
	if knowledge == null or not knowledge.player_knows_node_exists(node_id): return
	if node_visuals.has(node_id):
		if target_views.has(node_id):
			_select_target(node_id)
		else:
			for visual_id in node_visuals: (node_visuals[visual_id] as NodeVisual).set_destination_emphasis(visual_id == node_id)
			status_label.text = "MAP FOCUS // %s" % _known_node_focus_name(node_id)
	else:
		status_label.text = "MAP FOCUS // %s // OUTSIDE LOCAL VIEW" % _known_node_focus_name(node_id)

func _known_node_focus_name(node_id: StringName) -> String:
	var view := knowledge.get_node_view(node_id)
	return String(view.get("display_name", node_id)).to_upper() if bool(view.get("identity_known", false)) else "UNKNOWN NODE"

func _on_san_relocated(_san_id: StringName, _previous_node_id: StringName, current_node_id: StringName) -> void:
	var visual := node_visuals.get(current_node_id) as NodeVisual
	if visual != null:
		visual.play_san_arrival()

func _on_resized() -> void:
	_apply_hud_layout()
	queue_redraw()
	if not _transition_active:
		_rebuild_neighborhood()
	_log_live_hud_state("resized")


func _log_live_hud_state(reason: String) -> void:
	if not OS.is_debug_build() or not is_inside_tree(): return
	var slot_count := Game.program_loadout.capacity if Game.program_loadout != null else 0
	var rendered_slot_count := $BottomBar/Margin/Rows/Programs.get_child_count() if has_node("BottomBar/Margin/Rows/Programs") else -1
	var commands := _valid_contextual_commands
	print("[NetspaceHUD] reason=%s hud_instance=%s active_slot_bar_instance=%s command_dial_instance=%s visible=%s" % [reason, name, str(has_node("BottomBar")), str(has_node("BottomBar/Margin/Rows/Programs")), str(has_node("CommandDial"))])
	print("[DeckSlots] active_slot_count=%d loaded_program_count=%d rendered_slot_widgets=%d bar_visible=%s bar_size=%s bar_position=%s viewport_size=%s" % [slot_count, Game.program_loadout.installed_instance_ids.size() if Game.program_loadout != null else 0, rendered_slot_count, str($BottomBar.visible) if has_node("BottomBar") else "false", str($BottomBar.size) if has_node("BottomBar") else "(0,0)", str($BottomBar.position) if has_node("BottomBar") else "(0,0)", str(get_viewport_rect().size)])
	print("[CommandDial] target=%s focus_mode=%s valid_commands=%s selected=%s selected_index=%d rendered_icon_count=%d visible=%s size=%s position=%s" % [selected_target_id, netspace_focus_mode, commands, _selected_contextual_command, commands.find(_selected_contextual_command), command_dial.get_child_count() if command_dial != null else -1, str(command_dial.visible) if command_dial != null else "false", str(command_dial.size) if command_dial != null else "(0,0)", str(command_dial.position) if command_dial != null else "(0,0)"])
	if slot_count > 0 and rendered_slot_count == 0: push_error("Active slots exist but HUD rendered none")
	if not selected_target_id.is_empty() and not commands.is_empty() and command_dial != null and command_dial.get_child_count() == 0: push_error("Valid commands exist but command dial rendered none")

func _flash_status() -> void:
	status_label.modulate = Color("ff496c")
	create_tween().tween_property(status_label, "modulate", Color.WHITE, 0.35)

func _slot_angle(index: int, count: int) -> float:
	return -PI * 0.5 + TAU * float(index) / float(count)

func _dense_contact_position(index: int, count: int, map_rect: Rect2, center: Vector2) -> Vector2:
	var aspect := map_rect.size.x / maxf(map_rect.size.y, 1.0)
	var columns := maxi(2, int(ceil(sqrt(float(count + 1) * aspect))))
	var rows := maxi(2, int(ceil(float(count + 1) / float(columns))))
	var center_column := columns / 2
	var center_row := rows / 2
	var cell_index := index
	var reserved_index := center_row * columns + center_column
	if cell_index >= reserved_index: cell_index += 1
	var column := cell_index % columns
	var row := cell_index / columns
	var cell_size := Vector2(map_rect.size.x / float(columns), map_rect.size.y / float(rows))
	var position := map_rect.position + Vector2((float(column) + 0.5) * cell_size.x, (float(row) + 0.5) * cell_size.y)
	# The current node retains the exact visual center; its reserved grid cell
	# keeps dense contacts from being placed on top of it.
	if position.distance_to(center) < minf(cell_size.x, cell_size.y) * 0.35:
		position.x += cell_size.x * 0.42
	return position

func set_graph_zoom(value: float) -> void:
	var next_zoom := clampf(value, 0.3, 1.25)
	if is_equal_approx(next_zoom, _graph_zoom): return
	_graph_zoom = next_zoom
	_rebuild_neighborhood()

func graph_detail_level() -> int:
	return visualization_config.detail_level_for(_graph_zoom, _visible_node_count)

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		recenter_camera(); get_viewport().set_input_as_handled(); return
	if not event is InputEventMouseButton or not event.pressed: return
	var graph_rect := get_primary_graph_rect()
	if not graph_rect.has_point(event.position):
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		set_graph_zoom(_graph_zoom + 0.1)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		set_graph_zoom(_graph_zoom - 0.1)
		get_viewport().set_input_as_handled()

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
	_context_panel_requested = true
	_refresh_context_panel_visibility()
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
	else:
		details.append("IDENTITY // UNRESOLVED")
		details.append("SCAN REQUIRED")
	target_details.text = "\n".join(details)
	var scan_target: Dictionary = view.get("scan_target", {})
	var scan_cost := Game.scan_system.get_action_cost(scan_target) if not scan_target.is_empty() else -1
	var move_cost: Variant = view.get("link", {}).get("traversal_cost", "?") if kind == &"NODE" else "--"
	target_cost.text = "MOVE %s  //  SCAN %s" % [move_cost, scan_cost if scan_cost >= 0 else "--"]
	program_cost_label.text = "    ACTION COST MOVE %s / SCAN %s" % [move_cost, scan_cost if scan_cost >= 0 else "--"]
	# Traversal is a direct spatial gesture: one click on a reachable node. The
	# generic execute button remains available only for non-movement targets.
	confirm_button.visible = kind != &"NODE"
	confirm_button.disabled = kind == &"NODE"
	target_scan_button.disabled = scan_target.is_empty()
	_recalculate_contextual_commands()
	_refresh_contextual_command_buttons()
	if OS.is_debug_build(): print("[NetspaceTarget] focus_mode=%s focused_node_id=%s focused_local_target_id=%s resolved_target=%s" % [netspace_focus_mode, focused_node_id, focused_local_target_id, target_id])
	status_label.text = "TRAVERSAL ACCEPTED" if kind == &"NODE" else "TARGET LOCKED  //  ENTER EXECUTES  //  R SCANS"


func get_valid_commands(target_id: StringName = selected_target_id, _player_state: Variant = null, _run_state: Variant = null) -> Array[StringName]:
	var commands: Array[StringName] = []
	if target_id.is_empty() or not target_views.has(target_id): return commands
	var view := target_views[target_id] as Dictionary
	var kind: StringName = view.get("kind", &"UNKNOWN")
	var scanned := bool(view.get("scanned", false))
	var nested: Dictionary = view.get("node", view.get("ice", view.get("service", {}))) as Dictionary
	scanned = scanned or bool(nested.get("scanned", false))
	if not scanned and kind in [&"NODE", &"ICE", &"SERVICE", &"FILE", &"DEVICE_OBJECT"]: commands.append(&"SCAN")
	match kind:
		&"NODE":
			if scanned and bool(view.get("probeable", false)): commands.append(&"PROBE")
			var link := view.get("link", {}) as Dictionary
			if bool(view.get("enterable", false)) or (not link.is_empty() and target_id != position_model.current_node_id): commands.append(&"ENTER")
		&"ICE":
			if scanned and bool(view.get("probeable", false)): commands.append(&"PROBE")
			if bool(view.get("attackable", false)) or not view.get("confrontation_target", {}).is_empty(): commands.append(&"ATTACK")
			if bool(view.get("bypassable", false)): commands.append(&"BYPASS")
		&"SERVICE":
			if scanned and bool(view.get("probeable", false)): commands.append(&"PROBE")
			if bool(view.get("connectable", false)): commands.append(&"CONNECT")
			if bool(view.get("disableable", false)): commands.append(&"DISABLE")
			if bool(view.get("interceptable", false)): commands.append(&"INTERCEPT")
		&"FILE":
			if scanned and bool(view.get("analyzable", true)): commands.append(&"ANALYZE")
			if bool(view.get("downloadable", false)): commands.append(&"DOWNLOAD")
			if bool(view.get("deletable", false)): commands.append(&"DELETE")
		&"DEVICE_OBJECT":
			if scanned and bool(view.get("probeable", false)): commands.append(&"PROBE")
			if bool(view.get("connectable", false)): commands.append(&"CONNECT")
			if bool(view.get("disableable", false)): commands.append(&"DISABLE")
			if bool(view.get("controllable", false)): commands.append(&"TAKE_CONTROL")
	return commands


func available_commands_for_target(target_id: StringName = selected_target_id) -> Array[StringName]:
	return get_valid_commands(target_id)


func _recalculate_contextual_commands() -> void:
	var previous := _selected_contextual_command
	_valid_contextual_commands = get_valid_commands()
	var target_view := target_views.get(selected_target_id, {}) as Dictionary
	var target_nested := target_view.get("node", target_view.get("ice", target_view.get("service", {}))) as Dictionary
	var target_scanned := bool(target_view.get("scanned", false)) or bool(target_nested.get("scanned", false))
	if not target_scanned and &"SCAN" in _valid_contextual_commands:
		_selected_contextual_command = &"SCAN"
	elif previous in _valid_contextual_commands:
		_selected_contextual_command = previous
	elif _valid_contextual_commands.is_empty():
		_selected_contextual_command = &""
	else:
		_selected_contextual_command = _valid_contextual_commands[0]
	selected_command_id = _selected_contextual_command
	_update_contextual_command_hud()


func _contextual_command_label(command_id: StringName) -> String:
	match command_id:
		&"DEVICE_OBJECT": return "DEVICE / OBJECT"
		&"ATTACK_PROCESS": return "ATTACK"
		_: return String(command_id).replace("_", " ")


func _command_icon_path(command_id: StringName) -> String:
	var filename := "attack" if command_id == &"ATTACK_PROCESS" else String(command_id).to_lower().replace("_", "-")
	return "res://assets/ui/icons/netspace/commands/%s.svg" % filename
	
func _target_icon_path(kind: StringName) -> String:
	var filename := "device-object" if kind == &"DEVICE_OBJECT" else (String(kind).to_lower() if kind in [&"NODE", &"ICE", &"SERVICE", &"FILE"] else "unknown")
	return "res://assets/ui/icons/netspace/targets/%s.svg" % filename


func _render_command_dial() -> void:
	if command_dial == null: return
	for child in command_dial.get_children(): child.free()
	if _valid_contextual_commands.is_empty(): return
	var selected_index := _valid_contextual_commands.find(_selected_contextual_command)
	if selected_index < 0: selected_index = 0
	var first := maxi(0, selected_index - 2)
	var last := mini(_valid_contextual_commands.size() - 1, selected_index + 2)
	if selected_index - first < 2: last = mini(_valid_contextual_commands.size() - 1, last + (2 - (selected_index - first)))
	if last - selected_index < 2: first = maxi(0, first - (2 - (last - selected_index)))
	for index in range(first, last + 1):
		var command_id: StringName = _valid_contextual_commands[index]
		var icon := TextureButton.new()
		icon.ignore_texture_size = true
		icon.custom_minimum_size = Vector2(48, 48)
		icon.texture_normal = load(_command_icon_path(command_id)) as Texture2D
		icon.tooltip_text = _contextual_command_label(command_id)
		icon.modulate = Color.WHITE if index == selected_index else Color(0.72, 0.82, 0.88, 0.9)
		var target_scale := Vector2.ONE * (1.0 if index == selected_index else (0.85 if abs(index - selected_index) == 1 else 0.7))
		icon.scale = target_scale * 0.9
		create_tween().tween_property(icon, "scale", target_scale, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		icon.pressed.connect(_on_command_dial_pressed.bind(command_id))
		command_dial.add_child(icon)


func _on_command_dial_pressed(command_id: StringName) -> void:
	var index := _valid_contextual_commands.find(command_id)
	if index < 0: return
	if command_id == _selected_contextual_command:
		_execute_selected_contextual_command()
		return
	_selected_contextual_command = command_id
	selected_command_id = command_id
	_update_contextual_command_hud()


func _update_contextual_command_hud() -> void:
	if contextual_target_label == null or contextual_command_label == null: return
	contextual_target_label.text = target_title.text if not selected_target_id.is_empty() else "NO TARGET"
	if _valid_contextual_commands.is_empty():
		contextual_command_label.text = "NO ACTION"
	else:
		contextual_command_label.text = "< %s >" % _contextual_command_label(_selected_contextual_command)
	_render_command_dial()
	_log_live_hud_state("command_hud_refresh")
	if control_hints != null:
		var command_hint := "Z/.: COMMAND  •  " if not _valid_contextual_commands.is_empty() else ""
		var primary_keyboard := "ENTER: EXECUTE"
		var primary_gamepad := "A: EXECUTE"
		if netspace_focus_mode == NetspaceFocusMode.NODE:
			var current_selected := position_model != null and selected_target_id == position_model.current_node_id
			primary_keyboard = "ENTER: INSPECT NODE" if current_selected else "ENTER: MOVE"
			primary_gamepad = "A: INSPECT NODE" if current_selected else "A: MOVE"
		control_hints.keyboard_text = "%s%s  •  U: CLASS SKILL  •  F: PROGRAM  •  Q/E: SLOT  •  TAB: MANAGE  •  SPACE: RECENTER  •  ESC: BACK" % [command_hint, primary_keyboard]
		var pad_command_hint := "D-PAD L/R: COMMAND  •  " if not _valid_contextual_commands.is_empty() else ""
		control_hints.gamepad_text = "%s%s  •  D-PAD UP: CLASS SKILL  •  RT: PROGRAM  •  LB/RB: SLOT  •  LT: MANAGE  •  R3: RECENTER  •  B: BACK" % [pad_command_hint, primary_gamepad]
		control_hints._refresh()


func _refresh_contextual_command_buttons() -> void:
	var commands := _valid_contextual_commands
	attack_button.visible = &"ATTACK_PROCESS" in commands
	disrupt_button.visible = &"DISRUPT" in commands
	spoof_button.visible = &"SPOOF" in commands
	break_lock_button.visible = &"BREAK_LOCK" in commands
	redirect_button.visible = &"REDIRECT" in commands
	retreat_button.visible = &"RETREAT" in commands
	exploit_button.visible = &"EXPLOIT" in commands
	extract_button.visible = &"TRANSFER" in commands

func _clear_target_panel() -> void:
	confirm_button.visible = true
	selected_target_id = &""
	_valid_contextual_commands.clear()
	_selected_contextual_command = &""
	_context_panel_requested = false
	_refresh_context_panel_visibility()
	target_title.text = "NO TARGET"
	target_details.text = "Q / TAB cycles contacts.\nClick a glyph or route to inspect."
	target_cost.text = "ACTION COST // --"
	program_cost_label.text = "    ACTION COST --"
	confirm_button.disabled = true
	target_scan_button.disabled = true
	_update_contextual_command_hud()
	_refresh_contextual_command_buttons()

func _toggle_current_summary() -> void:
	_current_summary_expanded = not _current_summary_expanded
	left_panel.visible = _current_summary_expanded
	_apply_hud_layout()
	_rebuild_neighborhood()

func _toggle_event_log() -> void:
	_event_log_expanded = not _event_log_expanded
	event_feed.visible = _event_log_expanded
	event_feed_toggle.text = "EVENT LOG  -" if _event_log_expanded else "EVENT LOG  +"

func _on_monitor_presentation_changed(active: bool, expanded: bool) -> void:
	_monitor_full_visible = active and expanded
	HudState.set_suppressed(HudState.Widget.NODE_INSPECTOR, &"EXPANDED_MONITOR", _monitor_full_visible)
	_refresh_context_panel_visibility()

func _refresh_context_panel_visibility() -> void:
	HudState.set_context_active(HudState.Widget.NODE_INSPECTOR, _context_panel_requested)
	if right_panel != null: right_panel.visible = HudState.is_visible(HudState.Widget.NODE_INSPECTOR)

func _on_hud_state_changed(widget_id: int, state: Dictionary) -> void:
	match widget_id:
		HudState.Widget.SPHERE_MINIMAP:
			sphere_minimap.visible = bool(state.visible)
			sphere_minimap.set_collapsed(bool(state.collapsed))
		HudState.Widget.PROGRAM_QUICKBAR: $BottomBar.visible = bool(state.visible)
		HudState.Widget.NODE_INSPECTOR: right_panel.visible = bool(state.visible)
		HudState.Widget.OBJECTIVE: objective_label.visible = bool(state.visible)
		HudState.Widget.TRACE: trace_label.visible = bool(state.visible)
		HudState.Widget.ALERTS: status_label.visible = bool(state.visible)

func _apply_all_hud_states() -> void:
	for widget_id: int in [HudState.Widget.SPHERE_MINIMAP, HudState.Widget.PROGRAM_QUICKBAR, HudState.Widget.NODE_INSPECTOR, HudState.Widget.OBJECTIVE, HudState.Widget.TRACE, HudState.Widget.ALERTS]:
		_on_hud_state_changed(widget_id, HudState.get_state(widget_id))

func _on_minimap_collapsed_changed(collapsed: bool) -> void:
	HudState.set_collapsed(HudState.Widget.SPHERE_MINIMAP, collapsed)
	HudState.notify_widget_interacted(HudState.Widget.SPHERE_MINIMAP)

func _on_hud_widget_open_requested(widget_id: int) -> void:
	match widget_id:
		HudState.Widget.NODE_INSPECTOR:
			if right_panel.visible: target_title.grab_focus()
		HudState.Widget.PROGRAM_QUICKBAR:
			var buttons := $BottomBar/Margin/Rows/Programs.get_children()
			for button: Button in buttons:
				if not button.disabled:
					button.grab_focus()
					break

func _on_hud_action_feedback(message: String) -> void:
	if visible and not message.is_empty():
		status_label.text = message
		_flash_status()

func _on_hud_widget_emphasis_requested(widget_id: int, duration: float) -> void:
	var target: CanvasItem = $BottomBar if widget_id == HudState.Widget.PROGRAM_QUICKBAR else (sphere_minimap if widget_id == HudState.Widget.SPHERE_MINIMAP else null)
	if target == null or not target.visible: return
	if accessibility_config != null and bool(accessibility_config.get("reduced_animation")):
		target.modulate = Color(1.18, 1.18, 0.9, 1.0)
		get_tree().create_timer(minf(duration, 0.25)).timeout.connect(func() -> void: target.modulate = Color.WHITE)
		return
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color(1.3, 1.25, 0.72, 1.0), minf(0.18, duration * 0.3))
	tween.tween_property(target, "modulate", Color.WHITE, maxf(0.12, duration * 0.7))

func _on_diegetic_hud_lesson(actor_id: StringName, lesson_id: StringName, lines: Array) -> void:
	# This follows the same authored Latch channel as the rest of FIRST_CONTACT;
	# the event feed is only the current lightweight transcript presentation.
	for line: Variant in lines:
		event_feed.text += "\n%s // %s" % [String(actor_id).trim_suffix("_REMOTE_ACTOR").replace("_", " "), String(line)]
	if Game.hacker_npc_manager != null:
		var timed_lines: Array[Dictionary] = []
		for index in lines.size(): timed_lines.append({"time": float(index) * 1.8, "speaker_id": actor_id, "text": String(lines[index])})
		Game.hacker_npc_manager.contextual_dialogue_requested.emit(actor_id, lesson_id, timed_lines)

func _on_hud_tutorial_objective_requested(objective_id: StringName, title: String, optional: bool) -> void:
	_tutorial_hud_objective_id = objective_id
	objective_label.text = "%s%s" % ["OPTIONAL // " if optional else "", title]

func _on_hud_tutorial_objective_completed(objective_id: StringName) -> void:
	if objective_id != _tutorial_hud_objective_id: return
	_tutorial_hud_objective_id = &""
	_update_top_bar()

func _apply_hud_layout() -> void:
	if not is_node_ready(): return
	var compact := size.x < 1500.0 or size.y < 850.0
	var side_width := 196.0 if compact else 208.0
	left_panel.offset_right = 12.0 + side_width
	current_panel_toggle.offset_left = 12.0 + side_width - 48.0 if _current_summary_expanded else 12.0
	current_panel_toggle.offset_right = current_panel_toggle.offset_left + 48.0
	current_panel_toggle.text = "-" if _current_summary_expanded else "NODE +"
	var minimap_width := 270.0 if compact else 300.0
	sphere_minimap.offset_left = -12.0 - minimap_width
	sphere_minimap.offset_right = -12.0
	sphere_minimap.custom_minimum_size.x = minimap_width
	# The target inspector is subordinate to the minimap and begins below it.
	right_panel.offset_left = -12.0 - minimap_width
	right_panel.offset_right = -12.0
	right_panel.offset_top = 316.0
	$BottomBar.offset_top = -82.0 if compact else -88.0
	status_label.offset_top = -158.0
	status_label.offset_bottom = status_label.offset_top + 26.0

func get_primary_graph_rect() -> Rect2:
	var left_reserved := left_panel.offset_right + 8.0 if _current_summary_expanded and left_panel.visible else 60.0
	# A narrow right rail keeps the always-discoverable minimap and any active
	# contextual monitor out of the node interaction field.
	var right_reserved := maxf(414.0, maxf(absf(sphere_minimap.offset_left), sphere_minimap.size.x) + 24.0) if sphere_minimap != null else 414.0
	var top := 74.0
	# Includes the status line and minimized realtime monitor strip above the
	# quick-slot bar, preventing large node hitboxes from sitting beneath HUD.
	var bottom_reserved := 164.0
	return Rect2(Vector2(left_reserved, top), Vector2(maxf(1.0, size.x - left_reserved - right_reserved), maxf(1.0, size.y - top - bottom_reserved)))

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

func _on_gameplay_binding(request: RefCounted) -> void:
	if not visible or not Game.session_active: return
	if request.category == GameplayBindingRequestScript.Category.PROGRAM_BINDING:
		var installed: Array[StringName] = Game.program_loadout.installed_instance_ids if Game.program_loadout != null else []
		var instance_id := GameplayBindings.resolve_program_instance(request, installed)
		_activate_program_instance(instance_id, request.slot_index + 1)
		return
	match request.command_id:
		&"JACK_OUT": _jack_out_through_doorstop()
		&"SCAN":
			if selected_target_id == &"": _on_scan_pressed()
			else: _scan_selected_target()
		&"INSPECT":
			status_label.text = "INSPECTING // %s" % (target_title.text if not selected_target_id.is_empty() else current_name.text)
		&"CONFIRM_SELECTION": _confirm_selected_target()
		&"ATTACK": _submit_selected_confrontation(ActionRequest.ActionType.ATTACK_PROCESS)
		&"EVADE": _submit_selected_confrontation(ActionRequest.ActionType.RETREAT)
		&"TARGET_PREVIOUS": _cycle_target(-1)
		&"TARGET_NEXT": _cycle_target(1)
		&"CANCEL_SELECTION": _clear_target_panel()
		&"INTERCEPT": status_label.text = "INTERCEPT // SELECT A DISCOVERED COMMS SIGNAL"

func _on_bindings_changed(_input_action: StringName) -> void:
	_update_binding_labels()
	_update_program_bar()

func _update_binding_labels() -> void:
	if local_scan_button == null: return
	var action: StringName = GameplayBindings.profile.input_action_for(GameplayBindingRequestScript.Category.CYBERSPACE_COMMAND, &"SCAN")
	local_scan_button.text = "SCAN LOCAL [%s]" % GameplayBindings.get_binding_label(action)

func _on_program_selected(slot: int) -> void:
	if Game.program_loadout == null: return
	_selected_active_slot = clampi(slot - 1, 0, maxi(0, Game.program_loadout.capacity - 1))
	_update_program_bar()

func _activate_program_instance(instance_id: StringName, slot: int) -> void:
	var instance := Game.program_inventory.get_instance(instance_id) if Game.program_inventory != null else null
	if instance == null or Game.program_loadout == null or not Game.program_loadout.is_installed(instance_id):
		status_label.text = "PROGRAM BINDING %d // NO INSTALLED PROGRAM" % slot
		_flash_status()
		return
	if instance.definition is DoorstopDefinition:
		_pending_doorstop_instance_id = instance_id
		_request_doorstop_confirmation()
		return
	status_label.text = "PROGRAM BINDING %d // %s READY" % [slot, instance.definition.display_name.to_upper()]


func _request_doorstop_confirmation() -> void:
	var installed := Game.installed_doorstop_instance_ids()
	if installed.is_empty():
		status_label.text = "DOORSTOP UNAVAILABLE // NO INSTALLED COPY"
		Game.notify_doorstop_invalid("No Doorstop copy is installed in the active deck.")
		_flash_status()
		return
	if _pending_doorstop_instance_id.is_empty() or _pending_doorstop_instance_id not in installed:
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
	var programs := $BottomBar/Margin/Rows/Programs
	var count := Game.program_loadout.capacity if Game.program_loadout != null else 0
	while programs.get_child_count() > count:
		programs.get_child(programs.get_child_count() - 1).free()
	while programs.get_child_count() < count:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		programs.add_child(button)
		button.pressed.connect(_on_program_selected.bind(programs.get_child_count()))
	var slots: Array = Game.program_loadout.active_slots if Game.program_loadout != null else []
	for index in count:
		var button := programs.get_child(index) as Button
		var instance_id: StringName = slots[index] if index < slots.size() else &""
		var instance := Game.program_inventory.get_instance(instance_id) if not instance_id.is_empty() and Game.program_inventory != null else null
		var binding_id := StringName("PROGRAM_SLOT_%d" % (index + 1))
		var action := StringName(GameplayBindings.profile.program_bindings.get(binding_id, &""))
		var marker := ">" if index == _selected_active_slot else " "
		button.text = "%s [%s] %s" % [marker, GameplayBindings.get_binding_label(action), instance.definition.display_name.to_upper() if instance != null else "EMPTY"]
		button.tooltip_text = "%s // binding: PROGRAM_SLOT_%d" % [instance.definition.description if instance != null else "No program installed in this loadout position.", index + 1]
		button.disabled = false
		button.icon = instance.definition.get("icon") as Texture2D if instance != null and instance.definition.get("icon") is Texture2D else null
	_selected_active_slot = clampi(_selected_active_slot, 0, maxi(0, count - 1)) if count > 0 else 0
	_log_live_hud_state("program_bar_refresh")
	var anchor := Game.doorstop_controller.get_anchor(Game.intrusion_run_id) if Game.doorstop_controller != null else null
	jack_out_button.disabled = anchor == null or not anchor.active
	if anchor != null and anchor.active:
		var node := Game.network_graph.get_node(anchor.cyberspace_node_id)
		doorstop_state_label.text = "BACKDOOR ACTIVE // %s // ONE RETURN" % (node.display_name.to_upper() if node != null else anchor.cyberspace_node_id)
	else:
		doorstop_state_label.text = "BACKDOOR // CLOSED"


func _create_debug_hud() -> void:
	# Step 2-3: Create a temporary debug HUD as a CanvasLayer to prove screen-space rendering
	if not OS.is_debug_build():
		return
	
	var debug_layer = CanvasLayer.new()
	debug_layer.name = "DebugNetspaceHUD"
	debug_layer.layer = 100
	add_child(debug_layer)
	
	var root_control = Control.new()
	root_control.name = "Root"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.anchor_left = 0.0
	root_control.anchor_right = 1.0
	root_control.anchor_top = 0.0
	root_control.anchor_bottom = 1.0
	root_control.offset_left = 0
	root_control.offset_right = 0
	root_control.offset_top = 0
	root_control.offset_bottom = 0
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_layer.add_child(root_control)
	
	# Test label at bottom center - STEP 3
	var test_label = Label.new()
	test_label.name = "TestLabel"
	test_label.text = "NETSPACE HUD TEST"
	test_label.add_theme_font_size_override("font_size", 32)
	test_label.add_theme_color_override("font_color", Color.YELLOW)
	test_label.set_anchors_preset(Control.PRESET_BOTTOM_CENTER)
	test_label.anchor_left = 0.5
	test_label.anchor_right = 0.5
	test_label.anchor_top = 1.0
	test_label.anchor_bottom = 1.0
	test_label.offset_left = -200
	test_label.offset_right = 200
	test_label.offset_top = -100
	test_label.offset_bottom = -50
	root_control.add_child(test_label)
	
	print("[DebugHUD] Created temporary debug HUD layer. Test label should be visible at bottom of screen.")


func _create_slot_management_ui() -> void:
	_slot_management_panel = PanelContainer.new()
	_slot_management_panel.name = "ActiveSlotManagement"
	_slot_management_panel.visible = false
	_slot_management_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_slot_management_panel.position = Vector2(-360, -220)
	_slot_management_panel.size = Vector2(330, 420)
	add_child(_slot_management_panel)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 16); margin.add_theme_constant_override("margin_top", 14); margin.add_theme_constant_override("margin_right", 16); margin.add_theme_constant_override("margin_bottom", 14)
	_slot_management_panel.add_child(margin)
	var content := VBoxContainer.new(); content.add_theme_constant_override("separation", 8); margin.add_child(content)
	_slot_management_title = Label.new(); content.add_child(_slot_management_title)
	_slot_management_options = VBoxContainer.new(); content.add_child(_slot_management_options)
	var close := Button.new(); close.text = "CANCEL"; close.pressed.connect(_close_slot_management); content.add_child(close)
	_slot_management_confirmation = ConfirmationDialog.new(); _slot_management_confirmation.title = "DUMP PROGRAM"; _slot_management_confirmation.confirmed.connect(_confirm_dump_selected_slot); add_child(_slot_management_confirmation)


func open_selected_slot_management() -> void:
	if Game.program_loadout == null: return
	_slot_management_panel.visible = true
	_refresh_slot_management()


func _close_slot_management() -> void:
	if _slot_management_panel != null: _slot_management_panel.visible = false


func _refresh_slot_management() -> void:
	if _slot_management_options == null: return
	for child in _slot_management_options.get_children(): child.queue_free()
	var slot_id := Game.program_loadout.instance_at(_selected_active_slot) if Game.program_loadout != null else &""
	var instance := Game.program_inventory.get_instance(slot_id) if not slot_id.is_empty() and Game.program_inventory != null else null
	_slot_management_title.text = "ACTIVE SLOT %02d // %s" % [_selected_active_slot + 1, instance.definition.display_name.to_upper() if instance != null else "EMPTY"]
	if instance != null:
		var move := Button.new(); move.text = "MOVE TO STORAGE"; move.pressed.connect(_move_selected_to_storage); move.disabled = Game.program_inventory == null or not Game.program_inventory.can_store(Game.program_loadout); _slot_management_options.add_child(move)
		var dump := Button.new(); dump.text = "DUMP PROGRAM"; dump.pressed.connect(_request_dump_selected_slot); _slot_management_options.add_child(dump)
	if instance == null:
		var storage_label := Label.new(); storage_label.text = "LOAD FROM STORAGE"; _slot_management_options.add_child(storage_label)
	if instance == null and Game.program_inventory != null:
		for stored: ProgramInstance in Game.program_inventory.all_instances():
			if Game.program_loadout.is_installed(stored.instance_id): continue
			var load := Button.new(); load.text = stored.definition.display_name.to_upper(); load.pressed.connect(_load_into_selected_slot.bind(stored.instance_id)); _slot_management_options.add_child(load)


func _load_into_selected_slot(instance_id: StringName) -> void:
	if Game.program_loadout.install_at(_selected_active_slot, instance_id, Game.program_inventory):
		status_label.text = "PROGRAM LOADED"
		_update_program_bar(); _refresh_slot_management()


func _move_selected_to_storage() -> void:
	if Game.program_inventory == null or not Game.program_inventory.can_store(Game.program_loadout):
		status_label.text = "STORAGE FULL"; return
	if not Game.program_loadout.instance_at(_selected_active_slot).is_empty():
		Game.program_loadout.uninstall_at(_selected_active_slot)
		status_label.text = "PROGRAM STORED"
		_update_program_bar(); _refresh_slot_management()


func _request_dump_selected_slot() -> void:
	var instance_id := Game.program_loadout.instance_at(_selected_active_slot) if Game.program_loadout != null else &""
	var instance := Game.program_inventory.get_instance(instance_id) if Game.program_inventory != null else null
	if instance == null: return
	_slot_management_confirmation.dialog_text = "DUMP %s?" % instance.definition.display_name.to_upper()
	_slot_management_confirmation.popup_centered()


func _confirm_dump_selected_slot() -> void:
	var instance_id := Game.program_loadout.uninstall_at(_selected_active_slot) if Game.program_loadout != null else &""
	if not instance_id.is_empty() and Game.program_inventory != null: Game.program_inventory.remove_instance(instance_id)
	status_label.text = "PROGRAM DUMPED"
	_update_program_bar(); _refresh_slot_management()


func _jack_out_through_doorstop() -> void:
	var result: Dictionary = Game.jack_out_through_doorstop()
	if not result.success:
		status_label.text = "JACK OUT DENIED // %s" % String(result.reason).to_upper()
		Game.notify_doorstop_invalid(result.reason)
		_flash_status()


func _on_game_domain_changed(_previous_domain: int, current_domain: int) -> void:
	visible = current_domain == Game.GameDomain.CYBERSPACE
	if visible: GameplayBindings.set_context(GameplayBindings.Context.CYBERSPACE)

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
