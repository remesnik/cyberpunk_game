extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	HudState.reset_defaults()
	_expect(HudState.is_visible(HudState.Widget.SPHERE_MINIMAP), "Sphere Minimap is always visible by default")
	_expect(HudState.is_visible(HudState.Widget.PROGRAM_QUICKBAR), "Program Quickbar is always visible by default")
	_expect(not HudState.is_visible(HudState.Widget.MONITOR), "Monitor starts hidden without active context")
	_expect(not HudState.is_visible(HudState.Widget.NODE_INSPECTOR), "Node Inspector starts hidden without a selection")

	HudState.set_context_active(HudState.Widget.MONITOR, true)
	_expect(HudState.is_visible(HudState.Widget.MONITOR), "context makes the Monitor visible")
	HudState.set_collapsed(HudState.Widget.MONITOR, true)
	_expect(HudState.is_collapsed(HudState.Widget.MONITOR), "collapsed presentation is centrally tracked")

	HudState.set_context_active(HudState.Widget.NODE_INSPECTOR, true)
	HudState.set_suppressed(HudState.Widget.NODE_INSPECTOR, &"TEST_MODAL", true)
	_expect(not HudState.is_visible(HudState.Widget.NODE_INSPECTOR), "a temporary suppressor hides a contextual widget")
	_expect(bool(HudState.get_state(HudState.Widget.NODE_INSPECTOR).context_active), "suppression does not discard context")
	HudState.set_suppressed(HudState.Widget.NODE_INSPECTOR, &"TEST_MODAL", false)
	_expect(HudState.is_visible(HudState.Widget.NODE_INSPECTOR), "removing suppression restores the contextual widget")

	HudState.set_user_visible(HudState.Widget.NODE_INSPECTOR, false)
	_expect(not HudState.is_visible(HudState.Widget.NODE_INSPECTOR), "user visibility overrides active context")
	HudState.set_user_visible(HudState.Widget.NODE_INSPECTOR, true)
	HudState.set_policy(HudState.Widget.NODE_INSPECTOR, HudState.Policy.HIDDEN)
	_expect(not HudState.is_visible(HudState.Widget.NODE_INSPECTOR), "HIDDEN policy wins over context")

	HudState.register_widget(99, HudState.Policy.USER_TOGGLED)
	_expect(HudState.is_visible(99), "user-toggled widgets may start enabled")
	HudState.toggle_user_visible(99)
	_expect(not HudState.is_visible(99), "user-toggled widgets can be disabled centrally")

	HudState.reset_defaults()
	var feedback: Array[String] = []
	HudState.action_feedback.connect(func(message: String) -> void: feedback.append(message))
	_expect(not HudState.handle_bound_action(&"TOGGLE_MONITOR") and feedback[-1] == "MONITOR: NO ACTIVE FEEDS", "monitor binding reports unavailable content without opening an empty window")
	_expect(not HudState.is_visible(HudState.Widget.MONITOR), "unavailable Monitor remains hidden")
	HudState.set_context_active(HudState.Widget.MONITOR, true)
	_expect(HudState.handle_bound_action(&"TOGGLE_MONITOR") and HudState.is_collapsed(HudState.Widget.MONITOR), "monitor binding toggles presentation when feeds exist")
	_expect(not HudState.handle_bound_action(&"TOGGLE_TEAM_STATUS") and feedback[-1] == "TEAM STATUS: NO ACTIVE CONTACTS", "team binding reports unavailable contacts cleanly")
	_expect(not HudState.handle_bound_action(&"OPEN_NODE_INSPECTOR") and feedback[-1] == "NODE INSPECTOR: NO TARGET SELECTED", "inspector binding requires valid contextual content")
	_expect(HudState.handle_bound_action(&"TOGGLE_MINIMAP") and HudState.is_collapsed(HudState.Widget.SPHERE_MINIMAP), "minimap binding toggles centralized collapsed state")
	var opened: Array[int] = []
	HudState.widget_open_requested.connect(func(widget_id: int) -> void: opened.append(widget_id))
	_expect(HudState.handle_bound_action(&"OPEN_PROGRAM_LOADOUT") and opened[-1] == HudState.Widget.PROGRAM_QUICKBAR, "program loadout binding requests the existing loadout surface")

	HudState.reset_defaults()
	if failures == 0:
		print("HUD VISIBILITY MANAGER TESTS PASSED: %d assertions" % assertions)
		get_tree().quit(0)
	else:
		push_error("HUD VISIBILITY MANAGER TESTS FAILED: %d/%d" % [failures, assertions])
		get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
