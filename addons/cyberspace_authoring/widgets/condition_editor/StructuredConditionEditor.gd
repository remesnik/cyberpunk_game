@tool
class_name StructuredConditionEditor
extends VBoxContainer

signal conditions_changed(conditions: Array[Dictionary])

const TYPES := ["ALWAYS", "FLAG_SET", "FLAG_NOT_SET", "COUNTER_MIN", "COUNTER_MAX", "STATE_EQUALS", "NODE_DISCOVERED", "NODE_COMPROMISED", "SERVICE_DISCOVERED", "LINK_DISCOVERED", "HAS_CAPABILITY", "HAS_CREDENTIAL", "HAS_DATA", "TRACE_MIN", "TRACE_MAX", "AT_NODE", "AUTHORITY_LEVEL", "ANCHOR_ESTABLISHED", "MISSION_STATE", "HOOK_STATE", "FACTION_REPUTATION", "REALTIME_PROCESS_STATE", "COMMS_DISCOVERED", "COMMS_INTERCEPTED", "COMMS_RECORDED", "VIDEO_DISCOVERED", "VIDEO_STATE", "VIDEO_EVENT_SEEN", "ALARM_STATE", "TEAM_STATE", "TEAM_AT_LOCATION", "EQUIPMENT_DELIVERED", "REALTIME_EVENT_OCCURRED", "CUSTOM"]

var conditions: Array[Dictionary] = []
var _list: ItemList


func _ready() -> void:
	var row := HBoxContainer.new(); add_child(row)
	var title := Label.new(); title.text = "CONDITIONS // ALL / ANY / NOT"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(title)
	var add := Button.new(); add.text = "+ CONDITION"; add.pressed.connect(_add_condition); row.add_child(add)
	_list = ItemList.new(); _list.custom_minimum_size.y = 110; _list.allow_reselect = true; add_child(_list)
	var why := Button.new(); why.text = "SHOW WHY CONDITION FAILED"; why.pressed.connect(_show_why); add_child(why)


func set_conditions(value: Array) -> void:
	conditions.assign(value)
	_refresh()


func _add_condition() -> void:
	conditions.append({"operator": &"ALL", "type": &"ALWAYS", "reference_id": &"", "value": true})
	_refresh(); conditions_changed.emit(conditions)


func _refresh() -> void:
	if _list == null: return
	_list.clear()
	for condition: Dictionary in conditions:
		_list.add_item("%s  %s(%s)" % [condition.get("operator", &"ALL"), condition.get("type", &"ALWAYS"), condition.get("reference_id", &"")])


func _show_why() -> void:
	if conditions.is_empty(): _list.add_item("✓ No conditions; entry is available.")
	else: _list.add_item("PREVIEW: supply profile state to evaluate each structured condition.")

