extends SceneTree

const DefinitionScript := preload("res://core/operations/OperationPressureDefinition.gd")
const ManagerScript := preload("res://core/operations/OperationPressureManager.gd")
const CyberClockScript := preload("res://core/CyberspaceClock.gd")
const RealtimeClockScript := preload("res://core/RealtimeWorldClock.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_independent_pressures()
	print("%s: %d operation pressure assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_independent_pressures() -> void:
	var cyber = CyberClockScript.new()
	var realtime = RealtimeClockScript.new()
	var manager = ManagerScript.new()
	manager.configure(cyber, realtime)
	var definition = DefinitionScript.new(&"TEST_OPERATION", "Dual pressure test")
	definition.realtime_deadline_seconds = 42.0
	definition.add_cyber_step("SCAN", ActionRequest.ActionType.SCAN, &"ACCESS_ROUTER", 3)
	var operation: Variant = manager.begin(definition)

	var request := ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 100)
	var result := cyber.resolve_action(request, _always_valid, _always_applies)
	manager.record_cyber_action(request, result)
	_expect(cyber.current_tick == 100, "cyberspace action advances its declared tick cost")
	_expect(is_equal_approx(operation.realtime_seconds_remaining(0.0), 42.0), "100 cyber ticks consume zero realtime deadline seconds")

	realtime.restore(12.0, false)
	_expect(is_equal_approx(operation.realtime_seconds_remaining(realtime.elapsed_seconds), 30.0), "actual realtime progression reduces only the realtime deadline")
	_expect(cyber.current_tick == 100, "realtime progression creates no fake cyberspace ticks")
	_expect(operation.remaining_cyber_cost() == 3, "cyber plan cost remains a distinct tactical quantity")
	manager.free()
	realtime.free()


func _always_valid(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _always_applies(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "Applied.", "events": []}


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
