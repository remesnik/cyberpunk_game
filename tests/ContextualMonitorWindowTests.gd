extends Node

const WINDOW := preload("res://ui/monitors/ContextualMonitorWindow.tscn")

var failures := 0
var assertions := 0

func _ready() -> void:
	Game.start_session()
	var window: Control = WINDOW.instantiate()
	add_child(window)
	window._refresh_contents()
	_expect(not window.visible and window.active_feed_count() == 0, "monitor is hidden with no active feeds")

	var video_ids: Array = Game.video_feed_manager.sessions.keys()
	if not video_ids.is_empty(): Game.video_feed_manager.open_feed_id = video_ids[0]
	window._refresh_contents()
	_expect(window.visible and window.active_feed_count() == 1, "opening first video feed automatically shows monitor")

	var comms_sessions: Array = Game.comms_manager.sessions.values()
	if not comms_sessions.is_empty(): (comms_sessions[0] as CommsSession).monitor()
	window._refresh_contents()
	_expect(window.active_feed_count() == 2 and window.tabs.get_child_count() == 2, "simultaneous feed types appear as unified tabs")
	window.collapse()
	_expect(window.collapsed and not window.full_panel.visible and window.compact_indicator.visible and window.compact_indicator.text == "MONITOR // 2 ACTIVE", "collapsed monitor leaves a compact active-feed indicator")
	GameplayBindings.set_context(GameplayBindings.Context.CYBERSPACE)
	GameplayBindings._unhandled_input(_action(&"toggle_monitor"))
	_expect(not window.collapsed and window.full_panel.visible, "general TOGGLE_MONITOR binding reopens feeds without a mouse")
	var alarm_ids: Array = Game.physical_alarm_manager.instances.keys()
	if not alarm_ids.is_empty():
		var alarm: PhysicalAlarmInstance = Game.physical_alarm_manager.instances[alarm_ids[0]]
		Game.player_knowledge.realtime_process_records[alarm.definition.realtime_process_id] = {"id": alarm.definition.realtime_process_id}
		Game.physical_alarm_manager.start_monitoring(alarm.definition.id)
	window._refresh_contents()
	_expect(window.active_feed_count() == 3 and window.tabs.get_child_count() == 3, "explicitly monitored alarms join the same contextual window")

	Game.video_feed_manager.close_monitor()
	if not comms_sessions.is_empty(): (comms_sessions[0] as CommsSession).stop_monitoring()
	if not alarm_ids.is_empty(): Game.physical_alarm_manager.stop_monitoring(alarm_ids[0])
	window._refresh_contents()
	_expect(not window.visible and not window.compact_indicator.is_visible_in_tree() and window.active_feed_count() == 0, "window and compact indicator hide after final feed stops")

	window.queue_free()
	Game.end_session()
	print("%s: %d contextual monitor assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
