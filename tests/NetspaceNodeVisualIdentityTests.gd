extends Node

const DISPLAY := preload("res://cyberspace/display/NetworkDisplay.tscn")
var failures := 0
var assertions := 0

func _ready() -> void:
	var graph := NetworkGraph.new()
	for definition: NetworkNodeDefinition in [
		NetworkNodeDefinition.new(&"ENTRY", "Entry", NetworkNodeDefinition.NodeType.GATEWAY),
		NetworkNodeDefinition.new(&"FILE_CACHE", "File Cache", NetworkNodeDefinition.NodeType.FILE_SERVER),
		NetworkNodeDefinition.new(&"NEXT_NODE", "Next Node", NetworkNodeDefinition.NodeType.ROUTER),
	]: _expect(graph.add_node(definition), "logical node is authored once")
	var entry_cache := NetworkLinkDefinition.new(&"ENTRY_CACHE", &"ENTRY", &"FILE_CACHE")
	var cache_next := NetworkLinkDefinition.new(&"CACHE_NEXT", &"FILE_CACHE", &"NEXT_NODE")
	_expect(graph.add_link(entry_cache) and graph.add_link(cache_next), "one logical edge is authored per connection")
	var position := PlayerNetworkPosition.new(&"ENTRY", 10)
	var knowledge := PlayerKnowledge.new()
	knowledge.mark_node_visited(graph.get_node(&"ENTRY"))
	knowledge.detect_link(entry_cache)
	var display := DISPLAY.instantiate() as NetworkDisplay
	add_child(display); display.set_anchors_preset(Control.PRESET_TOP_LEFT); display.size = Vector2(1280, 720)
	display.set_models(graph, position, knowledge)
	await get_tree().process_frame
	var unknown_counts := display.debug_node_visual_identity(&"FILE_CACHE")
	_expect(unknown_counts.logical_instances == 1 and unknown_counts.anchor_instances == 1 and unknown_counts.visual_instances == 1, "unknown File Cache has one logical node, anchor, and visual")
	var stable_visual_id := (display.node_visuals[&"FILE_CACHE"] as NodeVisual).get_instance_id()

	knowledge.reveal_link(entry_cache, KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_node(graph.get_node(&"FILE_CACHE"), KnowledgeLevel.Value.IDENTIFIED)
	display._rebuild_neighborhood()
	_expect(display.debug_node_visual_identity(&"FILE_CACHE").visual_instances == 1 and (display.node_visuals[&"FILE_CACHE"] as NodeVisual).get_instance_id() == stable_visual_id, "unknown-to-known promotion updates the same File Cache visual")

	_expect(graph.traverse(position, &"FILE_CACHE").error == NetworkGraph.TraversalError.OK, "test traverses into File Cache")
	knowledge.observe_traversal(graph, &"ENTRY", &"FILE_CACHE")
	knowledge.detect_link(cache_next)
	display._rebuild_neighborhood()
	_expect(display.debug_node_visual_identity(&"FILE_CACHE").visual_instances == 1 and (display.node_visuals[&"FILE_CACHE"] as NodeVisual).get_instance_id() == stable_visual_id, "traversal keeps one persistent File Cache visual")
	_expect(display.link_visuals.size() == display.link_layer.get_child_count(), "one rendered connection exists for each keyed visible edge")

	display.focused_node_id = &"FILE_CACHE"
	var fixed_graph_positions := display.spatial_world.final_world_positions()
	var network_scale := (display.node_visuals[&"FILE_CACHE"] as NodeVisual).scale.x
	_expect(display._enter_node_focus_mode(), "current File Cache enters node focus mode")
	await get_tree().create_timer(NetworkDisplay.NODE_FOCUS_TRANSITION_DURATION + 0.05).timeout
	_expect(display.debug_node_visual_identity(&"FILE_CACHE").visual_instances == 1, "node focus creates no second world node")
	_expect((display.node_visuals[&"FILE_CACHE"] as NodeVisual).scale.x > network_scale * 1.4, "the same current-node visual enlarges as the focus anchor")
	_expect(display.local_target_visuals.is_empty() and display.node_layer.visible, "an empty node focus retains the same host visual without representing it as local content")
	display._exit_node_focus_mode()
	await get_tree().create_timer(NetworkDisplay.NODE_FOCUS_TRANSITION_DURATION + 0.05).timeout
	display._update_spatial_projection()
	_expect(display.debug_node_visual_identity(&"FILE_CACHE").visual_instances == 1, "exiting local mode and panning preserve one visual")
	_expect(display.spatial_world.final_world_positions() == fixed_graph_positions, "focus transitions never alter fixed graph world positions")
	display.set_models(graph, position, knowledge)
	_expect(display.debug_node_visual_identity(&"FILE_CACHE").visual_instances == 1, "leaving and returning reconciles to one visual")
	display.queue_free(); await get_tree().process_frame
	print("%s: %d Netspace node identity assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
