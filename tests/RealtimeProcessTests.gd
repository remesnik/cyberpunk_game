extends SceneTree

const CyberspaceClockScript := preload("res://core/CyberspaceClock.gd")
const RealtimeProcessScript := preload("res://core/RealtimeProcess.gd")
const RealtimeProcessManagerScript := preload("res://core/RealtimeProcessManager.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_clock_domain_isolation()
	_test_finite_process_completion()
	print("%s: %d realtime process assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_clock_domain_isolation() -> void:
	var manager = RealtimeProcessManagerScript.new()
	var process = RealtimeProcessScript.new(&"CAMERA_01", RealtimeProcessScript.ProcessType.VIDEO_FEED, "Camera")
	manager.add_process(process, true)
	manager.advance_to_realtime(5.0)
	_expect(is_equal_approx(process.elapsed_time, 5.0), "realtime timestamp advances active process")

	var cyber_clock = CyberspaceClockScript.new()
	var request := ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 100)
	var result := cyber_clock.resolve_action(request, _always_valid, _always_applies)
	_expect(result.success and cyber_clock.current_tick == 100, "cyberspace clock advances 100 ticks")
	_expect(is_equal_approx(process.elapsed_time, 5.0), "100 cyberspace ticks do not advance realtime process")

	manager.advance_to_realtime(7.5)
	_expect(is_equal_approx(process.elapsed_time, 7.5), "process advances only from later realtime timestamp")
	manager.free()


func _test_finite_process_completion() -> void:
	var manager = RealtimeProcessManagerScript.new()
	var process = RealtimeProcessScript.new(&"CALL", RealtimeProcessScript.ProcessType.VOICE_CALL, "Call", &"CONTACT", 3.0)
	manager.add_process(process, true)
	manager.advance_to_realtime(10.0)
	_expect(process.state == RealtimeProcessScript.State.COMPLETED, "finite process completes")
	_expect(is_equal_approx(process.elapsed_time, 3.0), "finite process elapsed time clamps to duration")
	manager.free()


func _always_valid(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _always_applies(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "Applied.", "events": []}


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
