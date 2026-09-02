extends SceneTree

const ValidatorScript := preload("res://addons/cyberspace_authoring/validators/AuthoringValidator.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	var level := load("res://data/authoring/first_contact.tres") as CyberspaceContentDocument
	_expect(level != null and level.document_id == &"FIRST_CONTACT", "FIRST_CONTACT loads as an authored content document")
	_expect(level.network_nodes.size() == 10, "tutorial graph contains ten compact nodes")
	var required_nodes: Array[StringName] = [&"ENTRY", &"ACCESS_RELAY", &"ROUTER_A", &"CAM_CTL", &"FILE_CACHE", &"SEC_RELAY", &"COMM_NODE", &"OPS_SERVER", &"EXIT_GATE"]
	_expect(required_nodes.all(func(id): return level.find_entry(id) != {}), "all required tutorial node roles are authored")
	_expect(_link_exists(level, &"ENTRY", &"ACCESS_RELAY") and _link_exists(level, &"ACCESS_RELAY", &"ROUTER_A"), "initial topology constrains the player to a guided ingress")
	_expect(_outgoing_count(level, &"ROUTER_A") >= 2, "Router A opens the first route choice")
	_expect(level.network_links.any(func(link): return link.get("hidden", false)) and level.network_links.any(func(link): return link.get("locked", false)), "topology includes discoverable and logically gated routes")
	_expect(level.comms_participants.any(func(participant): return participant.id == &"LATCH"), "Latch is an authored comms participant")
	var latch_sessions: Array = level.comms_sessions.filter(func(session): return session.channel_id == &"LATCH_BACKCHANNEL")
	_expect(latch_sessions.size() == 6, "Latch guidance uses staged realtime comms sessions across cyber and meat-space domains")
	_expect(level.comms_sessions.all(func(session): return not JSON.stringify(session).contains("press ")), "guidance contains no generic button prompts")
	_expect(level.story_hooks.all(func(hook): return not hook.activation_actions.is_empty()), "tutorial milestones use ordinary story conditions and actions")
	_expect(level.objectives.any(func(objective): return objective.id == &"RETRIEVE_ROUTE_MANIFEST" and not objective.optional), "objective and exit progression are authored")
	var opening: Dictionary = level.find_entry(&"FIRST_CONTACT_OPENING")
	_expect(opening.get("beats", []).size() == 3, "opening guidance is split into three player-paced beats")
	_expect(opening.beats[0].delay_seconds > 0.0 and opening.beats[0].objective.title == "INSPECT YOUR CURRENT NODE", "Latch arrives after a brief delay and asks for an in-world inspection")
	_expect(opening.beats[1].commands.any(func(command): return command.type == &"APPEAR" and command.node_id == &"ACCESS_RELAY"), "Latch appears on the adjacent relay after inspection")
	_expect(opening.beats[1].objective.target_id == &"ACCESS_RELAY" and opening.beats[2].completion.event_type == &"NETWORK_TIME_ADVANCED", "first traversal objective demonstrates normal cyber time advancement")
	_expect(opening.beats.all(func(beat): return beat.dialogue.size() <= 3), "opening avoids dumping mechanics into one dialogue block")
	var camera_sequence: Dictionary = level.find_entry(&"FIRST_CONTACT_ROUTER_CAMERA")
	_expect(camera_sequence.get("beats", []).size() == 8, "router and camera tutorial is divided into action-gated beats")
	_expect(camera_sequence.beats[0].objective.target_id == &"ROUTER_A" and camera_sequence.beats[1].objective.target_id == &"CAM_CTL", "sequence inspects Router A before guiding toward camera control")
	_expect(camera_sequence.beats.any(func(beat): return beat.objective.get("id", &"") == &"IDENTIFY_CAMERA_SERVICE") and camera_sequence.beats.any(func(beat): return beat.objective.get("id", &"") == &"EXAMINE_CAMERA_STATE"), "service identity and service state are taught separately")
	_expect(camera_sequence.beats.any(func(beat): return beat.objective.get("action_type", &"") == &"EXPLOIT" and beat.objective.get("compatible_program_ids", []).has(&"SERVICE_PROBE")), "camera compromise requires a compatible program through the generic exploit action")
	var camera_feed: Dictionary = level.find_entry(&"CAM_LOBBY_01")
	_expect(camera_feed.get("can_monitor", false) and camera_feed.get("can_select", false) and camera_feed.get("can_rotate", false) and camera_feed.get("can_disable", false), "authored meat-space feed supports viewing, selecting, rotating, and temporary disable")
	_expect(camera_sequence.beats[-2].objective.action_type == &"DISABLE" and camera_sequence.beats[-2].completion.state == &"OFFLINE", "disabling the logical camera feed is required for progression")
	var comms_sequence: Dictionary = level.find_entry(&"FIRST_CONTACT_LIVE_COMMS")
	_expect(comms_sequence.beats.any(func(beat): return beat.objective.get("id", &"") == &"DISCOVER_LIVE_CALL"), "COMM_NODE inspection exposes the authored meat-space call")
	_expect(comms_sequence.beats.any(func(beat): return beat.objective.get("id", &"") == &"CHOOSE_CALL_ACCESS" and beat.objective.get("optional", false)), "live-call access remains an optional tactical choice")
	var cache: Dictionary = level.find_entry(&"FILE_CACHE_SOFTWARE_BUNDLE")
	_expect(cache.get("reward_ids", []).has(&"LATCH_UTILITY_REWARD") and cache.get("reward_ids", []).has(&"TUTORIAL_DOORSTOP_REWARD"), "FILE_CACHE authors both required software rewards")
	var doorstop_reward: Dictionary = level.find_entry(&"TUTORIAL_DOORSTOP_REWARD")
	_expect(doorstop_reward.get("probability", 0.0) == 1.0 and not doorstop_reward.get("repeatable", true), "tutorial Doorstop reward is guaranteed and one-time")
	var doorstop_sequence: Dictionary = level.find_entry(&"FIRST_CONTACT_SEC_RELAY_DOORSTOP")
	_expect(doorstop_sequence.beats[0].objective.target_node_id == &"SEC_RELAY" and doorstop_sequence.beats[0].completion.event_type == &"DOORSTOP_DEPLOYED", "SEC_RELAY objective requires a real Doorstop deployment event")
	_expect(doorstop_sequence.beats[1].objective.action_type == &"JACK_OUT_DOORSTOP", "post-deployment guidance uses Doorstop-specific Jack Out")
	var management_sequence: Dictionary = level.find_entry(&"FIRST_CONTACT_MEATSPACE_MANAGEMENT")
	_expect(management_sequence.beats.map(func(beat): return beat.objective.get("action_type", &"")).has(&"INSPECT_DECK"), "suspended sequence teaches deck inspection")
	_expect(management_sequence.beats.map(func(beat): return beat.objective.get("action_type", &"")).has(&"START_PROGRAMMING"), "suspended sequence teaches realtime software programming")
	_expect(management_sequence.beats[-1].objective.action_type == &"JACK_BACK_IN_DOORSTOP" and management_sequence.beats[-1].objective.destroy_anchor_on_success, "JACK BACK IN is enabled with explicit one-use anchor destruction")
	var reentry_sequence: Dictionary = level.find_entry(&"FIRST_CONTACT_REENTRY_ENCOUNTER")
	_expect(reentry_sequence.beats[0].trigger.conditions.any(func(condition): return condition.get("type", &"") == &"RETURNED_THROUGH_DOORSTOP" and condition.node_id == &"SEC_RELAY"), "continuity sequence requires exact SEC_RELAY Doorstop return")
	_expect(reentry_sequence.beats[1].commands.any(func(command): return command.type == &"SET_ICE_STATE" and command.state == &"HUNT"), "persisted auditor enters an active real ICE state after return")
	_expect(reentry_sequence.beats[1].objective.choices.size() >= 3, "first ICE encounter presents multiple topology/program responses")
	var final_sequence: Dictionary = level.find_entry(&"FIRST_CONTACT_FINAL_OBJECTIVE")
	_expect(final_sequence.beats.size() == 5 and final_sequence.learned_skill_summary.size() == 7, "final objective synthesizes learned systems without adding a new mechanic")
	_expect(final_sequence.beats[1].objective.requires_installed_program and final_sequence.beats[1].objective.has("trace_guidance"), "OPS exploit combines installed software and existing trace management")
	_expect(final_sequence.beats[2].objective.id == &"RETRIEVE_ROUTE_MANIFEST" and final_sequence.beats[3].objective.completion_mode == &"NORMAL_EXIT", "manifest retrieval leads to a normal mission exit")
	_expect(not final_sequence.beats[3].objective.doorstop_jack_out_completes_mission, "Doorstop suspension explicitly cannot complete FIRST_CONTACT")
	_expect(final_sequence.beats[-1].commands.any(func(command): return command.type == &"COMPLETE_INTRUSION" and command.mode == &"NORMAL"), "EXIT_GATE authors a normal intrusion completion command")
	_expect(level.hacker_reactions.size() == 9 and level.hacker_reactions.all(func(reaction): return reaction.actor_id == &"LATCH_REMOTE_ACTOR"), "Latch has a focused authored contextual reaction set")
	_expect(level.hacker_reactions.all(func(reaction): return reaction.get("once", true) and int(reaction.get("cooldown_actions", 0)) >= 2), "contextual dialogue is first-time and cooldown constrained")
	_expect(level.hacker_reactions.any(func(reaction): return reaction.id == &"LATCH_NORMAL_JACK_OUT_WARNING") and level.hacker_reactions.any(func(reaction): return reaction.id == &"LATCH_UNEXPECTED_ENCOUNTER_SOLUTION"), "mistakes and clever alternate solutions receive prioritized reactions")
	_expect(level.tutorial_guidance_rules.size() == 9, "First Contact has authored novice recovery and hint rules")
	_expect(level.tutorial_guidance_rules.all(func(rule): return bool(rule.get("recoverable", false)) and not bool(rule.get("hard_fail", false))), "novice mistakes do not create tutorial-only hard failures")
	var editor_state := load("res://data/authoring/first_contact.editor_state.tres") as AuthoringEditorState
	_expect(editor_state != null and editor_state.graph_positions.size() == level.network_nodes.size(), "editor-only layout covers every node and remains separate")
	var issues: Array[Dictionary] = ValidatorScript.new().validate(level)
	_expect(not issues.any(func(issue): return issue.level == "ERROR"), "authoring validation reports no errors")
	print("%s: %d First Contact authoring assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _link_exists(level: CyberspaceContentDocument, a: StringName, b: StringName) -> bool:
	return level.network_links.any(func(link): return (link.source == a and link.destination == b) or (not link.get("one_way", false) and link.source == b and link.destination == a))


func _outgoing_count(level: CyberspaceContentDocument, node_id: StringName) -> int:
	return level.network_links.filter(func(link): return link.source == node_id or (not link.get("one_way", false) and link.destination == node_id)).size()


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
