extends SceneTree

const RouterScript := preload("res://core/story/RealtimeStoryRouter.gd")
const EventScript := preload("res://core/story/StoryEvent.gd")
const HookScript := preload("res://core/story/StoryHook.gd")
const ConditionScript := preload("res://core/story/ConditionDefinition.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_accumulated_structured_events_activate_hook()
	print("%s: %d realtime story assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_accumulated_structured_events_activate_hook() -> void:
	var router = RouterScript.new()
	var actions: Array[Dictionary] = []
	router.register_action_handler(&"REVEAL_NODE", func(action: Dictionary, _hook: StoryHook, _event: StoryEvent) -> void: actions.append(action))
	var hook = HookScript.new(&"THE_INSIDE_MAN", &"HEARD_COMMS_EVENT")
	hook.conditions.append(ConditionScript.new(&"INTERCEPT", ConditionScript.ConditionType.STORY_EVENT_OCCURRED, &"COMMS_INTERCEPTED", {"source_id": &"SECURITY_CALL_04"}))
	hook.conditions.append(ConditionScript.new(&"PHRASE", ConditionScript.ConditionType.STORY_EVENT_OCCURRED, &"HEARD_COMMS_EVENT", {"source_id": &"SECURITY_CALL_04", "payload": {"comms_event_id": &"MENTION_LOADING_DOCK"}}))
	hook.effects.append({"type": &"REVEAL_NODE", "node_id": &"CONTRACTOR_VPN"})
	router.add_hook(hook)

	var intercepted = router.publish(EventScript.Type.COMMS_INTERCEPTED, &"SECURITY_CALL_04", {"channel_id": &"SECURITY"})
	_expect(intercepted.to_context().event_type == &"COMMS_INTERCEPTED" and actions.is_empty(), "structured intercept fact is retained without prematurely firing the ALL hook")
	router.publish(EventScript.Type.HEARD_COMMS_EVENT, &"SECURITY_CALL_04", {"comms_event_id": &"UNRELATED"})
	_expect(actions.is_empty(), "unrelated heard content does not satisfy the semantic event condition")
	router.publish(EventScript.Type.HEARD_COMMS_EVENT, &"SECURITY_CALL_04", {"comms_event_id": &"MENTION_LOADING_DOCK"})
	_expect(actions.size() == 1 and actions[0].node_id == &"CONTRACTOR_VPN", "all accumulated conditions produce the authored story action")
	router.publish(EventScript.Type.HEARD_COMMS_EVENT, &"SECURITY_CALL_04", {"comms_event_id": &"MENTION_LOADING_DOCK"})
	_expect(actions.size() == 1, "one-shot hook does not activate twice")

	for type: StoryEvent.Type in [EventScript.Type.VIDEO_OBSERVED, EventScript.Type.VIDEO_EVENT_SEEN, EventScript.Type.ALARM_TRIGGERED, EventScript.Type.ALARM_BYPASSED, EventScript.Type.TEAM_REACHED_LOCATION, EventScript.Type.TEAM_LOST, EventScript.Type.TEAM_SUCCESS, EventScript.Type.EQUIPMENT_DELIVERED, EventScript.Type.REALTIME_EVENT_OCCURRED]:
		router.publish(type, &"FIXTURE")
	_expect(router.event_history.size() == 13, "router accepts every supported realtime story event category")
	router.free()


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
