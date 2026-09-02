extends SceneTree

var failures := 0
var assertions := 0


func _init() -> void:
	var graph := NetworkGraph.new()
	for id: StringName in [&"ENTRY", &"RELAY", &"ROUTER"]:
		graph.add_node(NetworkNodeDefinition.new(id, String(id).capitalize(), NetworkNodeDefinition.NodeType.ROUTER, 1, true))
	graph.add_link(NetworkLinkDefinition.new(&"ENTRY_RELAY", &"ENTRY", &"RELAY"))
	graph.add_link(NetworkLinkDefinition.new(&"RELAY_ROUTER", &"RELAY", &"ROUTER"))
	var player := PlayerNetworkPosition.new(&"ENTRY", 10)
	var knowledge := PlayerKnowledge.new()
	for id: StringName in [&"ENTRY", &"RELAY"]: knowledge.reveal_node(graph.get_node(id), KnowledgeLevel.Value.IDENTIFIED)
	var manager := HackerNPCManager.new()
	manager.configure(graph, player, knowledge)
	var definition := HackerNPCDefinition.new(&"LATCH", "Latch", "LATCH")
	definition.player_relationship = &"ALLY"
	definition.comms_channel_id = &"LATCH_BACKCHANNEL"
	definition.scripted_reactions = [{"id": &"SCAN_REACTION", "action_type": &"SCAN", "target_id": &"RELAY", "success": true, "commands": [{"type": &"COMMUNICATE", "session_id": &"LATCH_SCAN_RELAY"}, {"type": &"STORY_EVENT", "event_type": &"LATCH_REACTED_TO_SCAN"}]}, {"id": &"LOW_TRACE", "event_type": &"TRACE_UPDATED", "minimum_trace": 5, "lines": [{"time": 0.0, "text": "Low priority."}], "priority": 1, "once": true}, {"id": &"WARM_TRACE", "event_type": &"TRACE_UPDATED", "minimum_trace": 10, "lines": [{"time": 0.0, "text": "Trace is getting warm."}], "priority": 10, "once": true}]
	var latch := HackerNPC.new(&"LATCH_01", definition, &"RELAY")
	_expect(manager.add_actor(latch), "generic remote hacker actor is registered")
	_expect(manager.appear(latch.instance_id, &"RELAY").success, "Latch can appear at a valid graph node")
	_expect(knowledge.get_visible_hackers_at([&"ENTRY", &"RELAY"]).size() == 1, "known local view receives Latch's visible process projection")
	_expect(manager.move_scripted(latch.instance_id, &"ROUTER").success and latch.current_node_id == &"ROUTER", "story scripting moves Latch over a graph link without ICE AI")
	_expect(knowledge.get_visible_hackers_at([&"ENTRY", &"RELAY"]).is_empty(), "Latch disappears from the local view when outside known locality")
	knowledge.reveal_node(graph.get_node(&"ROUTER"), KnowledgeLevel.Value.IDENTIFIED)
	graph.apply_traversal(player, &"RELAY")
	_expect(knowledge.get_visible_hackers_at([&"RELAY", &"ROUTER"]).size() == 1, "player movement refreshes local hacker visibility")
	var communication_ids: Array[StringName] = []
	manager.communication_requested.connect(func(_actor_id, session_id): communication_ids.append(session_id))
	manager.handle_player_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.SCAN, {"node_id": &"RELAY"}), ActionResult.new(true, 1))
	_expect(communication_ids.has(&"LATCH_SCAN_RELAY"), "data-driven reaction requests realtime comms")
	_expect(manager.event_history.any(func(event): return event.type == &"LATCH_REACTED_TO_SCAN"), "data-driven reaction emits structured story events")
	var contextual_reactions: Array[StringName] = []
	manager.contextual_dialogue_requested.connect(func(_actor_id, reaction_id, _lines): contextual_reactions.append(reaction_id))
	manager.handle_context_event({"type": &"TRACE_UPDATED", "trace": 12})
	manager.handle_context_event({"type": &"TRACE_UPDATED", "trace": 13})
	_expect(contextual_reactions == [&"WARM_TRACE", &"LOW_TRACE"], "priority chooses one sparse response per event and once-only reactions do not repeat")
	_expect(manager.point_out(latch.instance_id, &"NODE", &"ENTRY").success, "Latch can point out a system without controlling the player")
	_expect(manager.disappear(latch.instance_id).success and knowledge.get_visible_hackers_at([&"ROUTER"]).is_empty(), "scripted disappearance removes Latch from current knowledge projection")
	_expect(not manager.move_scripted(latch.instance_id, &"ENTRY").success, "hidden or disconnected hackers cannot be commanded through movement API")
	_expect(not manager.execute_scripted_command(latch.instance_id, {"type": &"PLAYER_COMMAND"}).success, "remote hacker exposes no party-command operation")
	print("%s: %d Hacker NPC assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	manager.free()
	quit(failures)


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
