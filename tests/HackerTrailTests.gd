extends Node

var failures := 0
var assertions := 0
@onready var game: Node = get_node("/root/Game")

func _ready() -> void:
	_test_creation_decay_and_detection()
	_test_follow_multi_node_path()
	_test_runtime_movement_hooks()
	print("%s: %d hacker trail assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_creation_decay_and_detection() -> void:
	var trails := HackerTrailSystem.new()
	var segment := trails.leave_trail(&"HACKER_A", &"RUN_1", &"ENTRY", &"RELAY", 4, 1.0)
	_expect(segment != null and trails.segments.size() == 1, "traversal creates one trail segment")
	_expect(segment.owner_actor_id == &"HACKER_A" and segment.intrusion_id == &"RUN_1" and segment.from_node_id == &"ENTRY" and segment.to_node_id == &"RELAY" and segment.created_tick == 4, "trail preserves ownership, intrusion, route, and creation tick")
	trails.decay_trails(7)
	_expect(is_equal_approx(segment.strength, 0.7), "trail strength fades by elapsed cyberspace ticks")
	_expect(trails.detect_trails(1.0, &"ENTRY", &"RUN_1", &"TRACKER").has(segment), "sufficient generic tracking capability detects a fading trail")
	_expect(trails.detect_trails(0.5, &"ENTRY", &"RUN_1", &"TRACKER").is_empty(), "detection threshold rejects insufficient tracking capability")
	var graph := NetworkGraph.new(); graph.add_node(NetworkNodeDefinition.new(&"ENTRY", "Entry", NetworkNodeDefinition.NodeType.GATEWAY)); graph.add_node(NetworkNodeDefinition.new(&"RELAY", "Relay", NetworkNodeDefinition.NodeType.ROUTER)); graph.add_link(NetworkLinkDefinition.new(&"EDGE", &"ENTRY", &"RELAY"))
	var ice_controller := IceController.new(graph, PlayerNetworkPosition.new(&"RELAY"), PlayerKnowledge.new())
	var ice := IceInstance.new(&"TRACKER_ICE", IceDefinition.new(&"TRACKER", "Tracker", 1), &"ENTRY")
	ice_controller.add_ice(ice); ice_controller.configure_trails(trails, &"RUN_1")
	_expect(ice_controller.detect_trails(ice.instance_id).has(segment), "ICE detection uses its data-driven tracking capability")
	_expect(trails.detect_trails(1.0, &"ENTRY", &"RUN_1", &"HACKER_A").is_empty(), "own trails are omitted by default")
	_expect(trails.detect_trails(1.0, &"ENTRY", &"RUN_1", &"HACKER_A", true).has(segment), "callers may explicitly inspect their own trail data")
	trails.decay_trails(20)
	_expect(not segment.active and trails.detect_trails(10.0).is_empty(), "fully decayed trails are no longer detectable")

func _test_follow_multi_node_path() -> void:
	var trails := HackerTrailSystem.new(); trails.default_decay_per_tick = 0.0
	trails.leave_trail(&"HACKER_B", &"RUN_PATH", &"A", &"B", 1)
	trails.leave_trail(&"HACKER_B", &"RUN_PATH", &"B", &"C", 2)
	trails.leave_trail(&"HACKER_B", &"RUN_PATH", &"C", &"D", 3)
	var followed := trails.follow_trail(&"A", 1.0, &"RUN_PATH", &"ICE_TRACKER")
	_expect(followed.success and followed.node_path == [&"A", &"B", &"C", &"D"], "tracker follows a directed multi-node trail")
	_expect(followed.segments.size() == 3 and followed.last_node_id == &"D", "follow result exposes each segment and final host")
	var spoof := trails.leave_trail(&"HACKER_B", &"RUN_PATH", &"D", &"FALSE_EXIT", 4, 1.0, {"false_trail": true, "apparent_owner_actor_id": &"HACKER_C", "concealment": 0.2})
	_expect(spoof.false_trail and spoof.apparent_owner_actor_id == &"HACKER_C", "trail data can represent future spoofed ownership and concealment")
	_expect(trails.erase_trail(spoof.id) and not spoof.active, "generic erase API removes a specific trail")

func _test_runtime_movement_hooks() -> void:
	game.start_session()
	var origin: StringName = game.player_network_position.current_node_id
	var destination: StringName = game.network_graph.get_visible_connected_nodes(origin)[0]
	var movement: ActionResult = game.request_traversal(destination)
	var player_segments: Array[TrailSegment] = game.hacker_trail_system.detect_trails(1.0, origin, game.intrusion_run_id, &"ICE_TRACKER")
	_expect(movement.success and player_segments.size() == 1 and player_segments[0].owner_actor_id == game.active_player_id, "production player traversal leaves an intrusion trail")

	var definition := HackerNPCDefinition.new(&"REMOTE", "Remote", "Remote")
	var remote := HackerNPC.new(&"REMOTE_01", definition, destination)
	game.hacker_npc_manager.add_actor(remote); game.hacker_npc_manager.appear(remote.instance_id, destination)
	_expect(game.hacker_npc_manager.detect_trails(remote.instance_id, 1.0).any(func(segment): return segment.owner_actor_id == game.active_player_id), "another hacker can detect the player's trail through the generic capability API")
	var remote_destination: StringName = game.network_graph.get_visible_connected_nodes(destination).filter(func(id): return id != origin)[0]
	var remote_move: Dictionary = game.hacker_npc_manager.move_scripted(remote.instance_id, remote_destination)
	var remote_segments: Array[TrailSegment] = game.hacker_trail_system.detect_trails(1.0, destination, game.intrusion_run_id, &"ICE_TRACKER")
	_expect(remote_move.success and remote_segments.any(func(segment): return segment.owner_actor_id == remote.instance_id), "scripted remote-hacker traversal uses the same trail service")
	game.end_session()

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
