class_name RealtimeMonitorDock
extends Control

const COMMS_MONITOR := preload("res://ui/CommsMonitor.tscn")
const VIDEO_MONITOR := preload("res://ui/VideoMonitor.tscn")
const ALARM_MONITOR := preload("res://ui/AlarmMonitor.tscn")
const TEAM_MONITOR := preload("res://ui/PhysicalTeamMonitor.tscn")

@onready var left_dock: VBoxContainer = %LeftDock
@onready var right_dock: VBoxContainer = %RightDock
@onready var bottom_dock: HBoxContainer = %BottomDock

var widgets: Array[DockableMonitorWidget] = []


func _ready() -> void:
	# The dock itself never captures map input; only visible widget rectangles do.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_monitor("TEAM STATUS", TEAM_MONITOR.instantiate(), DockableMonitorWidget.DockSlot.LEFT, false)
	_add_monitor("COMMS", COMMS_MONITOR.instantiate(), DockableMonitorWidget.DockSlot.RIGHT, true)
	_add_monitor("VIDEO", VIDEO_MONITOR.instantiate(), DockableMonitorWidget.DockSlot.RIGHT, true)
	_add_monitor("ALARMS", ALARM_MONITOR.instantiate(), DockableMonitorWidget.DockSlot.RIGHT, true)


func _add_monitor(title: String, content: Control, slot: DockableMonitorWidget.DockSlot, minimized: bool) -> void:
	var widget := DockableMonitorWidget.new()
	_zone_for(slot).add_child(widget)
	widget.configure(title, content, slot, minimized)
	widget.dock_requested.connect(_move_widget)
	widgets.append(widget)


func _move_widget(widget: DockableMonitorWidget, slot: DockableMonitorWidget.DockSlot) -> void:
	widget.reparent(_zone_for(slot))
	widget.set_dock_slot(slot)


func _zone_for(slot: DockableMonitorWidget.DockSlot) -> Container:
	match slot:
		DockableMonitorWidget.DockSlot.LEFT:
			return left_dock
		DockableMonitorWidget.DockSlot.BOTTOM:
			return bottom_dock
		_:
			return right_dock


func get_pinned_monitors() -> Array[DockableMonitorWidget]:
	var result: Array[DockableMonitorWidget] = []
	for widget: DockableMonitorWidget in widgets:
		if widget.pinned:
			result.append(widget)
	return result

