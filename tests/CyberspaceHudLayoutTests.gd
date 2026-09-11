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
	var previous_inventory := Game.program_inventory
	var previous_loadout := Game.program_loadout
	Game.program_inventory = ProgramInventory.new()
	Game.program_loadout = ProgramLoadout.new(6)
	var display := DISPLAY.instantiate() as NetworkDisplay
	add_child(display)
	display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	display.position = Vector2.ZERO
	display.size = resolution
	display._apply_hud_layout()
	display._update_program_bar()
	_expect(display.get_node("BottomBar/Margin/Rows/Programs").get_child_count() == 6, "%s renders every active slot at variable capacity" % resolution)
	_expect((display.get_node("BottomBar/Margin/Rows/Programs").get_child(1) as Button).text.contains("EMPTY"), "%s renders empty active slots explicitly" % resolution)
	var graph_rect := display.get_primary_graph_rect()
	_expect(graph_rect.get_area() / (resolution.x * resolution.y) >= 0.35, "%s reserves the largest HUD region for graph interaction" % resolution)
	_expect(not display.left_panel.visible and graph_rect.position.x <= 64.0, "%s current-node details start collapsed to free graph space" % resolution)
	_expect(not graph_rect.intersects(display.sphere_minimap.get_rect()), "%s graph avoids Sphere minimap" % resolution)
	_expect(not display.right_panel.visible, "%s target inspector starts contextual/hidden" % resolution)
	_expect(not display.event_feed.visible, "%s detailed event log starts collapsed" % resolution)
	_expect(display.sphere_minimap.get_rect().end.y <= display.right_panel.get_rect().position.y, "%s minimap does not overlap contextual target panel" % resolution)
	_expect(graph_rect.end.y <= resolution.y - 160.0, "%s graph clears status, monitor, and quick-slot strips" % resolution)
	var projected := Control.new(); projected.position = Vector2(420, 330); projected.size = Vector2(100, 80); display.node_layer.add_child(projected)
	display.node_visuals[&"HUD_TARGET"] = projected
	display.target_views[&"HUD_TARGET"] = {"kind": &"NODE", "node": {"id": &"HUD_TARGET"}}
	display.selected_target_id = &"HUD_TARGET"; display._valid_contextual_commands = [&"SCAN"]; display._selected_contextual_command = &"SCAN"
	var dial_instance := display.command_dial.get_instance_id()
	display._render_command_dial(); display._update_command_dial_position()
	_expect(display.command_dial.get_parent() is CanvasLayer and (display.command_dial.get_parent() as CanvasLayer).layer > 0, "%s command dial renders in an unoccluded HUD CanvasLayer" % resolution)
	var first_dial_position := display.command_dial.position
	projected.position += Vector2(120, 45); display._update_command_dial_position()
	_expect(display.command_dial.position != first_dial_position and is_equal_approx(display.command_dial.position.x - first_dial_position.x, 120.0), "%s command dial follows the projected target while the map pans" % resolution)
	projected.position = Vector2(-200, -200); display._update_command_dial_position()
	_expect(display.command_dial.position.x >= 12 and display.command_dial.position.y >= 12, "%s command dial clamps inside the near viewport edge" % resolution)
	projected.position = resolution + Vector2(200, 200); display._update_command_dial_position()
	_expect(display.command_dial.get_rect().end.x <= resolution.x - 12 and display.command_dial.get_rect().end.y <= resolution.y - 12, "%s command dial clamps inside the far viewport edge" % resolution)
	display.target_views[&"SECOND_TARGET"] = {"kind": &"NODE", "node": {"id": &"SECOND_TARGET"}}; display.node_visuals[&"SECOND_TARGET"] = projected; display.selected_target_id = &"SECOND_TARGET"; display._update_command_dial_position()
	_expect(display.command_dial.get_instance_id() == dial_instance, "%s target changes reuse the single command dial" % resolution)
	display._context_panel_requested = true
	display._refresh_context_panel_visibility()
	_expect(display.right_panel.visible, "%s selected target can claim contextual rail" % resolution)
	display._on_monitor_presentation_changed(true, true)
	_expect(not display.right_panel.visible, "%s expanded Monitor shares rather than overlaps contextual rail" % resolution)
	display._on_monitor_presentation_changed(true, false)
	_expect(display.right_panel.visible, "%s collapsing Monitor restores requested target details" % resolution)
	display.queue_free()
	Game.program_inventory = previous_inventory
	Game.program_loadout = previous_loadout

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
