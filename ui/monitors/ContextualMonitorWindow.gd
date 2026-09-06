class_name ContextualMonitorWindow
extends Control

enum FeedType { VIDEO, COMMUNICATIONS, ALARMS, TELEMETRY, SENSOR, TEAM, AUDIO, CUSTOM }

const COMMS_MONITOR := preload("res://ui/CommsMonitor.tscn")
const VIDEO_MONITOR := preload("res://ui/VideoMonitor.tscn")
const ALARM_MONITOR := preload("res://ui/AlarmMonitor.tscn")

@onready var tabs: HBoxContainer = %FeedTabs
@onready var content_host: MarginContainer = %ContentHost
@onready var summary_label: Label = %SummaryLabel
@onready var full_panel: PanelContainer = %FullPanel
@onready var compact_indicator: Button = %CompactIndicator
@onready var collapse_button: Button = %CollapseButton

var providers: Dictionary = {}
var selected_type := -1
var _last_signature := ""
var collapsed := false
var _had_active_feeds := false
var _presentation_signature := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_register_defaults()
	compact_indicator.pressed.connect(expand)
	collapse_button.pressed.connect(collapse)
	HudState.widget_state_changed.connect(_on_hud_state_changed)
	_refresh_contents()

func _process(_delta: float) -> void:
	# Managers can be rebuilt when a session starts, so provider callables resolve
	# through Game each time rather than retaining stale runtime objects.
	_refresh_contents()

func register_feed_provider(type: FeedType, label: String, scene: PackedScene, active_ids: Callable) -> void:
	var wrapper := MarginContainer.new()
	wrapper.visible = false
	content_host.add_child(wrapper)
	var content := scene.instantiate() as Control
	if content.has_method("set") and type in [FeedType.COMMUNICATIONS, FeedType.ALARMS]: content.set("active_only", true)
	wrapper.add_child(content)
	providers[type] = {"label": label, "active_ids": active_ids, "wrapper": wrapper, "content": content}

func active_feed_count() -> int:
	var count := 0
	for type: int in providers:
		count += (providers[type].active_ids.call() as Array).size()
	return count

func collapse() -> void:
	if active_feed_count() <= 0: return
	HudState.set_collapsed(HudState.Widget.MONITOR, true)

func expand() -> void:
	if active_feed_count() <= 0: return
	HudState.set_collapsed(HudState.Widget.MONITOR, false)

func toggle() -> void:
	if active_feed_count() <= 0: return
	if collapsed: expand()
	else: collapse()

func _register_defaults() -> void:
	register_feed_provider(FeedType.VIDEO, "VIDEO", VIDEO_MONITOR, func() -> Array: return [Game.video_feed_manager.open_feed_id] if Game.video_feed_manager != null and not Game.video_feed_manager.open_feed_id.is_empty() else [])
	register_feed_provider(FeedType.COMMUNICATIONS, "COMMS", COMMS_MONITOR, func() -> Array:
		var result: Array = []
		if Game.comms_manager != null:
			for session: CommsSession in Game.comms_manager.sessions.values():
				if session.monitoring or session.listening: result.append(session.id)
		return result)
	register_feed_provider(FeedType.ALARMS, "ALARMS", ALARM_MONITOR, func() -> Array: return Game.physical_alarm_manager.monitored_alarm_ids.duplicate() if Game.physical_alarm_manager != null else [])

func _refresh_contents() -> void:
	if providers.is_empty(): return
	var active_types: Array[int] = []
	var signature_parts := PackedStringArray()
	for type: int in providers:
		var ids: Array = providers[type].active_ids.call()
		if not ids.is_empty(): active_types.append(type)
		signature_parts.append("%d:%s" % [type, ",".join(ids.map(func(id: Variant) -> String: return String(id)))])
	var signature := "|".join(signature_parts)
	var has_active := not active_types.is_empty()
	if has_active and not _had_active_feeds: HudState.set_collapsed(HudState.Widget.MONITOR, false)
	_had_active_feeds = has_active
	HudState.set_context_active(HudState.Widget.MONITOR, has_active)
	var manager_state := HudState.get_state(HudState.Widget.MONITOR)
	visible = bool(manager_state.visible)
	collapsed = bool(manager_state.collapsed)
	if not has_active: selected_type = -1
	elif selected_type not in active_types: selected_type = active_types[0]
	_apply_presentation()
	if signature == _last_signature: return
	_last_signature = signature
	for child in tabs.get_children():
		tabs.remove_child(child)
		child.queue_free()
	for type: int in providers:
		providers[type].wrapper.visible = visible and not collapsed and type == selected_type
	for type: int in active_types:
		var ids: Array = providers[type].active_ids.call()
		var button := Button.new()
		button.text = "%s%s" % [providers[type].label, " x%d" % ids.size() if ids.size() > 1 else ""]
		button.button_pressed = type == selected_type
		button.pressed.connect(_select_type.bind(type))
		tabs.add_child(button)
	summary_label.text = "%d ACTIVE FEED%s" % [active_feed_count(), "S" if active_feed_count() != 1 else ""]
	compact_indicator.text = "MONITOR // %d ACTIVE" % active_feed_count()

func _select_type(type: int) -> void:
	selected_type = type
	_last_signature = ""
	_refresh_contents()

func _apply_presentation() -> void:
	if full_panel == null: return
	full_panel.visible = visible and not collapsed
	compact_indicator.visible = visible and collapsed
	for type: int in providers:
		providers[type].wrapper.visible = visible and not collapsed and type == selected_type
	var signature := "%s:%s" % [visible, not collapsed]
	if signature != _presentation_signature:
		_presentation_signature = signature
		EventBus.monitor_presentation_changed.emit(visible, visible and not collapsed)
		HudState.set_suppressed(HudState.Widget.NODE_INSPECTOR, &"EXPANDED_MONITOR", visible and not collapsed)

func _on_hud_state_changed(widget_id: int, state: Dictionary) -> void:
	if widget_id != HudState.Widget.MONITOR: return
	visible = bool(state.visible)
	collapsed = bool(state.collapsed)
	_apply_presentation()
