extends SceneTree

const WidgetScript := preload("res://ui/monitors/DockableMonitorWidget.gd")
const ProbeScript := preload("res://tests/MonitorProbe.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	root.add_child(host)
	var first := WidgetScript.new()
	var first_probe := ProbeScript.new()
	host.add_child(first)
	first.configure("COMMS", first_probe, WidgetScript.DockSlot.RIGHT, true)
	var second := WidgetScript.new()
	var second_probe := ProbeScript.new()
	host.add_child(second)
	second.configure("VIDEO", second_probe, WidgetScript.DockSlot.BOTTOM, true)

	await process_frame
	await process_frame
	_expect(first.minimized and not first_probe.is_visible_in_tree(), "minimizing hides only monitor presentation")
	_expect(first_probe.is_inside_tree() and first_probe.update_count > 0, "a minimized monitor continues receiving frame updates")
	_expect(first_probe.process_mode != Node.PROCESS_MODE_DISABLED, "minimizing does not disable monitor processing")
	_expect(first.pinned and second.pinned, "multiple realtime monitors may be pinned simultaneously")
	_expect(not paused, "opening and minimizing monitors does not pause tactical gameplay")

	print("%s: %d monitor dock assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
