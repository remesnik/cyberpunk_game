extends SceneTree

const TutorialGuidanceStateScript = preload("res://core/story/TutorialGuidanceState.gd")

var failures := 0
var assertions := 0

func _init() -> void:
	var level := load("res://data/authoring/first_contact.tres") as CyberspaceContentDocument
	_expect(level != null and level.tutorial_guidance_rules.size() == 9, "First Contact authors all novice recovery cases")
	var guidance = TutorialGuidanceStateScript.new()
	guidance.configure(level.tutorial_guidance_rules)
	var stalled := {"type": &"TUTORIAL_STALLED", "objective_id": &"INSPECT_ACCESS_RELAY"}
	var first: Dictionary = guidance.observe(stalled)
	var second: Dictionary = guidance.observe(stalled)
	var third: Dictionary = guidance.observe(stalled)
	var exhausted: Dictionary = guidance.observe(stalled)
	_expect(first.lines[0].text == "Take another look at the relay.", "first stuck response is indirect")
	_expect(second.lines[0].text.contains("east connection"), "second stuck response narrows the search")
	_expect(third.lines[0].text == "CAM_CTL. Scan it.", "third stuck response gives the direct solution")
	_expect(not exhausted.handled and guidance.get_hint_index(&"FC_HINT_ACCESS_RELAY") == 3, "exhausted hints do not repeat endlessly")
	var ice: Dictionary = guidance.observe({"type": &"PLAYER_DETECTED_BY_ICE"})
	_expect(ice.recoverable and not ice.hard_fail and ice.recovery_policy == &"CONTINUE_ENCOUNTER", "ICE detection teaches through a recoverable encounter")
	var anchor: Dictionary = guidance.observe({"type": &"DOORSTOP_DEPLOYED_OUTSIDE_SUGGESTED_NODE", "node_id": &"CAM_CTL"})
	_expect(anchor.recovery_policy == &"ADOPT_ACTUAL_ANCHOR_NODE" and anchor.context.node_id == &"CAM_CTL", "off-target Doorstop preserves its actual legal anchor")
	var missed: Dictionary = guidance.observe({"type": &"OPTIONAL_COMMS_MISSED"})
	_expect(missed.recovery_policy == &"CONTINUE_WITH_ALTERNATE_INTEL", "missed optional comms do not block progression")
	_expect(level.tutorial_guidance_rules.all(func(rule): return bool(rule.get("recoverable", false)) and not bool(rule.get("hard_fail", false))), "tutorial recovery rules contain no artificial hard failures")
	print("%s: %d tutorial guidance assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
