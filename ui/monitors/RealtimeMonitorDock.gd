class_name RealtimeMonitorDock
extends Control

const TEAM_MONITOR := preload("res://ui/PhysicalTeamMonitor.tscn")
const CONTEXTUAL_MONITOR := preload("res://ui/monitors/ContextualMonitorWindow.tscn")

@onready var left_dock: VBoxContainer = %LeftDock
@onready var right_dock: VBoxContainer = %RightDock
@onready var bottom_dock: HBoxContainer = %BottomDock

var widgets: Array[DockableMonitorWidget] = []
var monitor_window: Control
var team_status: Control


func _ready() -> void:
	# The dock itself never captures map input; only visible widget rectangles do.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Monitoring is contextual: processes continue updating, but their panels do
	# not claim graph space until the player expands or redocks one.
	team_status = TEAM_MONITOR.instantiate()
	bottom_dock.add_child(team_status)
	monitor_window = CONTEXTUAL_MONITOR.instantiate()
	right_dock.add_child(monitor_window)


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
