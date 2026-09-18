extends SceneTree

const RealtimeClockScript := preload("res://core/RealtimeWorldClock.gd")
const PausePolicyScript := preload("res://core/PausePolicy.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var policy = PausePolicyScript.new()
	root.add_child(policy)
	policy.hard_pause_available = true
	policy.set_mode(PausePolicyScript.Mode.GAMEPLAY)
	_expect(policy.allows_cyberspace_actions() and policy.allows_realtime_advance(), "gameplay enables cyber actions and realtime")
	var start_event := InputEventAction.new()
	start_event.action = &"pause_game"; start_event.pressed = true
	policy._unhandled_input(start_event)
	_expect(policy.mode == PausePolicyScript.Mode.HARD_PAUSE, "controller Start uses the same pause policy as keyboard pause")
	policy._unhandled_input(start_event)
	_expect(policy.mode == PausePolicyScript.Mode.GAMEPLAY, "controller Start resumes through the shared pause policy")

	var clock = RealtimeClockScript.new()
	root.add_child(clock)
	clock.bind_pause_policy(policy)
	clock.start(true)
	policy.enter_soft_pause()
	clock._process(2.0)
	_expect(not policy.allows_cyberspace_actions(), "soft pause freezes cyberspace actions")
	_expect(policy.allows_realtime_advance() and is_equal_approx(clock.elapsed_seconds, 2.0), "soft pause continues realtime systems")
	_expect(not paused and not policy.should_pause_audio(), "soft pause does not pause the scene tree or audio")

	policy.set_mode(PausePolicyScript.Mode.HARD_PAUSE)
	clock._process(2.0)
	_expect(paused and not policy.allows_realtime_advance(), "hard pause freezes realtime and the scene tree")
	_expect(is_equal_approx(clock.elapsed_seconds, 2.0) and policy.should_pause_audio(), "hard pause freezes elapsed seconds and requests audio pause")

	policy.resume_gameplay()
	policy.hard_pause_available = false
	_expect(not policy.set_mode(PausePolicyScript.Mode.HARD_PAUSE) and policy.mode == PausePolicyScript.Mode.GAMEPLAY, "session policy can disable hard pause for future multiplayer")
	policy.hard_pause_available = true
	clock.queue_free()
	policy.queue_free()
	print("%s: %d pause policy assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
