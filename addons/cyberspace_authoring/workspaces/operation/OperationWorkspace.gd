@tool
class_name OperationWorkspace
extends VBoxContainer

const TimelineEditor := preload("res://addons/cyberspace_authoring/widgets/timeline/RealtimeTimelineEditor.gd")

var document: CyberspaceContentDocument
var _cyber: ItemList
var _physical: ItemList
var _timeline: Control


func _ready() -> void:
	var title := Label.new(); title.text = "OPERATION // CYBER-PHYSICAL RELATIONSHIPS"; add_child(title)
	var split := HSplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(split)
	_cyber = ItemList.new(); _cyber.name = "CYBERSPACE GRAPH"; split.add_child(_cyber)
	_physical = ItemList.new(); _physical.name = "MEATSPACE LOCATION GRAPH"; split.add_child(_physical)
	_timeline = TimelineEditor.new(); add_child(_timeline)


func set_document(value: CyberspaceContentDocument) -> void:
	document = value; _cyber.clear(); _physical.clear()
	if document == null: return
	for node: Dictionary in document.network_nodes: _cyber.add_item("%s // %s" % [node.id, node.get("display_name", "")])
	for endpoint: Dictionary in document.realtime_endpoints: _cyber.add_item("  ↳ %s → %s" % [endpoint.id, endpoint.get("physical_location_id", &"UNBOUND")])
	for location: Dictionary in document.meatspace_locations: _physical.add_item("%s // %s" % [location.id, location.get("display_name", "")])
	var events: Array = []
	for event: Dictionary in document.realtime_events: events.append({"time": event.get("delay_seconds", 0.0), "type": event.get("trigger_mode", &"EVENT"), "text": event.get("display_name", event.id)})
	_timeline.set_timeline(events)
