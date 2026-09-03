extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var graph := _graph()
	var trails := HackerTrailSystem.new(); trails.default_decay_per_tick = 0.0
	for edge: Array in [[&"A", &"B"], [&"B", &"C"], [&"C", &"D"]]: trails.leave_trail(&"PLAYER", &"RUN", edge[0], edge[1], 0, 0.65)
	var player := PlayerNetworkPosition.new(&"D")
	var controller := IceController.new(graph, player, PlayerKnowledge.new())
	controller.configure_trails(trails, &"RUN", &"PLAYER")
	var basic_definition := IceDefinition.new(&"BASIC", "Basic Tracker", 0, 1, 0)
	basic_definition.trail_tracking.enabled = true; basic_definition.trail_tracking.tracking_quality = 0.6; basic_definition.trail_tracking.detection_threshold = 0.5
	var basic := IceInstance.new(&"BASIC_01", basic_definition, &"A", IceState.Value.SEARCH)
	controller.add_ice(basic)
	controller.update(1, ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT))
	_expect(basic.current_node_id == &"A" and basic.followed_trail_segment_id.is_empty(), "basic ICE cannot acquire a trail below its configured threshold")

	var advanced_definition := IceDefinition.new(&"ADVANCED", "Advanced Tracker", 0, 1, 0)
	advanced_definition.trail_tracking.enabled = true; advanced_definition.trail_tracking.tracking_quality = 1.0
	advanced_definition.trail_tracking.detection_threshold = 0.5; advanced_definition.trail_tracking.max_age = 20; advanced_definition.trail_tracking.memory_ticks = 1
	var advanced := IceInstance.new(&"ADVANCED_01", advanced_definition, &"A", IceState.Value.SEARCH)
	controller.add_ice(advanced)
	var events: Array[Dictionary] = []
	for _step in 3: events.append_array(controller.update(1, ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT)))
	_expect(advanced.current_node_id == &"D" and advanced.state == IceState.Value.ENGAGE, "advanced ICE follows a multi-node trail until it finds the hacker")
	_expect(events.any(func(event): return event.type == &"HACKER_TRAIL_ACQUIRED"), "trail acquisition enters the ordinary ICE event flow")

	var stale_controller := IceController.new(graph, player, PlayerKnowledge.new()); stale_controller.configure_trails(trails, &"RUN", &"PLAYER"); stale_controller.simulation_tick = 10
	var stale_definition := IceDefinition.new(&"STALE", "Short Memory", 0, 1, 0); stale_definition.trail_tracking.enabled = true; stale_definition.trail_tracking.max_age = 3
	var stale := IceInstance.new(&"STALE_01", stale_definition, &"A", IceState.Value.SEARCH); stale_controller.add_ice(stale)
	stale_controller.update(1, ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT))
	_expect(stale.current_node_id == &"A", "max age prevents low-tier ICE from following old evidence")

	var authored := AuthoredIceFactory.create_definition({"id": &"FORENSIC", "trail_tracking": {"enabled": true, "detection_threshold": 0.2, "max_age": 40, "tracking_quality": 2.0, "memory_ticks": 6}})
	_expect(authored.trail_tracking.enabled and authored.trail_tracking.max_age == 40 and authored.trail_tracking.tracking_quality == 2.0, "authored ICE data configures distinct tracking tiers")

	var memory_controller := IceController.new(graph, player, PlayerKnowledge.new()); memory_controller.configure_trails(HackerTrailSystem.new(), &"RUN", &"PLAYER")
	var memory := IceInstance.new(&"MEMORY", advanced_definition, &"A", IceState.Value.SEARCH)
	memory.followed_trail_segment_id = &"MISSING"; memory.trail_memory_remaining = 1; memory_controller.add_ice(memory)
	var lost_events := memory_controller.update(1, ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT))
	_expect(memory.followed_trail_segment_id.is_empty() and lost_events.any(func(event): return event.type == &"HACKER_TRAIL_LOST" and event.ice_id == memory.instance_id), "ICE forgets a trail after its configured memory expires")
	var sans := SystemAccessNodeManager.new(); sans.create_san(&"PLAYER", &"RUN", &"DECK", &"A")
	var san_controller := IceController.new(graph, player, PlayerKnowledge.new()); san_controller.configure_trails(trails, &"RUN", &"PLAYER", sans)
	var san_hunter := IceInstance.new(&"SAN_HUNTER", advanced_definition, &"A", IceState.Value.SEARCH); san_controller.add_ice(san_hunter)
	var san_events := san_controller.update(1, ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT))
	_expect(san_hunter.state == IceState.Value.ENGAGE and san_events.any(func(event): return event.type == &"SAN_FOUND"), "trail-capable ICE stops pursuit when it finds the hacker's hosted SAN")

	print("%s: %d ICE trail tracking assertions" % ["PASS" if failures == 0 else "FAIL", assertions]); quit(failures)

func _graph() -> NetworkGraph:
	var graph := NetworkGraph.new()
	for id: StringName in [&"A", &"B", &"C", &"D"]: graph.add_node(NetworkNodeDefinition.new(id, String(id), NetworkNodeDefinition.NodeType.ROUTER))
	graph.add_link(NetworkLinkDefinition.new(&"AB", &"A", &"B")); graph.add_link(NetworkLinkDefinition.new(&"BC", &"B", &"C")); graph.add_link(NetworkLinkDefinition.new(&"CD", &"C", &"D"))
	return graph

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
