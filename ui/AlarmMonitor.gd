class_name AlarmMonitor
extends PanelContainer

@onready var summary_label: Label = %SummaryLabel
@onready var alarm_selector: OptionButton = %AlarmSelector
@onready var detail_label: Label = %DetailLabel
@onready var acknowledge_button: Button = %AcknowledgeButton
@onready var silence_button: Button = %SilenceButton
@onready var bypass_button: Button = %BypassButton
@onready var restore_button: Button = %RestoreButton
@onready var trigger_button: Button = %TriggerButton
@onready var record_button: Button = %RecordButton

var _alarm_ids: Array[StringName] = []


func _ready() -> void:
	alarm_selector.item_selected.connect(_on_selected)
	acknowledge_button.pressed.connect(_command.bind(PhysicalAlarmDefinition.Command.ACKNOWLEDGE))
	silence_button.pressed.connect(_command.bind(PhysicalAlarmDefinition.Command.SILENCE))
	bypass_button.pressed.connect(_command.bind(PhysicalAlarmDefinition.Command.BYPASS))
	restore_button.pressed.connect(_command.bind(PhysicalAlarmDefinition.Command.RESTORE))
	trigger_button.pressed.connect(_command.bind(PhysicalAlarmDefinition.Command.TRIGGER))
	record_button.pressed.connect(_record_log)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if Game.physical_alarm_manager == null:
		visible = false
		return
	var alarms: Array = Game.physical_alarm_manager.get_discovered_alarms()
	visible = not alarms.is_empty()
	var ids: Array[StringName] = []
	var active_count := 0
	for alarm: PhysicalAlarmInstance in alarms:
		ids.append(alarm.definition.id)
		if alarm.state != PhysicalAlarmInstance.State.NORMAL:
			active_count += 1
	if ids != _alarm_ids:
		_alarm_ids = ids
		alarm_selector.clear()
		for alarm: PhysicalAlarmInstance in alarms:
			alarm_selector.add_item("%s // %s" % [alarm.definition.display_name.to_upper(), alarm.state_label()])
		if not ids.is_empty():
			alarm_selector.select(0)
	else:
		for index in alarms.size():
			alarm_selector.set_item_text(index, "%s // %s" % [alarms[index].definition.display_name.to_upper(), alarms[index].state_label()])
	summary_label.text = "ALARM MONITOR // ACTIVE %02d" % active_count
	_update_detail()


func _on_selected(_index: int) -> void:
	_update_detail()


func _update_detail() -> void:
	var instance := _selected_alarm()
	if instance == null:
		detail_label.text = "NO ALARM ENDPOINTS DISCOVERED"
		_set_buttons(true)
		return
	detail_label.text = "%s // %s\nREALTIME %06.2fs\nDETECTION %s // ALERT %s\nEVENTS %d" % [
		instance.definition.type_label(), instance.state_label(), instance.elapsed_time,
		"ENABLED" if instance.detection_enabled else "BYPASSED",
		"PRESENTING" if instance.alert_presenting else "QUIET",
		instance.detection_count,
	]
	_set_buttons(false)
	acknowledge_button.disabled = instance.state not in [PhysicalAlarmInstance.State.TRIGGERED, PhysicalAlarmInstance.State.PREALARM, PhysicalAlarmInstance.State.SILENCED]
	silence_button.disabled = instance.state not in [PhysicalAlarmInstance.State.TRIGGERED, PhysicalAlarmInstance.State.PREALARM, PhysicalAlarmInstance.State.ACKNOWLEDGED]
	restore_button.disabled = instance.state == PhysicalAlarmInstance.State.NORMAL
	record_button.disabled = Game.evidence_archive != null and Game.evidence_archive.is_recording_source(EvidenceRecord.SourceType.ALARM_LOG, instance.definition.id)


func _selected_alarm() -> PhysicalAlarmInstance:
	var index := alarm_selector.selected
	if index < 0 or index >= _alarm_ids.size():
		return null
	return Game.physical_alarm_manager.instances.get(_alarm_ids[index])


func _command(command: PhysicalAlarmDefinition.Command) -> void:
	var instance := _selected_alarm()
	if instance != null:
		Game.physical_alarm_manager.execute_command(instance.definition.id, command)


func _record_log() -> void:
	var instance := _selected_alarm()
	if instance != null:
		Game.record_alarm_log(instance.definition.id)


func _set_buttons(disabled: bool) -> void:
	acknowledge_button.disabled = disabled
	silence_button.disabled = disabled
	bypass_button.disabled = disabled
	restore_button.disabled = disabled
	trigger_button.disabled = disabled
	record_button.disabled = disabled
