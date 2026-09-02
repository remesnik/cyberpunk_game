extends SceneTree

const Catalog := preload("res://core/story/MissionEventNodeCatalog.gd")
const Validator := preload("res://addons/cyberspace_authoring/validators/AuthoringValidator.gd")
var failures := 0
var assertions := 0

func _init() -> void:
	var document := CyberspaceContentDocument.new()
	document.hacker_npcs = [{"id": &"LATCH", "initial_node_id": &"ENTRY", "comms_channel_id": &""}]
	document.network_nodes = [{"id": &"ENTRY"}, {"id": &"ROUTER_A"}]
	document.network_links = [{"id": &"ENTRY_ROUTER", "source": &"ENTRY", "destination": &"ROUTER_A"}]
	document.objectives = [{"id": &"INSPECT_ENTRY"}, {"id": &"REACH_ROUTER"}]
	document.rewards = [{"id": &"UTILITY_LOOT", "reward_type": &"CUSTOM", "quantity": 1, "probability": 1.0, "source_type": &"NETWORK_NODE", "source_id": &"ENTRY"}]
	document.ice_definitions = [{"id": &"TUTORIAL_ICE"}]
	document.realtime_events = [{"id": &"PHONE_CALL", "delay_seconds": 1.0, "actions": [{"type": &"START_COMMS"}]}]
	var nodes: Array[Dictionary] = []
	nodes.append(_with(Catalog.create(&"DIALOGUE", &"N01"), {"actor_id": &"LATCH", "text": "Don't move yet."}))
	nodes.append(_with(Catalog.create(&"WAIT_FOR", &"N02"), {"event_type": &"PLAYER_INSPECTED_CURRENT_NODE"}))
	nodes.append(_with(Catalog.create(&"DIALOGUE", &"N03"), {"actor_id": &"LATCH", "text": "Good."}))
	nodes.append(_with(Catalog.create(&"OBJECTIVE_COMPLETE", &"N04"), {"objective_id": &"INSPECT_ENTRY"}))
	nodes.append(_with(Catalog.create(&"MOVE_ACTOR", &"N05"), {"actor_id": &"LATCH", "node_id": &"ROUTER_A"}))
	nodes.append(_with(Catalog.create(&"OBJECTIVE_START", &"N06"), {"objective_id": &"REACH_ROUTER"}))
	nodes.append(_with(Catalog.create(&"WAIT_FOR", &"N07"), {"event_type": &"NODE_ENTERED", "target_id": &"ROUTER_A"}))
	for event in [&"DOORSTOP_DEPLOYED", &"INTRUSION_SUSPENDED_AT_DOORSTOP", &"INTRUSION_RESUMED_FROM_DOORSTOP"]:
		nodes.append(_with(Catalog.create(&"WAIT_FOR", StringName("WAIT_%s" % event)), {"event_type": event}))
	document.story_sequences = [{"id": &"GUIDED_EXAMPLE", "display_name": "Guided Example", "event_nodes": nodes}]
	_expect(Catalog.NODE_TYPES.has(&"SPAWN_REWARD") and Catalog.NODE_TYPES.has(&"SPAWN_ICE") and Catalog.NODE_TYPES.has(&"BRANCH") and Catalog.NODE_TYPES.has(&"HINT"), "catalog covers loot, ICE, behavior branches, and optional hints")
	_expect(Catalog.GAMEPLAY_EVENTS.has(&"DOORSTOP_DEPLOYED") and Catalog.GAMEPLAY_EVENTS.has(&"INTRUSION_SUSPENDED_AT_DOORSTOP") and Catalog.GAMEPLAY_EVENTS.has(&"INTRUSION_RESUMED_FROM_DOORSTOP"), "Doorstop lifecycle uses generic gameplay waits")
	var converted := Catalog.convert_legacy_beats([{"id": &"OPEN", "trigger": {"event_type": &"NODE_ENTERED", "target_id": &"ENTRY"}, "dialogue": [{"speaker_id": &"LATCH", "text": "Don't move yet."}], "objective": {"id": &"INSPECT_ENTRY", "title": "Inspect entry"}, "completion": {"event_type": &"NODE_SCANNED", "target_id": &"ENTRY"}}], &"LATCH")
	_expect(converted.size() == 4 and converted[0].type == &"WAIT_FOR" and converted[1].type == &"DIALOGUE" and converted[2].type == &"OBJECTIVE_START", "legacy First Contact beats convert non-destructively to generic nodes")
	var issues: Array[Dictionary] = Validator.new().validate(document)
	_expect(not issues.any(func(issue): return issue.level == "ERROR" and issue.category == "MISSION SEQUENCE"), "example guided sequence validates without custom scripts")
	var invalid := Catalog.create(&"SPAWN_ICE", &"BAD_ICE"); invalid.ice_definition_id = &"MISSING"
	document.story_sequences[0].event_nodes.append(invalid)
	issues = Validator.new().validate(document)
	_expect(issues.any(func(issue): return issue.category == "MISSION SEQUENCE" and issue.message.contains("ICE definition")), "authoring validation catches invalid event-node references")
	print("%s: %d story sequence authoring assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _with(base: Dictionary, patch: Dictionary) -> Dictionary:
	base.merge(patch, true); return base
func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
