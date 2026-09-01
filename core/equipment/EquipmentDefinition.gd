class_name EquipmentDefinition
extends RefCounted

enum EquipmentType { CYBERDECK_MODULE, ANTENNA, RADIO, CAMERA_TAP, NETWORK_ADAPTER, STORAGE_MODULE, COMPUTE_MODULE, PHYSICAL_ACCESS_DEVICE, CUSTOM }

var id: StringName
var display_name: String
var equipment_type: EquipmentType
var description: String
var base_cost := 0
var delivery_story_hook_id: StringName
var story_tags: Array[StringName] = []
var metadata: Dictionary = {}


func _init(equipment_id: StringName = &"", name: String = "", type: EquipmentType = EquipmentType.CUSTOM, price := 0) -> void:
	id = equipment_id
	display_name = name
	equipment_type = type
	base_cost = maxi(0, price)


func type_label() -> String:
	return EquipmentType.keys()[equipment_type].replace("_", " ")

