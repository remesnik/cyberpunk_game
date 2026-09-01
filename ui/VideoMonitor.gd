class_name VideoMonitor
extends PanelContainer

@onready var selector: OptionButton = %FeedSelector
@onready var camera_label: Label = %CameraLabel
@onready var timestamp_label: Label = %TimestampLabel
@onready var state_label: Label = %StateLabel
@onready var viewport: MockVideoViewport = %MockViewport
@onready var open_button: Button = %OpenButton
@onready var close_button: Button = %CloseButton
@onready var record_button: Button = %RecordButton
@onready var disable_button: Button = %DisableButton
@onready var restore_button: Button = %RestoreButton
@onready var freeze_button: Button = %FreezeButton
@onready var loop_button: Button = %LoopButton
@onready var spoof_button: Button = %SpoofButton

var _feed_ids: Array[StringName] = []


func _ready() -> void:
	selector.item_selected.connect(_select_feed)
	open_button.pressed.connect(_open_selected)
	close_button.pressed.connect(_close)
	record_button.pressed.connect(_record)
	disable_button.pressed.connect(_command.bind(VideoFeedActionDefinition.Command.DISABLE))
	restore_button.pressed.connect(_command.bind(VideoFeedActionDefinition.Command.RESTORE))
	freeze_button.pressed.connect(_command.bind(VideoFeedActionDefinition.Command.FREEZE))
	loop_button.pressed.connect(_command.bind(VideoFeedActionDefinition.Command.LOOP))
	spoof_button.pressed.connect(_command.bind(VideoFeedActionDefinition.Command.SPOOF))
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if Game.video_feed_manager == null:
		visible = false
		return
	var feeds: Array = Game.video_feed_manager.get_discovered_feeds()
	var ids: Array[StringName] = []
	for session: VideoFeedSession in feeds:
		ids.append(session.definition.id)
	visible = not ids.is_empty()
	if ids != _feed_ids:
		_feed_ids = ids
		selector.clear()
		for session: VideoFeedSession in feeds:
			selector.add_item(session.definition.display_name.to_upper())
		if not ids.is_empty():
			_select_feed(0)
	var session: VideoFeedSession = Game.video_feed_manager.get_open_session()
	viewport.set_session(session)
	if session == null:
		camera_label.text = "CAMERA MONITOR // CLOSED"
		timestamp_label.text = "--:--.--"
		state_label.text = "SELECT A DISCOVERED FEED"
		close_button.disabled = true
		record_button.disabled = true
		_set_command_buttons_disabled(true)
		return
	var observer_view := session.get_observer_view()
	camera_label.text = "%s // %s" % [session.definition.id, session.definition.camera_type_label()]
	timestamp_label.text = _format_time(float(observer_view.get("time", session.elapsed_time)))
	state_label.text = "%s // %s%s // SUSPICION %03d" % [VideoFeedState.label(session.feed_state), String(observer_view.get("state", "NO SIGNAL")), " // REC" if session.player_recording else "", Game.video_feed_manager.total_security_suspicion]
	close_button.disabled = false
	record_button.disabled = not session.definition.can_record or session.player_recording
	_set_command_buttons_disabled(false)
	disable_button.disabled = not session.definition.can_disable or session.feed_state == VideoFeedState.Value.OFFLINE
	restore_button.disabled = session.feed_state == VideoFeedState.Value.LIVE
	loop_button.disabled = not session.definition.can_replay


func _select_feed(index: int) -> void:
	if index < 0 or index >= _feed_ids.size():
		open_button.disabled = true
		return
	var session: VideoFeedSession = Game.video_feed_manager.sessions[_feed_ids[index]]
	open_button.disabled = not session.definition.player_access


func _open_selected() -> void:
	if selector.selected >= 0 and selector.selected < _feed_ids.size():
		Game.request_video_feed_action(_feed_ids[selector.selected], VideoFeedActionDefinition.Command.MONITOR)


func _close() -> void:
	Game.video_feed_manager.close_monitor()


func _record() -> void:
	var session: VideoFeedSession = Game.video_feed_manager.get_open_session()
	if session != null:
		Game.request_video_feed_action(session.definition.id, VideoFeedActionDefinition.Command.RECORD)


func _command(command: VideoFeedActionDefinition.Command) -> void:
	var session: VideoFeedSession = Game.video_feed_manager.get_open_session()
	if session != null:
		Game.request_video_feed_action(session.definition.id, command)


func _set_command_buttons_disabled(disabled: bool) -> void:
	disable_button.disabled = disabled
	restore_button.disabled = disabled
	freeze_button.disabled = disabled
	loop_button.disabled = disabled
	spoof_button.disabled = disabled


func _format_time(seconds: float) -> String:
	return "%02d:%02d.%02d" % [int(seconds) / 60, int(seconds) % 60, int(seconds * 100.0) % 100]
