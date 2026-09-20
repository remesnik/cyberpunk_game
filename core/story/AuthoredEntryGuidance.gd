class_name AuthoredEntryGuidance
extends Node
## Runs the authored entry sequence on the real network; no alternate tutorial map.
var state: PersistentGameState
var beats: Array = []
var index := 0
var delay := 0.0
var elapsed := 0.0
var active := false
var presented := false
var pending: Array[Dictionary] = []
var observed: Array[Dictionary] = []
var history: Array[Dictionary] = []
var objective: Dictionary = {}
var beat_started_event_index := 0

func configure(document: CyberspaceContentDocument, persistent: PersistentGameState, entry: StringName) -> void:
	state = persistent
	for sequence: Dictionary in document.story_sequences:
		var authored: Array = sequence.get("beats", [])
		if authored.is_empty(): continue
		var trigger: Dictionary = authored[0].get("trigger", {})
		if trigger.get("event_type") == "NODE_ENTERED" and StringName(trigger.get("target_id", "")) == entry:
			beats = authored.duplicate(true)
			break
	if beats.is_empty(): return
	var opening_lesson: Array = document.hud_guidance.get("opening_network_lesson", [])
	if not opening_lesson.is_empty():
		var authored_dialogue: Array = beats[0].get("dialogue", []).duplicate(true)
		var lesson_dialogue: Array = authored_dialogue
		for line_index: int in opening_lesson.size():
			lesson_dialogue.append({"speaker_id": &"LATCH", "text": String(opening_lesson[line_index]), "time": float(line_index + 1) * 2.4})
		beats[0]["dialogue"] = lesson_dialogue
	for insertion: Dictionary in document.hud_guidance.get("additional_beats", []):
		var after_id := StringName(insertion.get("insert_after", &""))
		for beat_index: int in beats.size():
			if StringName(beats[beat_index].get("id", &"")) == after_id:
				beats.insert(beat_index + 1, (insertion.get("beat", {}) as Dictionary).duplicate(true))
				break
	var overrides: Dictionary = document.hud_guidance.get("beat_overrides", {})
	for beat_index: int in beats.size():
		var beat_id := StringName(beats[beat_index].get("id", &""))
		if overrides.has(beat_id): beats[beat_index].merge((overrides[beat_id] as Dictionary).duplicate(true), true)
	for rule: Dictionary in document.tutorial_guidance_rules:
		if bool(rule.get("sequence_insertion", false)):
			var after_id := StringName(rule.get("insert_after", &""))
			for beat_index: int in beats.size():
				if StringName(beats[beat_index].get("id", &"")) == after_id:
					beats.insert(beat_index + 1, (rule.get("beat", {}) as Dictionary).duplicate(true)); break
		var override_id := StringName(rule.get("sequence_beat_override", &""))
		if override_id != &"":
			for beat_index: int in beats.size():
				if StringName(beats[beat_index].get("id", &"")) == override_id:
					beats[beat_index].merge((rule.get("patch", {}) as Dictionary).duplicate(true), true); break
	for authored_patch: Dictionary in document.tutorial_sequence_patches:
		var patch_id := StringName(authored_patch.get("beat_id", &""))
		for beat_index: int in beats.size():
			if StringName(beats[beat_index].get("id", &"")) == patch_id:
				beats[beat_index].merge((authored_patch.get("patch", {}) as Dictionary).duplicate(true), true); break
	for insertion: Dictionary in document.tutorial_stage_insertions:
		var after_id := StringName(insertion.get("insert_after", &""))
		for beat_index: int in beats.size():
			if StringName(beats[beat_index].get("id", &"")) == after_id:
				beats.insert(beat_index + 1, (insertion.get("beat", {}) as Dictionary).duplicate(true)); break
	for beat_index: int in beats.size():
		var beat_id := StringName(beats[beat_index].get("id", &""))
		if document.tutorial_beat_overrides.has(beat_id): beats[beat_index].merge((document.tutorial_beat_overrides[beat_id] as Dictionary).duplicate(true), true)
	for insertion: Dictionary in document.hard_gate_tutorial_insertions:
		var after_id := StringName(insertion.get("insert_after", &""))
		for beat_index: int in beats.size():
			if StringName(beats[beat_index].get("id", &"")) == after_id:
				beats.insert(beat_index + 1, (insertion.get("beat", {}) as Dictionary).duplicate(true)); break
	for insertion: Dictionary in document.data_tutorial_insertions:
		var after_id := StringName(insertion.get("insert_after", &""))
		for beat_index: int in beats.size():
			if StringName(beats[beat_index].get("id", &"")) == after_id:
				beats.insert(beat_index + 1, (insertion.get("beat", {}) as Dictionary).duplicate(true)); break
	EventBus.action_resolved.connect(_on_action)
	EventBus.network_position_changed.connect(_on_move)
	EventBus.network_time_advanced.connect(_on_time)
	EventBus.tutorial_gameplay_event.connect(_on_gameplay_event)
	EventBus.intrusion_lifecycle_changed.connect(_on_intrusion_lifecycle)
	active = true
	_schedule_beat()

func _schedule_beat() -> void:
	presented = false
	beat_started_event_index = history.size()
	delay = float(beats[index].get("delay_seconds", 0))
	objective = beats[index].get("objective", {}).duplicate(true)
	state.world_state["active_tutorial_objective"] = objective.duplicate(true)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not active or Game.game_domain != Game.GameDomain.CYBERSPACE: return
	elapsed += delta
	if not presented:
		delay -= delta
		if delay <= 0:
			presented = true
			if not objective.is_empty(): HudState.tutorial_objective_requested.emit(StringName(objective.id), String(objective.title), bool(objective.get("optional", false)))
			for line: Dictionary in beats[index].get("dialogue", []): pending.append({"at": elapsed + float(line.get("time", 0)), "line": line})
			for command: Dictionary in beats[index].get("commands", []): pending.append({"at": elapsed + float(command.get("delay_seconds", 0)), "command": command})
	var due := pending.filter(func(item: Dictionary) -> bool: return float(item.at) <= elapsed)
	for item: Dictionary in due:
		pending.erase(item)
		if item.has("line"):
			HudState.diegetic_lesson_requested.emit(StringName(item.line.get("speaker_id", "LATCH")), StringName(beats[index].id), [String(item.line.text)])
		elif Game.hacker_npc_manager != null:
			Game.hacker_npc_manager.execute_scripted_command(StringName(item.command.get("actor_id", "")), item.command)
	if presented:
		var candidates: Array = history.slice(beat_started_event_index) if bool(beats[index].get("require_fresh_event", false)) else history
		for event: Dictionary in candidates:
			if _matches(beats[index].get("completion", {}), event):
				if not objective.is_empty(): HudState.tutorial_objective_completed.emit(StringName(objective.id))
				index += 1
				pending.clear()
				if index >= beats.size():
					active = false
					state.world_state["active_tutorial_objective"] = {}
				else: _schedule_beat()
				break

func _matches(rule: Dictionary, event: Dictionary) -> bool:
	if StringName(rule.get("operator", &"")) == &"ANY":
		return (rule.get("events", []) as Array).any(func(candidate: Dictionary) -> bool: return _matches(candidate, event))
	if rule.get("event_type", "") != event.get("event_type", ""): return false
	if rule.has("target_id") and String(rule.target_id) != String(event.get("target_id", "")): return false
	return int(event.get("units", 0)) >= int(rule.get("minimum_units", 0))

func _on_action(request: ActionRequest, result: ActionResult) -> void:
	if not active or not result.success: return
	if request.get_action_name() == "SCAN":
		var target: String = String(request.target.get("node_id", Game.player_network_position.current_node_id)) if request.target is Dictionary else String(request.target)
		_record({"event_type": "NODE_SCANNED", "target_id": target})
	for raw: Variant in result.events:
		if raw is not Dictionary: continue
		var event: Dictionary = raw.duplicate(true)
		event["event_type"] = StringName(event.get("event_type", event.get("type", &"")))
		event["target_id"] = StringName(event.get("target_id", event.get("destination_node_id", event.get("node_id", event.get("resource_id", event.get("file_id", event.get("ice_id", &"")))))))
		_record(event)

func _on_move(_from: StringName, target: StringName, _link: StringName) -> void:
	if active:
		_record({"event_type": "PLAYER_MOVED", "target_id": target})
		_record({"event_type": "PATH_TRAVERSED", "target_id": target})

func _on_time(units: int) -> void:
	if active: _record({"event_type": "NETWORK_TIME_ADVANCED", "units": units})

func _on_gameplay_event(event: Dictionary) -> void:
	if active: _record(event)

func _on_intrusion_lifecycle(_id: StringName, _previous: int, current: int) -> void:
	if not active: return
	var states: Array = IntrusionSession.Lifecycle.keys()
	if current >= 0 and current < states.size(): _record({"event_type": StringName("INTRUSION_" + String(states[current]))})

func _record(event: Dictionary) -> void:
	observed.append(event.duplicate(true))
	history.append(event.duplicate(true))
	if history.size() > 128: history.pop_front()
