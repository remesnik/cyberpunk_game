extends Node

const DISPLAY := preload("res://cyberspace/display/NetworkDisplay.tscn")
const MONITOR_DOCK := preload("res://ui/monitors/RealtimeMonitorDock.tscn")

var failures := 0
var assertions := 0

func _ready() -> void:
	for resolution: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		_test_resolution(resolution)
	_test_contextual_monitors()
	print("%s: %d cyberspace HUD layout assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_resolution(resolution: Vector2) -> void:
	var display := DISPLAY.instantiate() as NetworkDisplay
	add_child(display)
	display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	display.position = Vector2.ZERO
	display.size = resolution
	display._apply_hud_layout()
	var graph_rect := display.get_primary_graph_rect()
	_expect(graph_rect.get_area() / (resolution.x * resolution.y) >= 0.35, "%s reserves the largest HUD region for graph interaction" % resolution)
	_expect(not display.left_panel.visible and graph_rect.position.x <= 64.0, "%s current-node details start collapsed to free graph space" % resolution)
	_expect(not graph_rect.intersects(display.sphere_minimap.get_rect()), "%s graph avoids Sphere minimap" % resolution)
	_expect(not display.right_panel.visible, "%s target inspector starts contextual/hidden" % resolution)
	_expect(not display.event_feed.visible, "%s detailed event log starts collapsed" % resolution)
	_expect(display.sphere_minimap.get_rect().end.y <= display.right_panel.get_rect().position.y, "%s minimap does not overlap contextual target panel" % resolution)
	_expect(graph_rect.end.y <= resolution.y - 160.0, "%s graph clears status, monitor, and quick-slot strips" % resolution)
	display._context_panel_requested = true
	display._refresh_context_panel_visibility()
	_expect(display.right_panel.visible, "%s selected target can claim contextual rail" % resolution)
	display._on_monitor_presentation_changed(true, true)
	_expect(not display.right_panel.visible, "%s expanded Monitor shares rather than overlaps contextual rail" % resolution)
	display._on_monitor_presentation_changed(true, false)
	_expect(display.right_panel.visible, "%s collapsing Monitor restores requested target details" % resolution)
	display.queue_free()

func _test_contextual_monitors() -> void:
	var dock := MONITOR_DOCK.instantiate() as RealtimeMonitorDock
	add_child(dock)
	_expect(dock.widgets.is_empty(), "team status no longer uses a permanent full monitor wrapper")
	_expect(dock.team_status != null and not dock.team_status.expanded, "team status defaults to its compact tactical representation")
	_expect(dock.monitor_window != null and not dock.monitor_window.visible, "unified feed monitor reserves no visible panel when inactive")
	_expect(dock.monitor_window.providers.size() == 3, "video, communications, and alarms use unified generic feed providers")
	dock.queue_free()

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
