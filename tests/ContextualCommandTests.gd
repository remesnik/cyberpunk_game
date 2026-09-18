extends Node

const DISPLAY := preload("res://cyberspace/display/NetworkDisplay.tscn")

var failures := 0
var assertions := 0

func _ready() -> void:
	var display := DISPLAY.instantiate() as NetworkDisplay
	add_child(display)
	display.position_model = PlayerNetworkPosition.new(&"NODE", 10)
	display.target_views = {&"UNACTIONABLE": {"kind": &"UNKNOWN", "title": "UNKNOWN"}}
	display.selected_target_id = &"UNACTIONABLE"
	_expect(display.get_valid_commands() == [], "valid-command query excludes unrelated actions")
	display.target_views = {
		&"NODE": {"kind": &"NODE", "scanned": false},
		&"ICE": {"kind": &"ICE", "scanned": true, "ice": {"node_id": &"NODE", "scanned": true}, "attackable": true, "bypassable": true},
		&"FILE": {"kind": &"FILE", "scanned": true, "file": {"node_id": &"NODE", "scanned": true}, "analyzable": true, "downloadable": true, "deletable": false},
	}
	display.netspace_view_mode = NetworkDisplay.NetspaceViewMode.NETWORK
	display.selected_target_id = &"NODE"
	_expect(display.get_valid_commands() == [&"SCAN"], "unscanned nodes always expose Scan and no unrelated commands")
	display.netspace_view_mode = NetworkDisplay.NetspaceViewMode.NODE_FOCUS
	display.selected_target_id = &"ICE"
	_expect(display.get_valid_commands() == [&"ATTACK", &"BYPASS"], "ICE exposes only its valid canonical commands after scan")
	display.selected_target_id = &"FILE"
	_expect(display.get_valid_commands() == [&"ANALYZE", &"DOWNLOAD"], "files expose only valid canonical commands")
	for kind: StringName in [&"NODE", &"ICE", &"SERVICE", &"FILE", &"DEVICE_OBJECT"]:
		display.netspace_view_mode = NetworkDisplay.NetspaceViewMode.NETWORK if kind == &"NODE" else NetworkDisplay.NetspaceViewMode.NODE_FOCUS
		var view := {"kind": kind, "scanned": false}
		if kind == &"NODE": view["node"] = {"id": &"UNSCANNED"}
		elif kind == &"ICE": view["ice"] = {"node_id": &"NODE"}
		elif kind == &"SERVICE": view["service"] = {"node_id": &"NODE"}
		elif kind == &"FILE": view["file"] = {"node_id": &"NODE"}
		elif kind == &"DEVICE_OBJECT": view["device"] = {"node_id": &"NODE"}
		display.target_views[&"UNSCANNED"] = view
		display.selected_target_id = &"UNSCANNED"
		display._recalculate_contextual_commands(true)
		_expect(&"SCAN" in display.get_valid_commands() and display.selected_command_id == &"SCAN", "unscanned %s defaults to Scan" % kind)
	display._valid_contextual_commands = [&"SCAN", &"DOWNLOAD", &"DELETE"]
	display._selected_contextual_command = &"SCAN"
	display.cycle_contextual_command(1)
	_expect(display._selected_contextual_command == &"DOWNLOAD", "next contextual command skips invalid commands")
	display.cycle_contextual_command(-1)
	_expect(display._selected_contextual_command == &"SCAN", "previous contextual command uses the same cycle")
	display.cycle_contextual_command(-1)
	_expect(display._selected_contextual_command == &"DELETE", "contextual command cycle wraps")
	display._selected_contextual_command = &"SCAN"
	display._render_command_dial()
	_expect(display.command_dial.get_child_count() == 3, "command dial renders selected command and valid neighbors")
	display._valid_contextual_commands = [&"SCAN", &"PROBE", &"ENTER", &"ATTACK", &"BYPASS", &"CONNECT"]
	display._render_command_dial()
	_expect(display.command_dial.get_child_count() <= 5, "command dial caps visible commands at five")
	display._valid_contextual_commands.clear()
	display.cycle_contextual_command(1)
	_expect(display._selected_contextual_command == &"SCAN", "zero-command cycle does nothing")
	display.execute_class_skill()
	_expect(display.status_label.text == "CLASS SKILL NOT AVAILABLE", "class-skill hook has no gameplay effect")
	display.queue_free()
	print("%s: %d contextual command assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
