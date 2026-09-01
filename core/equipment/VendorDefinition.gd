class_name VendorDefinition
extends RefCounted

var id: StringName
var display_name: String
var inventory: Array[StringName] = []
var price_multiplier := 1.0
var delivery_duration := 30.0
var delivery_destinations: Array[StringName] = []
var story_tags: Array[StringName] = []
var description: String


func _init(vendor_id: StringName = &"", name: String = "", duration := 30.0) -> void:
	id = vendor_id
	display_name = name
	delivery_duration = maxf(1.0, duration)


func sells(equipment_id: StringName) -> bool:
	return inventory.has(equipment_id)


func price_for(equipment: EquipmentDefinition, quantity: int) -> int:
	return maxi(0, int(ceil(float(equipment.base_cost * maxi(quantity, 0)) * price_multiplier)))

