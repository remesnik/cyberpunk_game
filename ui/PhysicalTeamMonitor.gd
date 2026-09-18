class_name PhysicalTeamMonitor
extends PanelContainer

@onready var compact_roster: HBoxContainer = %CompactRoster
@onready var alert_label: Label = %AlertLabel
@onready var toggle_button: Button = %ToggleButton
@onready var detail_content: VBoxContainer = %DetailContent
@onready var team_detail: VBoxContainer = %TeamDetail
@onready var hacker_details: Label = %HackerDetails
@onready var selector: OptionButton = %TeamSelector
@onready var details: Label = %Details
@onready var encounter_label: Label = %EncounterLabel
@onready var wait_button: Button = %WaitButton
@onready var force_button: Button = %ForceButton
@onready var abort_button: Button = %AbortButton
@onready var alternate_button: Button = %AlternateButton
@onready var record_button: Button = %RecordButton

var expanded := false
var _team_ids: Array[StringName] = []
var _entries: Array[Dictionary] = []
var _roster_signature := ""
var _selected_entry: Dictionary = {}
var _alert_queue: Array[Dictionary] = []
var _active_alert: Dictionary = {}
var _alert_remaining := 0.0

func _ready() -> void:
	toggle_button.pressed.connect(toggle_expanded)
	selector.item_selected.connect(_on_selected)
	wait_button.pressed.connect(_decision.bind(TeamSupportEncounter.TeamDecision.WAIT))
	force_button.pressed.connect(_decision.bind(TeamSupportEncounter.TeamDecision.FORCE_ENTRY))
	abort_button.pressed.connect(_decision.bind(TeamSupportEncounter.TeamDecision.ABORT))
	alternate_button.pressed.connect(_decision.bind(TeamSupportEncounter.TeamDecision.ALTERNATE_ROUTE))
	record_button.pressed.connect(_record_telemetry)
	EventBus.tactical_status_alert.connect(_on_tactical_alert)
	EventBus.action_resolved.connect(_on_action_resolved)
	HudState.widget_state_changed.connect(_on_hud_state_changed)
	set_expanded(false)
	_refresh()

func _process(delta: float) -> void:
	_advance_alert(delta)
	_refresh()

func toggle_expanded() -> void:
	set_expanded(not expanded)

func set_expanded(value: bool) -> void:
	HudState.set_collapsed(HudState.Widget.TEAM_STATUS, not value)
	expanded = not HudState.is_collapsed(HudState.Widget.TEAM_STATUS)
	detail_content.visible = expanded
	toggle_button.text = "TEAM STATUS  -" if expanded else "TEAM STATUS  +"
	custom_minimum_size = Vector2(280.0, 250.0 if expanded else 34.0)

func _refresh() -> void:
	_entries = _build_tactical_entries()
	HudState.set_context_active(HudState.Widget.TEAM_STATUS, not _entries.is_empty() or not _active_alert.is_empty())
	visible = HudState.is_visible(HudState.Widget.TEAM_STATUS)
	if not visible:
		set_expanded(false)
		return
	var signature_parts := PackedStringArray()
	for entry: Dictionary in _entries: signature_parts.append("%s:%s:%s" % [entry.kind, entry.id, entry.status])
	var signature := "|".join(signature_parts)
	if signature != _roster_signature:
		_roster_signature = signature
		_rebuild_compact_roster()
	_rebuild_team_selector()
	_update_selected_details()

func _on_tactical_alert(event: Dictionary) -> void:
	if event.has("player_visible") and not bool(event.player_visible): return
	var type := StringName(event.get("type", &""))
	if type not in [&"TEAM_MEMBER_DETECTED", &"TEAM_MEMBER_UNDER_ATTACK", &"SAN_BREACHED", &"TEAM_MEMBER_DUMPED", &"COMMS_LOST", &"OBJECTIVE_COMPLETE", &"OBJECTIVE_COMPLETED", &"MISSION_COMPLETE", &"CRITICAL_HARDWARE_DAMAGE"]: return
	_alert_queue.append(event.duplicate(true))
	if _active_alert.is_empty(): _show_next_alert()

func _on_action_resolved(_request: ActionRequest, result: ActionResult) -> void:
	for event: Dictionary in result.events_produced: _on_tactical_alert(event)

func _show_next_alert() -> void:
	if _alert_queue.is_empty():
		_active_alert.clear(); alert_label.visible = false; return
	_active_alert = _alert_queue.pop_front()
	_alert_remaining = maxf(0.05, float(_active_alert.get("duration", 4.0)))
	var type_text := String(_active_alert.get("type", &"ALERT")).replace("_", " ")
	var subject := String(_active_alert.get("subject_id", "")).replace("_", " ")
	var message := String(_active_alert.get("message", type_text))
	alert_label.text = "ALERT // %s%s" % [subject + " // " if not subject.is_empty() else "", message]
	alert_label.add_theme_color_override("font_color", Color("ff496c") if _active_alert.get("severity", &"WARNING") == &"CRITICAL" else Color("ffc857"))
	alert_label.visible = true
	visible = true

func _advance_alert(delta: float) -> void:
	var remaining_delta := maxf(0.0, delta)
	while not _active_alert.is_empty() and remaining_delta >= _alert_remaining:
		remaining_delta -= _alert_remaining
		_active_alert.clear()
		_show_next_alert()
	if not _active_alert.is_empty(): _alert_remaining -= remaining_delta

func _on_hud_state_changed(widget_id: int, state: Dictionary) -> void:
	if widget_id != HudState.Widget.TEAM_STATUS: return
	visible = bool(state.visible)
	expanded = not bool(state.collapsed)
	detail_content.visible = visible and expanded
	toggle_button.text = "TEAM STATUS  -" if expanded else "TEAM STATUS  +"

func _build_tactical_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if Game.physical_team_manager != null and Game.realtime_world_clock != null:
		for view: Dictionary in Game.physical_team_manager.get_player_views(Game.realtime_world_clock.elapsed_seconds):
			var state := int(view.get("team_state", -1))
			var status := _physical_state_label(state, bool(view.get("stale", false)))
			var definition: PhysicalTeamDefinition = Game.physical_team_manager.definitions.get(view.get("team_id", &""))
			var names: PackedStringArray = []
			if definition != null:
				for member: PhysicalTeamMemberDefinition in definition.members: names.append(member.display_name if not member.display_name.is_empty() else String(member.id).replace("_", " "))
				if names.is_empty(): names.append(definition.display_name)
			else: names.append(String(view.get("team_id", "TEAM")).replace("_", " "))
			for name: String in names:
				result.append({"kind": &"PHYSICAL_TEAM", "id": view.team_id, "name": name.to_upper(), "status": status.text, "critical": status.critical, "view": view})
	if Game.player_knowledge != null:
		for record: Dictionary in Game.player_knowledge.hacker_records.values():
			if not bool(record.get("present", false)) or StringName(record.get("relationship", &"NEUTRAL")) not in [&"ALLY", &"FRIENDLY", &"CONTACT", &"GUIDE"]: continue
			var state := int(record.get("state", HackerNPC.State.OFFLINE))
			var warning := String(record.get("critical_warning", ""))
			var status := warning if not warning.is_empty() else ("ONLINE" if state == HackerNPC.State.CONNECTED else "SIGNAL LOST")
			result.append({"kind": &"HACKER", "id": record.get("id", &""), "name": String(record.get("callsign", record.get("display_name", "REMOTE"))).to_upper(), "status": status, "critical": not warning.is_empty() or state != HackerNPC.State.CONNECTED, "view": record})
	return result

func _physical_state_label(state: int, stale: bool) -> Dictionary:
	if stale: return {"text": "STALE", "critical": true}
	match state:
		PhysicalTeamInstance.State.LOST: return {"text": "DOWN", "critical": true}
		PhysicalTeamInstance.State.ENGAGED: return {"text": "ENGAGED!", "critical": true}
		PhysicalTeamInstance.State.COMPROMISED: return {"text": "TRACE!", "critical": true}
		PhysicalTeamInstance.State.HOLDING: return {"text": "HOLD", "critical": false}
		PhysicalTeamInstance.State.COMPLETE: return {"text": "CLEAR", "critical": false}
		PhysicalTeamInstance.State.STAGING: return {"text": "READY", "critical": false}
		_: return {"text": "BUSY", "critical": false}

func _rebuild_compact_roster() -> void:
	for child in compact_roster.get_children(): child.queue_free()
	for entry: Dictionary in _entries:
		var button := Button.new()
		button.text = "%s  %s" % [entry.name, entry.status]
		button.tooltip_text = "Open tactical status for %s" % entry.name
		if entry.critical: button.add_theme_color_override("font_color", Color("ff496c"))
		button.pressed.connect(_select_entry.bind(entry))
		compact_roster.add_child(button)

func _rebuild_team_selector() -> void:
	var ids: Array[StringName] = []
	for entry: Dictionary in _entries:
		if entry.kind == &"PHYSICAL_TEAM" and entry.id not in ids: ids.append(entry.id)
	if ids == _team_ids: return
	_team_ids = ids
	selector.clear()
	for team_id: StringName in _team_ids: selector.add_item(String(team_id).replace("_", " "))
	if not _team_ids.is_empty(): selector.select(0)

func _select_entry(entry: Dictionary) -> void:
	_selected_entry = entry
	set_expanded(true)
	_update_selected_details()

func _on_selected(_index: int) -> void:
	if selector.selected >= 0 and selector.selected < _team_ids.size():
		for entry: Dictionary in _entries:
			if entry.kind == &"PHYSICAL_TEAM" and entry.id == _team_ids[selector.selected]: _selected_entry = entry; break
	_update_selected_details()

func _update_selected_details() -> void:
	if _selected_entry.is_empty() and not _entries.is_empty(): _selected_entry = _entries[0]
	var is_team: bool = StringName(_selected_entry.get("kind", &"")) == &"PHYSICAL_TEAM"
	team_detail.visible = is_team
	hacker_details.visible = not is_team
	if not is_team:
		var view: Dictionary = _selected_entry.get("view", {})
		hacker_details.text = "%s // %s\nRELATION // %s\nLAST KNOWN NODE // %s" % [_selected_entry.get("name", "REMOTE"), _selected_entry.get("status", "UNKNOWN"), String(view.get("relationship", "UNKNOWN")), String(view.get("node_id", "UNKNOWN"))]
		return
	_update_details()
	_update_encounter()

func _update_details() -> void:
	var team_id: StringName = _selected_entry.get("id", &"")
	if team_id.is_empty() or Game.physical_team_knowledge == null:
		details.text = "NO TEAM CONTACTS"; record_button.disabled = true; return
	var view: Dictionary = Game.physical_team_knowledge.get_view(team_id, Game.realtime_world_clock.elapsed_seconds)
	var state_text: String = PhysicalTeamInstance.State.keys()[int(view.team_state)] if view.has("team_state") else "UNKNOWN"
	var confidence := int(round(float(view.get("confidence", 0.0)) * 100.0))
	details.text = "LAST CONTACT  %05.1fs AGO%s\nLAST KNOWN  %s\nCOMMS  %s\nSTATE  %s\nOBJECTIVE  %s\nCONFIDENCE  %03d%%" % [float(view.get("contact_age", 0.0)), " // STALE" if view.get("stale", false) else "", String(view.get("last_known_location", "UNKNOWN")), PhysicalTeamKnowledge.comms_label(int(view.get("comms_status", PhysicalTeamKnowledge.CommsStatus.UNKNOWN))), state_text, String(view.get("objective", "UNKNOWN")), confidence]
	record_button.disabled = Game.evidence_archive != null and Game.evidence_archive.is_recording_source(EvidenceRecord.SourceType.TEAM_TELEMETRY, team_id)

func _update_encounter() -> void:
	if Game.team_support_encounter == null:
		encounter_label.text = "NO ACTIVE ROUTE DECISION"; _set_decisions_disabled(true); return
	var encounter: TeamSupportEncounter = Game.team_support_encounter
	encounter_label.text = "DOOR_12 // %s\nSUSPICION // %03d" % [encounter.status_text(), encounter.security_suspicion]
	_set_decisions_disabled(encounter.state != TeamSupportEncounter.EncounterState.WAITING_AT_DOOR)

func _decision(decision: TeamSupportEncounter.TeamDecision) -> void:
	if Game.team_support_encounter != null: Game.team_support_encounter.choose_team_decision(decision)

func _record_telemetry() -> void:
	var team_id: StringName = _selected_entry.get("id", &"")
	if not team_id.is_empty(): Game.record_team_telemetry(team_id)

func _set_decisions_disabled(disabled: bool) -> void:
	wait_button.disabled = disabled; force_button.disabled = disabled; abort_button.disabled = disabled; alternate_button.disabled = disabled
