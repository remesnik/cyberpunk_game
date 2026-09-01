extends CanvasLayer

@onready var tick_label: Label = %TickLabel
@onready var realtime_label: Label = %RealtimeLabel
@onready var pause_policy_label: Label = %PausePolicyLabel
@onready var action_label: Label = %ActionLabel
@onready var cost_label: Label = %CostLabel
@onready var events_label: Label = %EventsLabel
@onready var ice_label: Label = %IceLabel
@onready var world_knowledge_label: Label = %WorldKnowledgeLabel
@onready var realtime_processes_label: Label = %RealtimeProcessesLabel
@onready var dual_pressure_label: Label = %DualPressureLabel
@onready var cyber_timeline_label: Label = %CyberTimelineLabel
@onready var meatspace_timeline_label: Label = %MeatspaceTimelineLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = Debug.overlay_visible
	EventBus.debug_visibility_changed.connect(_on_visibility_changed)
	EventBus.action_resolved.connect(_on_action_resolved)
	EventBus.session_started.connect(_update_ice_debug)
	EventBus.session_started.connect(_update_world_debug)
	if Game.action_clock != null:
		tick_label.text = "CYBER TICK: %03d" % Game.action_clock.current_tick
	_update_realtime_readout()


func _process(_delta: float) -> void:
	_update_realtime_readout()
	_update_realtime_processes()
	_update_dual_pressure()
	_update_scenario_timeline()


func _on_visibility_changed(is_visible: bool) -> void:
	visible = is_visible

func _on_action_resolved(request: ActionRequest, result: ActionResult) -> void:
	tick_label.text = "CYBER TICK: %03d" % Game.action_clock.current_tick
	action_label.text = "LAST ACTION  %s  [%s]" % [request.get_action_name(), "OK" if result.success else "DENIED"]
	cost_label.text = "ACTION COST  %d  //  TIME SPENT  %d" % [request.cost, result.time_spent]
	var event_names: PackedStringArray = []
	for event in result.events_produced:
		event_names.append(String(event.get("type", &"UNKNOWN")))
	events_label.text = "EVENTS (%d)\n%s" % [event_names.size(), "  > ".join(event_names)]
	_update_ice_debug()
	_update_world_debug()


func _update_realtime_readout() -> void:
	pause_policy_label.text = "PAUSE POLICY: %s  // CYBER %s  // REALTIME %s  // AUDIO %s" % [PausePolicy.mode_label(), "ACTIVE" if PausePolicy.allows_cyberspace_actions() else "FROZEN", "ACTIVE" if PausePolicy.allows_realtime_advance() else "FROZEN", "PAUSED" if PausePolicy.should_pause_audio() else "ACTIVE"]
	if Game.realtime_world_clock == null:
		realtime_label.text = "REALTIME SESSION: 00:00.00"
		return
	realtime_label.text = "REALTIME SESSION: %s" % Game.realtime_world_clock.formatted_session_time()


func _update_realtime_processes() -> void:
	if Game.realtime_process_manager == null:
		realtime_processes_label.text = "MEATSPACE PROCESSES\n--"
		return
	var lines: PackedStringArray = ["MEATSPACE PROCESSES // REALTIME"]
	var ids: Array = Game.realtime_process_manager.processes.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for process_id: StringName in ids:
		if Game.player_knowledge == null or not Game.player_knowledge.knows_realtime_process(process_id):
			continue
		var process: RealtimeProcess = Game.realtime_process_manager.get_process(process_id)
		lines.append("%-20s %8.2fs  %s" % [process.id, process.elapsed_time, process.state_label()])
	if lines.size() == 1:
		lines.append("No meatspace interfaces discovered.")
	realtime_processes_label.text = "\n".join(lines)


func _update_dual_pressure() -> void:
	if Game.operation_pressure_manager == null or Game.realtime_world_clock == null:
		dual_pressure_label.text = "DUAL PRESSURE // --"
		return
	var operation: Variant = Game.operation_pressure_manager.get_operation(&"SUPPORT_TEAM_ALPHA")
	if operation == null:
		dual_pressure_label.text = "DUAL PRESSURE // --"
		return
	var cyber_tick := Game.action_clock.current_tick if Game.action_clock != null else 0
	dual_pressure_label.text = "DUAL PRESSURE // INDEPENDENT CLOCKS\nCYBER  TICK %03d  // PLAN %d/%d  // %d COST REMAINS\nNEXT   %s\nREAL   %s IN %05.2fs  [%s]\nSECONDS ARE NEVER CONVERTED TO CYBER TICKS" % [cyber_tick, operation.completed_cyber_steps, operation.definition.cyber_plan.size(), operation.remaining_cyber_cost(), operation.current_step_label(), operation.definition.realtime_threat_label, operation.realtime_seconds_remaining(Game.realtime_world_clock.elapsed_seconds), operation.state_label()]


func _update_scenario_timeline() -> void:
	if Game.facility_scenario == null:
		cyber_timeline_label.text = "CYBERSPACE EVENTS\n--"
		meatspace_timeline_label.text = "MEATSPACE EVENTS\n--"
		return
	var cyber_lines: PackedStringArray = ["CYBERSPACE EVENTS"]
	for event: Dictionary in Game.facility_scenario.cyberspace_events.slice(-6):
		cyber_lines.append("T%03d  %-18s %s" % [int(event.get("tick", 0)), String(event.get("type", &"EVENT")).trim_prefix("CYBER_"), "OK" if event.get("success", false) else "DENIED"])
	var meat_lines: PackedStringArray = ["MEATSPACE EVENTS"]
	for event: Dictionary in Game.facility_scenario.meatspace_events.slice(-6):
		meat_lines.append("%05.1fs  %s" % [float(event.get("realtime", 0.0)), String(event.get("type", &"EVENT")).replace("_", " ")])
	cyber_timeline_label.text = "\n".join(cyber_lines)
	meatspace_timeline_label.text = "\n".join(meat_lines)

func _update_ice_debug() -> void:
	if Game.ice_controller == null or Game.player_knowledge == null:
		return
	var lines: PackedStringArray = ["ICE TRUTH  |  PLAYER KNOWLEDGE"]
	var ids: Array = Game.ice_controller.instances.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for instance_id in ids:
		var ice := Game.ice_controller.get_ice(instance_id)
		var record: Dictionary = Game.player_knowledge.ice_records.get(instance_id, {})
		var known_position: StringName = record.get("node_id", &"UNKNOWN")
		var known_state_value: Variant = record.get("state", null)
		var known_state := "UNKNOWN" if known_state_value == null else IceState.label(known_state_value)
		lines.append("%s: %s / %s  |  %s / %s" % [instance_id, ice.current_node_id, IceState.label(ice.state), known_position, known_state])
	ice_label.text = "\n".join(lines)

func _update_world_debug() -> void:
	if Game.network_graph == null or Game.player_knowledge == null:
		return
	var lines: PackedStringArray = ["TRUE WORLD  |  PLAYER KNOWLEDGE"]
	var node_ids: Array = Game.network_graph.nodes.keys()
	node_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for node_id in node_ids:
		var node := Game.network_graph.get_node(node_id)
		var level := Game.player_knowledge.get_node_level(node_id)
		var player_name := String(Game.player_knowledge.get_node_view(node_id).get("display_name", "--"))
		lines.append("NODE %-18s | %-11s %s" % [node.display_name, KnowledgeLevel.label(level), player_name])
	var link_ids: Array = Game.network_graph.links.keys()
	link_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for link_id in link_ids:
		var link := Game.network_graph.get_link(link_id)
		lines.append("LINK %s>%s | %s" % [link.source, link.destination, KnowledgeLevel.label(Game.player_knowledge.get_link_level(link_id))])
	world_knowledge_label.text = "\n".join(lines)
