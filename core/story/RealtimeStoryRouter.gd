class_name RealtimeStoryRouter
extends Node

signal structured_event_received(event: StoryEvent)
signal hook_activated(hook: StoryHook, event: StoryEvent)
signal story_action_produced(hook_id: StringName, action: Dictionary)

var hooks: Dictionary = {}
var event_history: Array[StoryEvent] = []
var activated_hooks: Dictionary = {}
var action_handlers: Dictionary = {}
var flags: Dictionary = {}
var _clock: RealtimeWorldClock
var _serial: int = 0
var _comms: Variant
var _video: Variant
var _alarms: Variant
var _teams: Variant


func configure(clock: RealtimeWorldClock) -> void:
	_clock = clock


func bind_sources(comms: Node, video: Node, alarms: Node, teams: Node, equipment: Node, scheduler: Node) -> void:
	_comms = comms
	_video = video
	_alarms = alarms
	_teams = teams
	if not comms.intercept_started.is_connected(_on_comms_intercepted): comms.intercept_started.connect(_on_comms_intercepted)
	if not comms.recording_started.is_connected(_on_comms_recorded): comms.recording_started.connect(_on_comms_recorded)
	if not comms.comms_event_heard.is_connected(_on_comms_event_heard): comms.comms_event_heard.connect(_on_comms_event_heard)
	if not video.feed_observed.is_connected(_on_video_observed): video.feed_observed.connect(_on_video_observed)
	if not video.video_event_seen.is_connected(_on_video_event_seen): video.video_event_seen.connect(_on_video_event_seen)
	if not alarms.alarm_state_changed.is_connected(_on_alarm_state_changed): alarms.alarm_state_changed.connect(_on_alarm_state_changed)
	if not teams.team_moved.is_connected(_on_team_moved): teams.team_moved.connect(_on_team_moved)
	if not teams.team_state_changed.is_connected(_on_team_state_changed): teams.team_state_changed.connect(_on_team_state_changed)
	if not equipment.delivery_event.is_connected(_on_equipment_delivered): equipment.delivery_event.connect(_on_equipment_delivered)
	if not scheduler.event_completed.is_connected(_on_realtime_event_completed): scheduler.event_completed.connect(_on_realtime_event_completed)


func reset() -> void:
	hooks.clear()
	event_history.clear()
	activated_hooks.clear()
	action_handlers.clear()
	flags.clear()
	_serial = 0


func add_hook(hook: StoryHook) -> bool:
	if hook == null or hook.id == &"" or hooks.has(hook.id):
		return false
	hooks[hook.id] = hook
	return true


func register_action_handler(action_type: StringName, handler: Callable) -> void:
	if handler.is_valid():
		action_handlers[action_type] = handler


func publish(event_type: StoryEvent.Type, source_id: StringName, payload: Dictionary = {}, tags: Array[StringName] = []) -> StoryEvent:
	_serial += 1
	var realtime := _clock.elapsed_seconds if _clock != null else 0.0
	var event := StoryEvent.new(event_type, source_id, realtime, payload)
	event.id = StringName("STORY_EVENT_%05d" % _serial)
	event.story_tags.assign(tags)
	event_history.append(event)
	structured_event_received.emit(event)
	_evaluate_hooks(event)
	return event


func has_event(event_type: StringName, filters: Dictionary = {}) -> bool:
	for event: StoryEvent in event_history:
		if event.type_name() == event_type and _event_matches(event, filters):
			return true
	return false


func _evaluate_hooks(latest_event: StoryEvent) -> void:
	var context := {"story_events": event_history, "latest_story_event": latest_event, "flags": flags}
	for value: Variant in hooks.values():
		var hook := value as StoryHook
		if activated_hooks.has(hook.id):
			continue
		if hook.trigger not in [&"ANY_REALTIME", latest_event.type_name()]:
			continue
		if not hook.matches(context):
			continue
		activated_hooks[hook.id] = latest_event.id
		hook_activated.emit(hook, latest_event)
		for authored_action: Dictionary in hook.effects:
			var action := authored_action.duplicate(true)
			action["hook_id"] = hook.id
			action["source_event_id"] = latest_event.id
			action["realtime"] = latest_event.realtime_seconds
			story_action_produced.emit(hook.id, action)
			var action_type: StringName = action.get("type", &"")
			if action_handlers.has(action_type):
				action_handlers[action_type].call(action, hook, latest_event)


func _event_matches(event: StoryEvent, filters: Dictionary) -> bool:
	if filters.has("source_id") and event.source_id != StringName(filters.source_id):
		return false
	if filters.has("story_tag") and not event.story_tags.has(StringName(filters.story_tag)):
		return false
	var payload_filters: Dictionary = filters.get("payload", {})
	for key: Variant in payload_filters:
		if event.payload.get(key) != payload_filters[key]:
			return false
	return true


func _on_comms_intercepted(session_id: StringName) -> void:
	var session: CommsSession = _comms.sessions.get(session_id)
	publish(StoryEvent.Type.COMMS_INTERCEPTED, session_id, {"channel_id": session.channel_id if session != null else &""}, session.story_tags if session != null else [])


func _on_comms_recorded(session_id: StringName) -> void:
	var session: CommsSession = _comms.sessions.get(session_id)
	publish(StoryEvent.Type.COMMS_RECORDED, session_id, {"channel_id": session.channel_id if session != null else &""}, session.story_tags if session != null else [])


func _on_comms_event_heard(session_id: StringName, event_id: StringName, line: Dictionary) -> void:
	publish(StoryEvent.Type.HEARD_COMMS_EVENT, session_id, {"comms_event_id": event_id, "speaker_id": line.get("speaker_id", &""), "text": line.get("text", ""), "stream_time": line.get("time", 0.0)})


func _on_video_observed(feed_id: StringName) -> void:
	var definition: VideoFeedDefinition = _video.definitions.get(feed_id)
	publish(StoryEvent.Type.VIDEO_OBSERVED, feed_id, {"physical_location_id": definition.physical_location_id if definition != null else &""}, definition.story_tags if definition != null else [])


func _on_video_event_seen(feed_id: StringName, event: Dictionary) -> void:
	publish(StoryEvent.Type.VIDEO_EVENT_SEEN, feed_id, {"video_event_id": event.get("event_id", event.get("type", &"")), "event": event.duplicate(true)})


func _on_alarm_state_changed(alarm_id: StringName, _previous: int, current: int) -> void:
	var definition: PhysicalAlarmDefinition = _alarms.definitions.get(alarm_id)
	var tags: Array[StringName] = definition.story_tags if definition != null else []
	if current == PhysicalAlarmInstance.State.TRIGGERED:
		publish(StoryEvent.Type.ALARM_TRIGGERED, alarm_id, {"state": current, "physical_location_id": definition.physical_location_id}, tags)
	elif current == PhysicalAlarmInstance.State.BYPASSED:
		publish(StoryEvent.Type.ALARM_BYPASSED, alarm_id, {"state": current, "physical_location_id": definition.physical_location_id}, tags)


func _on_team_moved(team_id: StringName, previous: StringName, current: StringName) -> void:
	publish(StoryEvent.Type.TEAM_REACHED_LOCATION, team_id, {"previous_location": previous, "location_id": current})


func _on_team_state_changed(team_id: StringName, _previous: int, current: int) -> void:
	if current == PhysicalTeamInstance.State.LOST:
		publish(StoryEvent.Type.TEAM_LOST, team_id, {"state": current})
	elif current == PhysicalTeamInstance.State.COMPLETE:
		var team: PhysicalTeamInstance = _teams.instances.get(team_id)
		publish(StoryEvent.Type.TEAM_SUCCESS, team_id, {"state": current, "location_id": team.current_location if team != null else &"", "objective": team.objective if team != null else &""})


func _on_equipment_delivered(event: Dictionary) -> void:
	publish(StoryEvent.Type.EQUIPMENT_DELIVERED, event.get("order_id", &""), event, event.get("story_tags", []))


func _on_realtime_event_completed(instance: RealtimeEventInstance) -> void:
	publish(StoryEvent.Type.REALTIME_EVENT_OCCURRED, instance.definition.id, {"instance_id": instance.id, "scheduled_at": instance.scheduled_at, "completed_at": instance.completed_at, "produced_actions": instance.produced_actions.duplicate(true)}, instance.definition.story_tags)
