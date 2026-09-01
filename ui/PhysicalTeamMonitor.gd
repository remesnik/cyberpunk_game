class_name PhysicalTeamMonitor
extends PanelContainer

@onready var selector: OptionButton = %TeamSelector
@onready var details: Label = %Details
@onready var encounter_label: Label = %EncounterLabel
@onready var wait_button: Button = %WaitButton
@onready var force_button: Button = %ForceButton
@onready var abort_button: Button = %AbortButton
@onready var alternate_button: Button = %AlternateButton
@onready var record_button: Button = %RecordButton

var _team_ids: Array[StringName] = []


func _ready() -> void:
	selector.item_selected.connect(_on_selected)
	wait_button.pressed.connect(_decision.bind(TeamSupportEncounter.TeamDecision.WAIT))
	force_button.pressed.connect(_decision.bind(TeamSupportEncounter.TeamDecision.FORCE_ENTRY))
	abort_button.pressed.connect(_decision.bind(TeamSupportEncounter.TeamDecision.ABORT))
	alternate_button.pressed.connect(_decision.bind(TeamSupportEncounter.TeamDecision.ALTERNATE_ROUTE))
	record_button.pressed.connect(_record_telemetry)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if Game.physical_team_manager == null or Game.realtime_world_clock == null:
		visible = false
		return
	var views: Array = Game.physical_team_manager.get_player_views(Game.realtime_world_clock.elapsed_seconds)
	var ids: Array[StringName] = []
	for view: Dictionary in views:
		ids.append(view.team_id)
	visible = not ids.is_empty()
	if ids != _team_ids:
		_team_ids = ids
		selector.clear()
		for view: Dictionary in views:
			selector.add_item(String(view.team_id).replace("_", " "))
		if not ids.is_empty():
			selector.select(0)
	_update_details()
	_update_encounter()


func _on_selected(_index: int) -> void:
	_update_details()


func _update_details() -> void:
	if selector.selected < 0 or selector.selected >= _team_ids.size():
		details.text = "NO TEAM CONTACTS"
		record_button.disabled = true
		return
	var view: Dictionary = Game.physical_team_knowledge.get_view(_team_ids[selector.selected], Game.realtime_world_clock.elapsed_seconds)
	var state_text := "UNKNOWN"
	if view.has("team_state"):
		state_text = PhysicalTeamInstance.State.keys()[int(view.team_state)]
	var confidence := int(round(float(view.get("confidence", 0.0)) * 100.0))
	details.text = "LAST CONTACT    %05.1fs AGO%s\nLAST KNOWN      %s\nCOMMS STATUS    %s\nTEAM STATE      %s\nOBJECTIVE       %s\nCONFIDENCE      %03d%%\nSOURCE          %s" % [
		float(view.get("contact_age", 0.0)), " // STALE" if view.get("stale", false) else "",
		String(view.get("last_known_location", "UNKNOWN")),
		PhysicalTeamKnowledge.comms_label(int(view.get("comms_status", PhysicalTeamKnowledge.CommsStatus.UNKNOWN))),
		state_text,
		String(view.get("objective", "UNKNOWN")),
		confidence,
		PhysicalTeamKnowledge.source_label(int(view.get("last_source", PhysicalTeamKnowledge.Source.VERBAL_REPORT))),
	]
	record_button.disabled = Game.evidence_archive != null and Game.evidence_archive.is_recording_source(EvidenceRecord.SourceType.TEAM_TELEMETRY, _team_ids[selector.selected])


func _update_encounter() -> void:
	if Game.team_support_encounter == null:
		encounter_label.text = "DOOR_12 // NO LINK"
		_set_decisions_disabled(true)
		return
	var encounter: TeamSupportEncounter = Game.team_support_encounter
	encounter_label.text = "DOOR_12 // %s\nCONTROL // ACCESS_CONTROL_SERVER\nSUSPICION // %03d" % [encounter.status_text(), encounter.security_suspicion]
	_set_decisions_disabled(encounter.state != TeamSupportEncounter.EncounterState.WAITING_AT_DOOR)


func _decision(decision: TeamSupportEncounter.TeamDecision) -> void:
	Game.team_support_encounter.choose_team_decision(decision)


func _record_telemetry() -> void:
	if selector.selected >= 0 and selector.selected < _team_ids.size():
		Game.record_team_telemetry(_team_ids[selector.selected])


func _set_decisions_disabled(disabled: bool) -> void:
	wait_button.disabled = disabled
	force_button.disabled = disabled
	abort_button.disabled = disabled
	alternate_button.disabled = disabled
