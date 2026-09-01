extends SceneTree

const ProcessScript := preload("res://core/RealtimeProcess.gd")
const ProcessManagerScript := preload("res://core/RealtimeProcessManager.gd")
const FeedScript := preload("res://core/video/VideoFeedDefinition.gd")
const FeedManagerScript := preload("res://core/video/VideoFeedManager.gd")
const CyberClockScript := preload("res://core/CyberspaceClock.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_multiple_feeds_use_current_realtime_state()
	print("%s: %d video feed assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_multiple_feeds_use_current_realtime_state() -> void:
	var process_manager = ProcessManagerScript.new()
	process_manager.add_process(ProcessScript.new(&"DOCK_PROCESS", ProcessScript.ProcessType.VIDEO_FEED, "Dock"), true)
	process_manager.add_process(ProcessScript.new(&"LOBBY_PROCESS", ProcessScript.ProcessType.VIDEO_FEED, "Lobby"), true)
	var knowledge := PlayerKnowledge.new()
	var position := PlayerNetworkPosition.new(&"SECURITY_SYSTEM")
	knowledge.realtime_process_records[&"DOCK_PROCESS"] = {"id": &"DOCK_PROCESS"}
	knowledge.realtime_process_records[&"LOBBY_PROCESS"] = {"id": &"LOBBY_PROCESS"}
	var manager = FeedManagerScript.new()
	manager.configure(process_manager, knowledge, position)

	var dock = FeedScript.new(&"CAM_LOADING_DOCK_03", "Dock 03")
	dock.player_access = true
	dock.can_disable = true
	dock.can_replay = true
	dock.add_event(0.0, &"STATE", {"description": "EMPTY DOCK"})
	dock.add_event(12.0, &"ENTER", {"entity_id": &"GUARD", "kind": &"PERSON"})
	dock.add_event(23.0, &"ENTER", {"entity_id": &"TRUCK", "kind": &"VEHICLE"})
	dock.add_event(41.0, &"LEAVE", {"entity_id": &"GUARD"})
	dock.add_event(54.0, &"ENTER", {"entity_id": &"TEAM", "kind": &"PERSON"})
	manager.add_feed(dock, &"DOCK_PROCESS")
	var lobby = FeedScript.new(&"CAM_LOBBY", "Lobby")
	lobby.player_access = true
	lobby.add_event(8.0, &"ENTER", {"entity_id": &"VISITOR", "kind": &"PERSON"})
	manager.add_feed(lobby, &"LOBBY_PROCESS")

	process_manager.advance_to_realtime(30.0)
	var dock_session: VideoFeedSession = manager.sessions[dock.id]
	var lobby_session: VideoFeedSession = manager.sessions[lobby.id]
	_expect(dock_session.elapsed_time == 30.0 and lobby_session.elapsed_time == 30.0, "multiple feeds advance simultaneously while closed")
	_expect(dock_session.active_entities.has(&"GUARD") and dock_session.active_entities.has(&"TRUCK"), "authored events establish the current physical scene")
	var opened := manager.open_feed(dock.id)
	_expect(opened.elapsed_time == 30.0, "opening late reflects current time instead of restarting")
	var freeze_result: VideoFeedActionResult = manager.execute_action(dock.id, VideoFeedActionDefinition.Command.FREEZE)
	var frozen_view := dock_session.get_observer_view()
	_expect(freeze_result.success and dock_session.feed_state == VideoFeedState.Value.FROZEN, "freeze changes the logical observer state")

	var cyber = CyberClockScript.new()
	cyber.resolve_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 100), _valid, _applied)
	_expect(cyber.current_tick == 100 and dock_session.elapsed_time == 30.0, "100 cyber ticks do not advance video")
	manager.close_monitor()
	process_manager.advance_to_realtime(55.0)
	_expect(dock_session.elapsed_time == 55.0 and lobby_session.elapsed_time == 55.0, "closing monitor does not stop any feed")
	_expect(not dock_session.active_entities.has(&"GUARD") and dock_session.active_entities.has(&"TEAM"), "later events resolve while monitor is closed")
	_expect(dock_session.get_observer_view().time == frozen_view.time and not _entity_ids(dock_session.get_observer_view()).has(&"TEAM"), "frozen observers retain the old frame while true scene changes")
	var loop_result: VideoFeedActionResult = manager.execute_action(dock.id, VideoFeedActionDefinition.Command.LOOP)
	_expect(loop_result.success and loop_result.trace_generated == 3 and loop_result.security_suspicion == 25, "loop uses data-driven trace and suspicion")
	_expect(loop_result.story_events[0].type == &"CAMERA_LOOPED" and dock_session.feed_state == VideoFeedState.Value.LOOPED, "loop produces authored story event and observer state")
	var denied_spoof: VideoFeedActionResult = manager.validate_action(dock.id, VideoFeedActionDefinition.Command.SPOOF)
	_expect(not denied_spoof.success and denied_spoof.reason.contains("ROOTKIT"), "spoof capability requirement is data-driven")
	position.grant_capability(CapabilityCatalog.ROOTKIT)
	var spoof_result: VideoFeedActionResult = manager.execute_action(dock.id, VideoFeedActionDefinition.Command.SPOOF)
	_expect(spoof_result.success and dock_session.get_observer_view().state.contains("ALL CLEAR"), "spoof presents authored false state")
	var disable_result: VideoFeedActionResult = manager.execute_action(dock.id, VideoFeedActionDefinition.Command.DISABLE)
	process_manager.advance_to_realtime(60.0)
	_expect(disable_result.success and not dock_session.get_observer_view().available and dock_session.elapsed_time == 60.0, "offline signal does not stop the true physical timeline")
	manager.execute_action(dock.id, VideoFeedActionDefinition.Command.RESTORE)
	_expect(dock_session.feed_state == VideoFeedState.Value.LIVE and dock_session.get_observer_view().time == 60.0, "restore returns observers to current live state")
	_expect(manager.get_discovered_feeds().size() == 2, "multiple discovered feeds remain available and active")
	manager.free()
	process_manager.free()


func _valid(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _applied(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _entity_ids(view: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for entity: Dictionary in view.get("entities", []):
		ids.append(entity.get("id", &""))
	return ids


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
