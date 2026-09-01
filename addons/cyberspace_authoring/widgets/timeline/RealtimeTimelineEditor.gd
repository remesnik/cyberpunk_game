@tool
class_name RealtimeTimelineEditor
extends VBoxContainer

signal timeline_changed(events: Array[Dictionary])

var events: Array[Dictionary] = []
var preview_time: float = 0.0
var _list: ItemList
var _time: Label


func _ready() -> void:
	var controls := HBoxContainer.new(); add_child(controls)
	for caption: String in ["PLAY", "PAUSE PREVIEW", "SCRUB -5", "SCRUB +5", "START INTERCEPT HERE", "+ EVENT"]:
		var button := Button.new(); button.text = caption; controls.add_child(button)
		if caption == "SCRUB -5": button.pressed.connect(func(): set_preview_time(preview_time - 5.0))
		elif caption == "SCRUB +5": button.pressed.connect(func(): set_preview_time(preview_time + 5.0))
		elif caption == "+ EVENT": button.pressed.connect(_add_event)
	_time = Label.new(); _time.text = "EDITOR PREVIEW 00:00.00 // REAL SECONDS"; add_child(_time)
	_list = ItemList.new(); _list.custom_minimum_size.y = 130; add_child(_list)


func set_timeline(value: Array) -> void:
	events.assign(value); events.sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0))); _refresh()


func set_preview_time(value: float) -> void:
	preview_time = maxf(0.0, value)
	_time.text = "EDITOR PREVIEW %02d:%05.2f // REAL SECONDS" % [int(preview_time) / 60, fmod(preview_time, 60.0)]


func _add_event() -> void:
	events.append({"time": preview_time, "type": &"ANNOTATION", "text": "New timed event"}); set_timeline(events); timeline_changed.emit(events)


func _refresh() -> void:
	if _list == null: return
	_list.clear()
	for event: Dictionary in events: _list.add_item("%06.2f  %-18s %s" % [float(event.get("time", 0.0)), event.get("type", &"EVENT"), event.get("text", event.get("description", ""))])
