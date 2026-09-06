class_name HudVisibilityManager
extends Node

signal widget_state_changed(widget_id: int, state: Dictionary)
signal widget_open_requested(widget_id: int)
signal action_feedback(message: String)
signal widget_emphasis_requested(widget_id: int, duration: float)
signal diegetic_lesson_requested(actor_id: StringName, lesson_id: StringName, lines: Array)
signal tutorial_objective_requested(objective_id: StringName, title: String, optional: bool)
signal tutorial_objective_completed(objective_id: StringName)

enum Widget { SPHERE_MINIMAP, PROGRAM_QUICKBAR, MONITOR, TEAM_STATUS, NODE_INSPECTOR, OBJECTIVE, TRACE, ALERTS }
enum Policy { ALWAYS, CONTEXTUAL, COLLAPSED, USER_TOGGLED, HIDDEN }

const DEFAULT_POLICIES := {
	Widget.SPHERE_MINIMAP: Policy.ALWAYS,
	Widget.PROGRAM_QUICKBAR: Policy.ALWAYS,
	Widget.MONITOR: Policy.CONTEXTUAL,
	Widget.TEAM_STATUS: Policy.COLLAPSED,
	Widget.NODE_INSPECTOR: Policy.CONTEXTUAL,
	Widget.OBJECTIVE: Policy.ALWAYS,
	Widget.TRACE: Policy.ALWAYS,
	Widget.ALERTS: Policy.CONTEXTUAL,
}

var states: Dictionary = {}
var content_profile: Dictionary = {}
var _fired_content_rules: Dictionary = {}
var _content_event_counts: Dictionary = {}
var _pending_content_objectives: Dictionary = {}

func _ready() -> void:
	reset_defaults()
	GameplayBindings.binding_triggered.connect(_on_binding_triggered)
	GameplayBindings.program_instance_bound.connect(_on_program_instance_bound)
	EventBus.session_started.connect(_on_session_started)
	EventBus.network_position_changed.connect(_on_network_position_changed)

func _on_session_started() -> void:
	reset_defaults()
	var document: Resource = Game.active_content_document
	if document != null:
		configure_content_profile(document.get("hud_guidance") as Dictionary)

func configure_content_profile(profile: Dictionary) -> void:
	content_profile = profile.duplicate(true)
	_fired_content_rules.clear()
	_content_event_counts.clear()
	_pending_content_objectives.clear()
	var initial: Dictionary = content_profile.get("initial_policies", {})
	for widget_name: Variant in initial:
		var widget_id := widget_from_name(StringName(widget_name))
		var policy := policy_from_name(StringName(initial[widget_name]))
		if widget_id >= 0 and policy >= 0:
			set_policy(widget_id, policy)

func _on_network_position_changed(from_node_id: StringName, to_node_id: StringName, _link_id: StringName) -> void:
	if from_node_id != to_node_id:
		trigger_content_event(&"PLAYER_MOVED")

func _on_program_instance_bound(_binding_id: StringName, instance_id: StringName) -> void:
	if not instance_id.is_empty():
		trigger_content_event(&"PROGRAM_BOUND")

func trigger_content_event(event_id: StringName) -> bool:
	_content_event_counts[event_id] = int(_content_event_counts.get(event_id, 0)) + 1
	for rule: Dictionary in content_profile.get("reveal_rules", []):
		var rule_id := StringName(rule.get("id", &""))
		if StringName(rule.get("event", &"")) != event_id or _fired_content_rules.has(rule_id):
			continue
		if int(_content_event_counts[event_id]) < int(rule.get("minimum_occurrences", 1)):
			continue
		var widget_id := widget_from_name(StringName(rule.get("widget", &"")))
		if widget_id < 0:
			continue
		var policy := policy_from_name(StringName(rule.get("policy", &"")))
		if policy >= 0: set_policy(widget_id, policy)
		_fired_content_rules[rule_id] = true
		var duration := float(rule.get("emphasis_seconds", 0.0))
		if duration > 0.0: widget_emphasis_requested.emit(widget_id, duration)
		var lines: Array = rule.get("lines", [])
		if not lines.is_empty(): diegetic_lesson_requested.emit(StringName(rule.get("actor_id", &"")), rule_id, lines.duplicate(true))
		var objective: Dictionary = rule.get("objective", {})
		if not objective.is_empty():
			var objective_id := StringName(objective.get("id", &""))
			_pending_content_objectives[objective_id] = {"widget": widget_id, "completion_event": StringName(objective.get("completion_event", &""))}
			tutorial_objective_requested.emit(objective_id, String(objective.get("title", "")), bool(objective.get("optional", true)))
		return true
	return false

func notify_widget_interacted(widget_id: int) -> bool:
	for objective_id: StringName in _pending_content_objectives.keys():
		var objective: Dictionary = _pending_content_objectives[objective_id]
		if int(objective.get("widget", -1)) != widget_id: continue
		_pending_content_objectives.erase(objective_id)
		tutorial_objective_completed.emit(objective_id)
		var completion_event := StringName(objective.get("completion_event", &""))
		if not completion_event.is_empty(): trigger_content_event(completion_event)
		return true
	return false

func _on_binding_triggered(request: RefCounted) -> void:
	if request.category != GameplayBindingRequest.Category.GLOBAL_GAME_ACTION:
		return
	handle_bound_action(request.command_id)

func handle_bound_action(command_id: StringName) -> bool:
	match command_id:
		&"TOGGLE_MINIMAP":
			if int(get_state(Widget.SPHERE_MINIMAP).policy) == Policy.HIDDEN:
				action_feedback.emit("SPHERE MINIMAP: NOT YET AVAILABLE")
				return false
			if notify_widget_interacted(Widget.SPHERE_MINIMAP):
				set_collapsed(Widget.SPHERE_MINIMAP, false)
				return true
			set_collapsed(Widget.SPHERE_MINIMAP, not is_collapsed(Widget.SPHERE_MINIMAP))
			return true
		&"TOGGLE_MONITOR":
			return _toggle_contextual_widget(Widget.MONITOR, "MONITOR: NO ACTIVE FEEDS")
		&"TOGGLE_TEAM_STATUS":
			return _toggle_contextual_widget(Widget.TEAM_STATUS, "TEAM STATUS: NO ACTIVE CONTACTS")
		&"OPEN_NODE_INSPECTOR":
			return _open_contextual_widget(Widget.NODE_INSPECTOR, "NODE INSPECTOR: NO TARGET SELECTED")
		&"OPEN_PROGRAM_LOADOUT":
			if int(get_state(Widget.PROGRAM_QUICKBAR).policy) == Policy.HIDDEN:
				action_feedback.emit("PROGRAM LOADOUT: NOT YET AVAILABLE")
				return false
			set_user_visible(Widget.PROGRAM_QUICKBAR, true)
			widget_open_requested.emit(Widget.PROGRAM_QUICKBAR)
			return true
	return false

func _toggle_contextual_widget(widget_id: int, unavailable_message: String) -> bool:
	var state := get_state(widget_id)
	if not bool(state.context_active):
		action_feedback.emit(unavailable_message)
		return false
	set_user_visible(widget_id, true)
	set_collapsed(widget_id, not bool(state.collapsed))
	return true

func _open_contextual_widget(widget_id: int, unavailable_message: String) -> bool:
	var state := get_state(widget_id)
	if not bool(state.context_active):
		action_feedback.emit(unavailable_message)
		return false
	set_user_visible(widget_id, true)
	set_collapsed(widget_id, false)
	widget_open_requested.emit(widget_id)
	return true

func reset_defaults() -> void:
	content_profile.clear()
	_fired_content_rules.clear()
	_content_event_counts.clear()
	_pending_content_objectives.clear()
	states.clear()
	for widget_id: int in DEFAULT_POLICIES:
		register_widget(widget_id, DEFAULT_POLICIES[widget_id])

func register_widget(widget_id: int, policy: Policy) -> void:
	states[widget_id] = {"policy": policy, "context_active": policy == Policy.ALWAYS, "user_visible": policy != Policy.HIDDEN, "collapsed": policy == Policy.COLLAPSED, "suppressors": {}}
	_emit(widget_id)

func set_policy(widget_id: int, policy: Policy) -> void:
	_ensure(widget_id)
	states[widget_id].policy = policy
	if policy == Policy.COLLAPSED: states[widget_id].collapsed = true
	_emit(widget_id)

func set_context_active(widget_id: int, active: bool) -> void:
	_ensure(widget_id)
	if bool(states[widget_id].context_active) == active: return
	states[widget_id].context_active = active
	_emit(widget_id)
	if active:
		if widget_id == Widget.MONITOR: trigger_content_event(&"FIRST_EXTERNAL_MONITOR")
		elif widget_id == Widget.TEAM_STATUS: trigger_content_event(&"TEAM_STATUS_RELEVANT")

func set_user_visible(widget_id: int, value: bool) -> void:
	_ensure(widget_id)
	states[widget_id].user_visible = value
	_emit(widget_id)

func toggle_user_visible(widget_id: int) -> void:
	_ensure(widget_id)
	set_user_visible(widget_id, not bool(states[widget_id].user_visible))

func set_collapsed(widget_id: int, value: bool) -> void:
	_ensure(widget_id)
	if bool(states[widget_id].collapsed) == value: return
	states[widget_id].collapsed = value
	_emit(widget_id)

func set_suppressed(widget_id: int, reason: StringName, value: bool) -> void:
	_ensure(widget_id)
	var suppressors: Dictionary = states[widget_id].suppressors
	if value: suppressors[reason] = true
	else: suppressors.erase(reason)
	_emit(widget_id)

func get_state(widget_id: int) -> Dictionary:
	_ensure(widget_id)
	var raw: Dictionary = states[widget_id]
	var policy: int = raw.policy
	var visible := false
	match policy:
		Policy.ALWAYS: visible = true
		Policy.CONTEXTUAL, Policy.COLLAPSED: visible = bool(raw.context_active) and bool(raw.user_visible)
		Policy.USER_TOGGLED: visible = bool(raw.user_visible)
		Policy.HIDDEN: visible = false
	if not (raw.suppressors as Dictionary).is_empty(): visible = false
	return {"widget_id": widget_id, "policy": policy, "visible": visible, "collapsed": bool(raw.collapsed), "context_active": bool(raw.context_active), "user_visible": bool(raw.user_visible), "suppressed": not (raw.suppressors as Dictionary).is_empty()}

func is_visible(widget_id: int) -> bool:
	return bool(get_state(widget_id).visible)

func is_collapsed(widget_id: int) -> bool:
	return bool(get_state(widget_id).collapsed)

func _ensure(widget_id: int) -> void:
	if not states.has(widget_id): register_widget(widget_id, Policy.HIDDEN)

func _emit(widget_id: int) -> void:
	widget_state_changed.emit(widget_id, get_state(widget_id))

static func widget_from_name(value: StringName) -> int:
	return Widget.keys().find(String(value))

static func policy_from_name(value: StringName) -> int:
	return Policy.keys().find(String(value))
