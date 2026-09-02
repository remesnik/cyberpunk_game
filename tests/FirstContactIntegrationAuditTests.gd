extends SceneTree

const NetworkFactory := preload("res://cyberspace/AuthoredNetworkFactory.gd")
const Guidance := preload("res://core/story/TutorialGuidanceState.gd")
var failures := 0
var assertions := 0

func _init() -> void:
	var level := load("res://data/authoring/first_contact.tres") as CyberspaceContentDocument
	var runtime := NetworkFactory.build(level)
	var graph: NetworkGraph = runtime.graph
	var position: PlayerNetworkPosition = runtime.position
	_expect(graph.nodes.size() == 10 and graph.links.size() == 11 and position.current_node_id == &"ENTRY", "fresh authored runtime builds complete First Contact graph at ENTRY")
	_expect(level.story_variables.all(func(variable): return not bool(variable.get("default_value", false))), "fresh save begins with no prior tutorial flags")
	var serialized := JSON.stringify(level.all_entries()).to_upper()
	_expect(not serialized.contains("DEBUG") and not serialized.contains("CHEAT"), "authored sequences contain no debug or cheat commands")
	_expect(level.objectives.all(func(objective): return objective.get("failure_conditions", []).is_empty()), "tutorial objectives add no artificial hard-fail conditions")
	var reentry: Dictionary = level.find_entry(&"FIRST_CONTACT_REENTRY_ENCOUNTER")
	_expect(reentry.beats[1].objective.choices.size() >= 4 and reentry.beats[1].completion.events.size() >= 5, "first active ICE encounter accepts alternate production actions")
	var doorstop_reward: Dictionary = level.find_entry(&"TUTORIAL_DOORSTOP_REWARD")
	_expect(doorstop_reward.reward_type == &"PROGRAM" and doorstop_reward.program_definition_id == &"DOORSTOP_TUTORIAL_1_0", "Doorstop is issued through the generic program reward pipeline")
	_expect(level.find_entry(&"GUARD_CAMERA_CALL_PROCESS").process_type == &"VOICE_CALL" and level.find_entry(&"GUARD_CAMERA_FAULT_CALL").realtime_process_id == &"GUARD_CAMERA_CALL_PROCESS", "meat-space call uses RealtimeProcess and CommsSession data")
	_expect(level.find_entry(&"SEC_RELAY_AUDITOR_01").definition_id == &"PASSIVE_AUDITOR_MK1", "tutorial ICE is a production IceInstance definition reference")
	var guidance := Guidance.new(); guidance.configure(level.tutorial_guidance_rules)
	for count in 4: guidance.observe({"type": &"TUTORIAL_STALLED", "objective_id": &"INSPECT_ACCESS_RELAY"})
	_expect(guidance.get_hint_index(&"FC_HINT_ACCESS_RELAY") == 3 and not guidance.observe({"type": &"TUTORIAL_STALLED", "objective_id": &"INSPECT_ACCESS_RELAY"}).handled, "tutorial hints exhaust and cannot fire repeatedly")
	_expect(not ClassDB.class_exists("FirstContactSaveGame"), "audit records that tutorial save/load progression is not yet supported")
	print("%s: %d First Contact integration-audit assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
