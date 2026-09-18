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
var objective: Dictionary = {}

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
	EventBus.action_resolved.connect(_on_action)
	EventBus.network_position_changed.connect(_on_move)
	EventBus.network_time_advanced.connect(_on_time)
	active = true
	_schedule_beat()

func _schedule_beat() -> void:
	presented = false
	delay = float(beats[index].get("delay_seconds", 0))
	observed.clear()
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
		for event: Dictionary in observed:
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
	if rule.get("event_type", "") != event.get("event_type", ""): return false
	if rule.has("target_id") and String(rule.target_id) != String(event.get("target_id", "")): return false
	return int(event.get("units", 0)) >= int(rule.get("minimum_units", 0))

func _on_action(request: ActionRequest, result: ActionResult) -> void:
	if not active or not result.success: return
	if request.get_action_name() == "SCAN":
		var target: String = String(request.target.get("node_id", Game.player_network_position.current_node_id)) if request.target is Dictionary else String(request.target)
		observed.append({"event_type": "NODE_SCANNED", "target_id": target})

func _on_move(_from: StringName, target: StringName, _link: StringName) -> void:
	if active: observed.append({"event_type": "PLAYER_MOVED", "target_id": target})

func _on_time(units: int) -> void:
	if active: observed.append({"event_type": "NETWORK_TIME_ADVANCED", "units": units})
