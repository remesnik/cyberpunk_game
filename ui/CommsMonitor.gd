class_name CommsMonitor
extends PanelContainer

@onready var channel_label: Label = %ChannelLabel
@onready var status_label: Label = %StatusLabel
@onready var transcript: RichTextLabel = %Transcript
@onready var access_label: Label = %AccessLabel
@onready var monitor_button: Button = %MonitorButton
@onready var listen_button: Button = %ListenButton
@onready var stop_button: Button = %StopButton
@onready var record_button: Button = %RecordButton
@onready var mark_button: Button = %MarkButton
@onready var inject_button: Button = %InjectButton
@onready var outbound_target: OptionButton = %OutboundTarget
@onready var outbound_choice: OptionButton = %OutboundChoice
@onready var call_button: Button = %CallButton

var _session_id: StringName
var _outbound_target_ids: Array[StringName] = []
var _outbound_choice_ids: Array[StringName] = []
@export var active_only := false


func _ready() -> void:
	monitor_button.pressed.connect(_monitor)
	listen_button.pressed.connect(_listen)
	stop_button.pressed.connect(_stop)
	record_button.pressed.connect(_record)
	mark_button.pressed.connect(_mark)
	inject_button.pressed.connect(_inject)
	outbound_target.item_selected.connect(_on_outbound_target_selected)
	call_button.pressed.connect(_call_outbound)
	if Game.comms_manager != null:
		Game.comms_manager.monitor_changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if Game.comms_manager == null:
		visible = false
		return
	_refresh_outbound()
	var sessions: Array = Game.comms_manager.get_available_sessions()
	if active_only: sessions = sessions.filter(func(session: CommsSession) -> bool: return session.monitoring or session.listening)
	visible = not sessions.is_empty() or not _outbound_target_ids.is_empty()
	if sessions.is_empty():
		channel_label.text = "OUTBOUND PBX // READY"
		status_label.text = "SELECT AN AUTHORED TARGET"
		access_label.text = "CALLING USES REALTIME // CYBER TICK UNAFFECTED"
		return
	var session: CommsSession = sessions[0]
	for candidate: CommsSession in sessions:
		if candidate.id == Game.comms_manager.active_session_id:
			session = candidate
			break
	_session_id = session.id
	var channel: CommsChannelDefinition = Game.comms_manager.channels[session.channel_id]
	channel_label.text = "%s // %s" % [channel.type_label(), channel.display_name.to_upper()]
	var monitor_access: CommsAccessResult = Game.comms_manager.evaluate_access(session.id, CommsAccessResult.Operation.MONITOR)
	var intercept_access: CommsAccessResult = Game.comms_manager.evaluate_access(session.id, CommsAccessResult.Operation.INTERCEPT)
	var record_access: CommsAccessResult = Game.comms_manager.evaluate_access(session.id, CommsAccessResult.Operation.RECORD)
	var inject_access: CommsAccessResult = Game.comms_manager.evaluate_access(session.id, CommsAccessResult.Operation.INJECT)
	if session.monitoring:
		var participant_names: PackedStringArray = []
		for participant_id: StringName in session.participants:
			var participant: CommsParticipantDefinition = Game.comms_manager.participants.get(participant_id)
			if participant != null:
				participant_names.append(participant.callsign if not participant.callsign.is_empty() else participant.display_name)
		var duration_text := "%05.2fs" % session.duration if session.duration >= 0.0 else "OPEN"
		status_label.text = "%05.2fs / %s  %s%s\nSIGNAL ACTIVE // %s" % [session.elapsed_time, duration_text, "INTERCEPT" if session.listening else "MONITOR", "  REC" if session.recording else "", ", ".join(participant_names) if not participant_names.is_empty() else "PARTICIPANTS UNKNOWN"]
	else:
		status_label.text = "DISCOVERED // METADATA NOT MONITORED"
	access_label.text = "%s\n%s\n%s\n%s" % [monitor_access.status_text(), intercept_access.status_text(), record_access.status_text(), inject_access.status_text()]
	monitor_button.disabled = not monitor_access.available or session.monitoring or session.completed
	listen_button.disabled = not intercept_access.available or session.listening or session.completed
	stop_button.disabled = not session.monitoring
	record_button.disabled = not record_access.available or session.recording or session.completed
	mark_button.disabled = not monitor_access.available
	inject_button.disabled = true
	var lines := session.transcript_for_monitor()
	transcript.clear()
	if lines.is_empty():
		transcript.append_text("[color=#668899]No captured transcript. Live channel continues.[/color]")
	else:
		for line: Dictionary in lines:
			var timestamp := float(line.time)
			transcript.append_text("[color=#56e8ff]%02d:%02d[/color]  [color=#ffcc66]%s[/color]\n%s\n" % [int(timestamp) / 60, int(timestamp) % 60, String(line.speaker_id), String(line.text)])


func _listen() -> void:
	Game.comms_manager.listen(_session_id)


func _monitor() -> void:
	Game.comms_manager.monitor(_session_id)


func _stop() -> void:
	Game.comms_manager.stop_listening()


func _record() -> void:
	Game.comms_manager.record(_session_id)


func _mark() -> void:
	Game.comms_manager.mark_important(_session_id)


func _inject() -> void:
	Game.comms_manager.inject(_session_id)


func _refresh_outbound() -> void:
	if Game.outbound_comms_manager == null:
		return
	var targets: Array = Game.outbound_comms_manager.get_available_targets()
	var ids: Array[StringName] = []
	for target: OutboundCommsTargetDefinition in targets:
		ids.append(target.id)
	if ids == _outbound_target_ids:
		return
	_outbound_target_ids = ids
	outbound_target.clear()
	for target: OutboundCommsTargetDefinition in targets:
		outbound_target.add_item(target.display_name.to_upper())
	_on_outbound_target_selected(0)


func _on_outbound_target_selected(index: int) -> void:
	_outbound_choice_ids.clear()
	outbound_choice.clear()
	if index < 0 or index >= _outbound_target_ids.size():
		call_button.disabled = true
		return
	var target: OutboundCommsTargetDefinition = Game.outbound_comms_manager.targets[_outbound_target_ids[index]]
	for choice: Dictionary in target.choices:
		_outbound_choice_ids.append(choice.id)
		outbound_choice.add_item(choice.text)
	call_button.disabled = _outbound_choice_ids.is_empty()


func _call_outbound() -> void:
	var target_index := outbound_target.selected
	var choice_index := outbound_choice.selected
	if target_index < 0 or target_index >= _outbound_target_ids.size() or choice_index < 0 or choice_index >= _outbound_choice_ids.size():
		return
	var target: OutboundCommsTargetDefinition = Game.outbound_comms_manager.targets[_outbound_target_ids[target_index]]
	var action := OutboundCommsAction.new(OutboundCommsAction.ActionType.CALL, target.target_type, target.id, _outbound_choice_ids[choice_index])
	Game.outbound_comms_manager.submit(action)
