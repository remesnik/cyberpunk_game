extends Node

var failures := 0
var assertions := 0
var latch_lines: Array[String] = []

func _ready() -> void:
	HudState.diegetic_lesson_requested.connect(func(speaker: StringName, _lesson: StringName, lines: Array) -> void:
		if speaker == &"LATCH": latch_lines.append_array(lines.map(func(line: Variant) -> String: return String(line)))
	)
	Game.create_new_game(GameMode.Value.STORY)
	Game.persistent_game_state.campaign_state["current_content_id"] = &"FIRST_CONTACT"
	Game.persistent_game_state.campaign_state["pending_entry_content_id"] = &"FIRST_CONTACT"
	Game.persistent_game_state.campaign_state.get_or_add("story_flags", {})[&"FIRST_CONTACT_STARTED"] = true
	Game.start_session()
	_expect(Game.active_content_profile.get("runtime_document_path", "") == "res://data/networks/first_contact.netspace", "Story launch selects the canonical encrypted First Contact network")
	_expect(Game.player_network_position.current_node_id == &"SAN", "First Contact starts at SAN")
	_expect(Game.entry_guidance != null and Game.entry_guidance.current_step_id() == &"FC_BRIEF", "one tutorial controller owns the opening step")
	Game.game_domain = Game.GameDomain.CLEAN_ROOM
	var entered := Game.enter_netspace_from_clean_room()
	_expect(entered.success and Game.game_domain == Game.GameDomain.CYBERSPACE, "Clean Room GO initializes First Contact before enabling Netspace")
	Game.entry_guidance.advance(0.1)
	_expect(not latch_lines.is_empty(), "Latch speaks when the tutorial starts")
	_expect(not Game.request_traversal(&"ACCESS").success and Game.last_traversal_debug.reason == &"TUTORIAL_STEP_RESTRICTION", "intro step blocks otherwise-open traversal")
	_expect(not Game.traversal_preview(&"COMMS").allowed, "sensor-visible topology is not directly traversable")
	_expect(Game.request_scan({"kind": ScanSystem.CURRENT_NODE, "node_id": &"SAN"}).success, "the expected opening scan uses real gameplay")
	Game.entry_guidance.advance(0.1)
	_expect(Game.entry_guidance.current_step_id() == &"FC_TRAVERSE_ACCESS", "scan event advances the authoritative tutorial step")
	_expect(Game.request_traversal(&"ACCESS").success, "the intended first path becomes usable at its traversal step")
	_expect(not Game.traversal_preview(&"COMMS").allowed, "the onward path remains locked after reaching ACCESS")
	print("%s: %d First Contact launch-flow assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	Game.end_session()
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
