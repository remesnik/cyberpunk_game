extends Node

const TEAM_STATUS := preload("res://ui/PhysicalTeamMonitor.tscn")

var failures := 0
var assertions := 0

func _ready() -> void:
	var status: Control = TEAM_STATUS.instantiate()
	add_child(status)
	status._refresh()
	_expect(not status.visible, "team status is hidden when no relevant contacts exist")
	EventBus.publish_tactical_status_alert(&"SAN_BREACHED", &"LOCAL_SAN", "SAN BREACHED", &"CRITICAL", 0.5)
	_expect(status.visible and status.alert_label.visible and not status.expanded, "critical event surfaces compact status without opening details")
	status._process(0.6)
	_expect(not status.visible and not status.alert_label.visible, "event-only status hides after its short alert expires")

	Game.start_session()
	status._refresh()
	_expect(status.visible and not status.expanded, "active known teams appear in compact mode")
	_expect(status.compact_roster.get_child_count() > 0 and status.custom_minimum_size.y <= 34.0, "default roster is a thin tactical row")

	Game.player_knowledge.hacker_records[&"LATCH_REMOTE"] = {"id": &"LATCH_REMOTE", "callsign": "LATCH", "relationship": &"ALLY", "state": HackerNPC.State.CONNECTED, "present": true, "node_id": &"ROUTER_A"}
	status._refresh()
	_expect(_roster_contains(status, "LATCH  ONLINE"), "known allied hackers use the same compact roster")

	var team_ids: Array = Game.physical_team_manager.instances.keys()
	if not team_ids.is_empty():
		var team: PhysicalTeamInstance = Game.physical_team_manager.instances[team_ids[0]]
		team.set_operational_state(PhysicalTeamInstance.State.ENGAGED, "CONTACT")
		Game.physical_team_manager.observe_team(team.id, PhysicalTeamKnowledge.Source.TEAM_TELEMETRY, Game.realtime_world_clock.elapsed_seconds)
		status._refresh()
		_expect(_roster_contains(status, "ENGAGED!"), "critical state is promoted into the compact line")

	status.set_expanded(true)
	_expect(status.expanded and status.detail_content.visible, "explicit selection can open detailed status")
	status.set_expanded(false)
	_expect(not status.detail_content.visible, "details collapse without removing tactical awareness")
	status._process(5.0)
	EventBus.publish_tactical_status_alert(&"COMMS_LOST", &"LATCH_REMOTE", "COMMS LOST", &"CRITICAL", 0.5)
	_expect(not status.expanded and "COMMS LOST" in status.alert_label.text, "important event emphasis does not force full panel open")
	status._process(0.6)
	_expect(status.visible and not status.expanded and status.compact_roster.visible, "status returns to compact roster after alert")

	status.queue_free()
	Game.end_session()
	print("%s: %d team status assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _roster_contains(status: Control, fragment: String) -> bool:
	for child in status.compact_roster.get_children():
		if fragment in String(child.text): return true
	return false

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
