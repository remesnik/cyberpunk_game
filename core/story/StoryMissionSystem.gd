class_name StoryMissionSystem
extends RefCounted
## Persistent authored missions driven by normalized gameplay/story events.

const LOCKED := &"LOCKED"
const AVAILABLE := &"AVAILABLE"
const ACTIVE := &"ACTIVE"
const SUCCESS := &"SUCCESS"
const FAILURE := &"FAILURE"
const COMPLETED := &"COMPLETED"

signal mission_available(mission_id: StringName)
signal mission_started(mission_id: StringName)
signal objective_changed(mission_id: StringName, objective: Dictionary)
signal mission_resolved(result: MissionResult)

var story_state: StoryState
var story_events: StoryEventSystem
var definitions: Dictionary = {}
var active_mission_id: StringName
var active_run: Dictionary = {}

func configure(state: PersistentGameState, events: StoryEventSystem = null) -> void:
	story_state = StoryState.new(state); story_events = events
	for key: String in ["mission_runs", "mission_results", "mission_reward_claims"]:
		if not story_state.game_state.campaign_state.get(key) is Dictionary: story_state.game_state.campaign_state[key] = {}
	active_run = (story_state.game_state.campaign_state.get("active_mission_run", {}) as Dictionary).duplicate(true)
	active_mission_id = StringName(active_run.get("mission_id", &""))

func load_file(path: String) -> Array[String]:
	if not FileAccess.file_exists(path): return ["Mission catalog not found: %s" % path]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array: return ["Mission catalog must contain an array: %s" % path]
	var errors: Array[String] = []
	for value: Variant in parsed:
		if not value is Dictionary: errors.append("Mission catalog contains a non-object entry."); continue
		var definition := MissionDefinition.from_dict(value); errors.append_array(add_mission(definition))
	return errors

func add_mission(definition: MissionDefinition) -> Array[String]:
	if definition == null: return ["Cannot register a null mission."]
	var errors := definition.validate()
	if definitions.has(definition.mission_id): errors.append("Duplicate mission '%s'." % definition.mission_id)
	if errors.is_empty():
		definitions[definition.mission_id] = definition
		for alias: StringName in definition.aliases:
			if not alias.is_empty(): definitions[alias] = definition
		_register_result_rules(definition)
		_refresh_definition_availability(definition)
	return errors

func refresh_availability() -> void:
	var seen: Dictionary = {}
	for value: Variant in definitions.values():
		var definition := value as MissionDefinition
		if definition == null or seen.has(definition.mission_id): continue
		seen[definition.mission_id] = true; _refresh_definition_availability(definition)

func _refresh_definition_availability(definition: MissionDefinition) -> void:
	if status(definition.mission_id) != LOCKED: return
	var required: Array = definition.story_metadata.get("availability_flags", [])
	if bool(definition.story_metadata.get("initially_available", false)) or (not required.is_empty() and required.all(func(flag: Variant) -> bool: return story_state.get_flag(StringName(flag)))): make_available(definition.mission_id)

func status(mission_id: StringName) -> StringName:
	mission_id = _canonical_id(mission_id)
	var stored := story_state.get_mission_status(mission_id).to_upper()
	return AVAILABLE if stored == &"UNLOCKED" else stored

func make_available(mission_id: StringName) -> bool:
	mission_id = _canonical_id(mission_id)
	if not definitions.has(mission_id) or status(mission_id) not in [LOCKED, FAILURE]: return false
	story_state.set_mission_status(mission_id, AVAILABLE); mission_available.emit(mission_id); return true

func start_mission(mission_id: StringName) -> Dictionary:
	mission_id = _canonical_id(mission_id)
	if not definitions.has(mission_id): return _failure("Unknown mission '%s'." % mission_id)
	if not active_mission_id.is_empty(): return _failure("Another authored mission is already active.")
	if status(mission_id) != AVAILABLE: return _failure("Mission '%s' is not available." % mission_id)
	var definition: MissionDefinition = definitions[mission_id]
	var objectives: Dictionary = {}
	for objective: ObjectiveDefinition in definition.all_objectives(): objectives[objective.objective_id] = objective.initial_state()
	active_run = {"mission_id": mission_id, "objectives": objectives, "events": [], "files_extracted": [], "targets_scanned": [], "services_disabled": [], "stream_intercepts": [], "contacts_helped": [], "trace": 0, "alarm_triggered": false, "explicit_failure": false, "started_at": Time.get_unix_time_from_system()}
	active_mission_id = mission_id; story_state.set_mission_status(mission_id, ACTIVE); _persist_run(); mission_started.emit(mission_id)
	return {"success": true, "mission_id": mission_id, "entry_network": definition.entry_network, "briefing": definition.briefing_view()}

func observe(event_name: StringName, context: Dictionary = {}) -> Array[Dictionary]:
	if active_mission_id.is_empty() or not definitions.has(active_mission_id): return []
	var event := context.duplicate(true); event["event"] = event_name; active_run.events.append(event)
	_record_run_fact(event_name, context)
	var changed: Array[Dictionary] = []; var definition: MissionDefinition = definitions[active_mission_id]
	for objective: ObjectiveDefinition in definition.all_objectives():
		var current: Dictionary = active_run.objectives.get(objective.objective_id, {})
		if current.get("state") != ObjectiveDefinition.ACTIVE or objective.expected_event() != event_name or not _target_matches(objective, context): continue
		if objective.objective_type in [&"AVOID_ALARM", &"AVOID_TRACE"]: current["state"] = ObjectiveDefinition.FAILED
		else:
			current["progress"] = mini(objective.required_progress, int(current.get("progress", 0)) + int(context.get("amount", 1)))
			if int(current.progress) >= objective.required_progress: current["state"] = ObjectiveDefinition.COMPLETED
		active_run.objectives[objective.objective_id] = current; changed.append(current.duplicate(true)); objective_changed.emit(active_mission_id, current.duplicate(true))
	for condition: Dictionary in definition.failure_conditions:
		if StringName(condition.get("event", &"")) == event_name and _context_matches(condition, context): active_run["explicit_failure"] = true
	_persist_run()
	return changed

func resolve_active_mission() -> Dictionary:
	if active_mission_id.is_empty() or not definitions.has(active_mission_id): return _failure("No authored mission is active.")
	var definition: MissionDefinition = definitions[active_mission_id]
	for objective: ObjectiveDefinition in definition.all_objectives():
		if objective.objective_type not in [&"AVOID_ALARM", &"AVOID_TRACE"]: continue
		var avoidance: Dictionary = active_run.objectives.get(objective.objective_id, {})
		if avoidance.get("state") == ObjectiveDefinition.ACTIVE: avoidance["state"] = ObjectiveDefinition.COMPLETED; active_run.objectives[objective.objective_id] = avoidance
	var primary: Array[Dictionary] = _states(definition.primary_objectives); var optional: Array[Dictionary] = _states(definition.optional_objectives); var hidden: Array[Dictionary] = _states(definition.hidden_objectives)
	var success := not bool(active_run.get("explicit_failure", false)) and primary.all(func(item: Dictionary) -> bool: return item.state == ObjectiveDefinition.COMPLETED)
	var result := MissionResult.new(); result.mission_id = active_mission_id; result.success = success; result.primary_objectives = primary; result.optional_objectives = optional; result.hidden_objectives = hidden
	result.trace_outcome = int(active_run.get("trace", 0)); result.alarm_state = bool(active_run.get("alarm_triggered", false)); result.files_extracted.assign(active_run.get("files_extracted", [])); result.targets_scanned.assign(active_run.get("targets_scanned", [])); result.services_disabled.assign(active_run.get("services_disabled", [])); result.stream_intercepts.assign(active_run.get("stream_intercepts", [])); result.contacts_helped.assign(active_run.get("contacts_helped", []))
	result.trace_result = StringName(active_run.get("trace_result", &"CLEAR")); result.warden_state = StringName(active_run.get("warden_state", &"NOT_ENCOUNTERED")); result.primary_objective_completed = primary.all(func(item: Dictionary) -> bool: return item.state == ObjectiveDefinition.COMPLETED)
	var result_fields: Dictionary = definition.story_metadata.get("result_fields", {})
	result.personnel_file_acquired = result.files_extracted.has(StringName(result_fields.get("personnel_file", &""))); result.unknown_ice_scanned = result.targets_scanned.has(StringName(result_fields.get("unknown_ice", &""))); result.executive_comms_intercepted = result.stream_intercepts.has(StringName(result_fields.get("executive_comms", &"")))
	if success: result.ic_earned = _apply_reward_once(definition)
	var flags_before: Dictionary = story_state.game_state.campaign_state.get("story_flags", {}).duplicate(true)
	if story_events != null: story_events.publish(&"mission_result", result.to_dict())
	for flag: Variant in story_state.game_state.campaign_state.get("story_flags", {}):
		if bool(story_state.get_flag(StringName(flag))) and not bool(flags_before.get(flag, false)): result.story_flags_generated.append(StringName(flag))
	result.consequences.assign(definition.story_metadata.get("success_consequences" if success else "failure_consequences", []))
	var results: Dictionary = story_state.game_state.campaign_state.mission_results; results[active_mission_id] = result.to_dict(); story_state.game_state.campaign_state["mission_results"] = results
	var runs: Dictionary = story_state.game_state.campaign_state.mission_runs; var history: Array = runs.get(active_mission_id, []); history.append(result.to_dict()); runs[active_mission_id] = history; story_state.game_state.campaign_state["mission_runs"] = runs
	story_state.set_mission_status(active_mission_id, SUCCESS if success else FAILURE)
	active_mission_id = &""; active_run = {}; story_state.game_state.campaign_state["active_mission_run"] = {}; story_state.game_state.emit_changed(); mission_resolved.emit(result)
	return {"success": true, "result": result, "debrief": result.debrief_view(definition.title)}

func briefing(mission_id: StringName) -> Dictionary:
	mission_id = _canonical_id(mission_id)
	if not definitions.has(mission_id): return {}
	return (definitions[mission_id] as MissionDefinition).briefing_view()
func latest_result(mission_id: StringName) -> MissionResult:
	mission_id = _canonical_id(mission_id)
	var data: Dictionary = story_state.game_state.campaign_state.get("mission_results", {}).get(mission_id, {})
	return MissionResult.from_dict(data) if not data.is_empty() else null
func debrief(mission_id: StringName) -> Dictionary:
	mission_id = _canonical_id(mission_id)
	var result := latest_result(mission_id); return result.debrief_view((definitions.get(mission_id) as MissionDefinition).title if definitions.has(mission_id) else "") if result != null else {}

func acknowledge_debrief(mission_id: StringName) -> bool:
	mission_id = _canonical_id(mission_id)
	if status(mission_id) != SUCCESS: return false
	story_state.set_mission_status(mission_id, COMPLETED)
	return true

func fail_active_run(reason: StringName, context: Dictionary = {}) -> Dictionary:
	if active_mission_id.is_empty(): return _failure("No authored mission is active.")
	active_run["explicit_failure"] = true
	active_run["failure_reason"] = reason
	if reason == &"trace":
		active_run["trace_result"] = &"TRACED"
		active_run["trace"] = maxi(int(active_run.get("trace", 0)), int(context.get("trace", 100)))
	elif reason == &"abort": active_run["trace_result"] = &"ABORTED"
	_persist_run()
	return resolve_active_mission()

func _register_result_rules(definition: MissionDefinition) -> void:
	if story_events == null: return
	for index in definition.story_result_rules.size():
		var rule: Dictionary = definition.story_result_rules[index]
		var authored := StoryEventDefinition.from_dict({"event_id": "%s_result_%02d" % [definition.mission_id, index], "trigger": "mission_result", "conditions": rule.get("conditions", {"all": []}), "actions": rule.get("actions", []), "repeat": "once", "priority": int(rule.get("priority", 0))})
		story_events.add_event(authored)
func _apply_reward_once(definition: MissionDefinition) -> int:
	var claims: Dictionary = story_state.game_state.campaign_state.mission_reward_claims
	if bool(claims.get(definition.mission_id, false)): return 0
	var amount := maxi(0, int(definition.reward_definition.get("ics", 0)))
	var optional_bonus := maxi(0, int(definition.reward_definition.get("optional_objective_bonus", 0)))
	for objective: ObjectiveDefinition in definition.optional_objectives:
		if (active_run.objectives.get(objective.objective_id, {}) as Dictionary).get("state") == ObjectiveDefinition.COMPLETED: amount += optional_bonus
	story_state.game_state.player_state["credits"] = int(story_state.game_state.player_state.get("credits", 0)) + amount; claims[definition.mission_id] = true; story_state.game_state.campaign_state["mission_reward_claims"] = claims; return amount
func _states(objectives: Array[ObjectiveDefinition]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for objective: ObjectiveDefinition in objectives: result.append((active_run.objectives.get(objective.objective_id, {}) as Dictionary).duplicate(true))
	return result
func _record_run_fact(event: StringName, context: Dictionary) -> void:
	var target := _context_target(context)
	match event:
		&"file_downloaded": _append_unique("files_extracted", target)
		&"target_scanned": _append_unique("targets_scanned", target)
		&"service_disabled": _append_unique("services_disabled", target)
		&"stream_intercepted": _append_unique("stream_intercepts", target)
		&"contact_helped": _append_unique("contacts_helped", target)
		&"alarm_triggered": active_run["alarm_triggered"] = true
		&"trace_completed": active_run["trace"] = maxi(int(active_run.get("trace", 0)), int(context.get("trace", context.get("value", 0))))
		&"boss_state_changed": active_run["warden_state"] = StringName(context.get("phase", active_run.get("warden_state", &"NOT_ENCOUNTERED")))
func _append_unique(key: String, value: StringName) -> void:
	if value.is_empty(): return
	var values: Array = active_run.get(key, []); if value not in values: values.append(value); active_run[key] = values
func _target_matches(objective: ObjectiveDefinition, context: Dictionary) -> bool:
	if not objective.target_id.is_empty() and objective.target_id != _context_target(context): return false
	if objective.condition.has("minimum") and float(context.get("value", context.get("trace", 0))) < float(objective.condition.minimum): return false
	if objective.condition.has("maximum") and float(context.get("value", context.get("trace", 0))) > float(objective.condition.maximum): return false
	return true
func _context_target(context: Dictionary) -> StringName:
	for key: String in ["target_id", "file_id", "resource_id", "service_id", "stream_id", "node_id", "ice_id", "contact_id"]:
		if context.has(key): return StringName(context[key])
	return &""
func _context_matches(condition: Dictionary, context: Dictionary) -> bool:
	var expected := StringName(condition.get("target_id", condition.get("target", &""))); return expected.is_empty() or expected == _context_target(context)
func _persist_run() -> void: story_state.game_state.campaign_state["active_mission_run"] = active_run.duplicate(true); story_state.game_state.emit_changed()
func _failure(reason: String) -> Dictionary: return {"success": false, "reason": reason}
func _canonical_id(mission_id: StringName) -> StringName:
	var definition := definitions.get(mission_id) as MissionDefinition
	return definition.mission_id if definition != null else mission_id
