extends SceneTree

var failures := 0
var assertions := 0


func _init() -> void:
	var level := load("res://data/authoring/first_contact.tres") as CyberspaceContentDocument
	var graph := NetworkGraph.new()
	for id: StringName in [&"CAM_CTL", &"SEC_RELAY", &"COMM_NODE"]:
		graph.add_node(NetworkNodeDefinition.new(id, String(id), NetworkNodeDefinition.NodeType.SYSTEM, 1, true))
	graph.add_link(NetworkLinkDefinition.new(&"CAM_SECURITY", &"CAM_CTL", &"SEC_RELAY"))
	graph.add_link(NetworkLinkDefinition.new(&"SEC_COMM", &"SEC_RELAY", &"COMM_NODE"))
	var player := PlayerNetworkPosition.new(&"CAM_CTL", 10)
	var knowledge := PlayerKnowledge.new()
	for id: StringName in [&"CAM_CTL", &"SEC_RELAY"]: knowledge.reveal_node(graph.get_node(id), KnowledgeLevel.Value.IDENTIFIED)
	var controller := IceController.new(graph, player, knowledge)
	var authored := AuthoredIceFactory.populate(controller, level.ice_definitions, level.ice_instances)
	var auditor := authored.instances.get(&"SEC_RELAY_AUDITOR_01") as IceInstance
	_expect(auditor != null and not auditor.operational and auditor.state == IceState.Value.PATROL, "authored passive auditor loads into the actual ICE system inactive and patrolling")
	auditor.operational = true
	knowledge.detect_ice(auditor.instance_id)
	_expect(knowledge.get_ice_level(auditor.instance_id) == KnowledgeLevel.Value.DETECTED, "activation exposes only an ICE signal through PlayerKnowledge")
	var events := controller.update(1, ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 1))
	_expect(auditor.current_node_id == &"SEC_RELAY" and auditor.state != IceState.Value.ENGAGE, "one tutorial action does not make passive ICE attack or reach the player")
	_expect(not events.any(func(event): return event.get("type", &"") == &"PLAYER_DETECTED"), "low-threat ICE does not directly detect the adjacent player")

	var video_trace := int(level.find_entry(&"CAM_LOBBY_01").get("disable_trace", 0))
	var clock := ActionClock.new()
	var trace_state := {"value": 0}
	clock.register_trace_updater(func(tick: int, _request: ActionRequest) -> Array[Dictionary]:
		trace_state.value += video_trace
		return [{"type": &"TRACE_UPDATED", "tick": tick, "increase": video_trace, "trace": trace_state.value, "player_visible": true}]
	)
	var result := clock.resolve_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.USE_PROGRAM, {"feed_id": &"CAM_LOBBY_01"}, 2), func(_request): return {"success": true, "reason": "", "events": []}, func(_request): return {"success": true, "reason": "Camera disabled.", "events": [{"type": &"CAMERA_OFFLINE"}]})
	_expect(result.success and trace_state.value == 2 and result.events_produced.any(func(event): return event.get("type", &"") == &"TRACE_UPDATED" and event.get("player_visible", false)), "camera manipulation raises visible trace through the actual ActionClock trace phase")
	_expect(trace_state.value < PayrollMissionController.TRACE_FAILURE_THRESHOLD, "scripted tutorial trace remains safely below failure threshold")
	var sequence: Dictionary = level.find_entry(&"FIRST_CONTACT_TRACE_AND_ICE")
	_expect(sequence.beats.size() == 4 and sequence.beats[-1].objective.allowed_action_types == [&"MOVE", &"SCAN", &"WAIT"], "authored lesson ends with a live decision under trace pressure")
	print("%s: %d First Contact trace/ICE assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
