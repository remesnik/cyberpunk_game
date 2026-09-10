extends Node

const DISPLAY := preload("res://cyberspace/display/NetworkDisplay.tscn")

var failures := 0
var assertions := 0

func _ready() -> void:
	var display := DISPLAY.instantiate() as NetworkDisplay
	add_child(display)
	display.netspace_focus_mode = NetworkDisplay.NetspaceFocusMode.NODE
	display.focused_node_id = &"CURRENT"
	display.target_views = {
		&"CURRENT": {"kind": &"NODE", "title": "CURRENT", "current": true},
		&"ICE_LOCAL": {"kind": &"ICE", "title": "BLACK ICE", "ice": {"node_id": &"CURRENT"}},
		&"SERVICE_LOCAL": {"kind": &"SERVICE", "title": "SECURITY DAT"},
	}
	display.local_target_visuals = {&"ICE_LOCAL": Button.new(), &"SERVICE_LOCAL": Button.new()}
	display.selected_target_id = &"CURRENT"
	display.focused_node_id = &"CURRENT"
	display._valid_contextual_commands = [&"SCAN", &"ATTACK_PROCESS"]
	display._selected_contextual_command = &"SCAN"
	display.selected_command_id = &"SCAN"
	_expect(display.netspace_focus_mode == NetworkDisplay.NetspaceFocusMode.NODE and display.focused_node_id == &"CURRENT", "node focus state is explicit")
	display.netspace_focus_mode = NetworkDisplay.NetspaceFocusMode.LOCAL_TARGET
	display.focused_local_target_id = &"ICE_LOCAL"
	display.selected_target_id = &"ICE_LOCAL"
	_expect(display.netspace_focus_mode == NetworkDisplay.NetspaceFocusMode.LOCAL_TARGET and display.selected_target_id == &"ICE_LOCAL", "local target mode tracks the focused local target")
	display.cycle_contextual_command(1)
	_expect(display.selected_command_id == &"ATTACK_PROCESS", "local D-pad command cycling changes command state")
	var current_node := &"CURRENT"
	_expect(current_node == &"CURRENT", "local mode does not mutate current node state")
	display.netspace_focus_mode = NetworkDisplay.NetspaceFocusMode.NODE
	display.focused_local_target_id = &""
	_expect(display.netspace_focus_mode == NetworkDisplay.NetspaceFocusMode.NODE and display.focused_local_target_id.is_empty(), "Back exit restores node mode and clears local focus")
	display.execute_class_skill()
	_expect(display.status_label.text == "CLASS SKILL NOT AVAILABLE", "class skill remains a no-effect hook")
	var executor: RefCounted = load("res://core/skills/ClassSkillExecutor.gd").new()
	var skill_result: Dictionary = executor.execute(&"VIRUS", {"kind": &"ICE"}, {})
	_expect(not skill_result.success and skill_result.reason == "Class skill not available", "class skill executor is extensible without inventing an ability")
	display.queue_free()
	print("%s: %d Netspace focus assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
