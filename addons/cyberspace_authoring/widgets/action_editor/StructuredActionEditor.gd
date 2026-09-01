@tool
class_name StructuredActionEditor
extends VBoxContainer

signal actions_changed(actions: Array[Dictionary])

const TYPES := ["SET_FLAG", "CLEAR_FLAG", "INCREMENT_COUNTER", "SET_STATE", "REVEAL_NODE", "REVEAL_LINK", "CHANGE_NETWORK_STATE", "ADD_DATA", "REMOVE_DATA", "GRANT_CAPABILITY", "REVOKE_CAPABILITY", "GRANT_CREDENTIAL", "REMOVE_CREDENTIAL", "ACTIVATE_HOOK", "RESOLVE_HOOK", "ADD_OBJECTIVE", "ADD_GRAFFITI", "ENABLE_GRAFFITI", "DISABLE_GRAFFITI", "SEND_MESSAGE", "START_REALTIME_PROCESS", "STOP_REALTIME_PROCESS", "START_COMMS", "END_COMMS", "CHANGE_VIDEO_STATE", "CHANGE_ALARM_STATE", "MOVE_TEAM", "CHANGE_TEAM_OBJECTIVE", "CHANGE_TEAM_STATE", "UNLOCK_MEATSPACE_LOCATION", "UNLOCK_MEATSPACE_INTERACTION", "START_EQUIPMENT_ORDER", "SCHEDULE_REALTIME_EVENT", "CUSTOM"]

var actions: Array[Dictionary] = []
var _list: ItemList


func _ready() -> void:
	var row := HBoxContainer.new(); add_child(row)
	var title := Label.new(); title.text = "STRUCTURED ACTIONS"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(title)
	var add := Button.new(); add.text = "+ ACTION"; add.pressed.connect(_add_action); row.add_child(add)
	_list = ItemList.new(); _list.custom_minimum_size.y = 110; add_child(_list)


func set_actions(value: Array) -> void:
	actions.assign(value); _refresh()


func _add_action() -> void:
	actions.append({"type": &"SET_FLAG", "target_id": &"", "value": true})
	_refresh(); actions_changed.emit(actions)


func _refresh() -> void:
	if _list == null: return
	_list.clear()
	for action: Dictionary in actions: _list.add_item("%s  →  %s" % [action.get("type", &"CUSTOM"), action.get("target_id", &"")])

