class_name IceDefinition
extends RefCounted

const IceSANAttackDefinitionScript := preload("res://entities/ice/IceSANAttackDefinition.gd")
const IceBindingProfileScript := preload("res://entities/ice/IceBindingProfile.gd")

var id: StringName
var display_name: String
var detection_capability: int
var movement_cost: int
var scan_capability: int
var patrol_route: Array[StringName]
var maximum_integrity: int
var defense: int
var trail_tracking: IceTrailTrackingProfile
var san_attack: RefCounted
var binding: RefCounted

func _init(p_id: StringName, p_display_name: String, p_detection_capability := 1, p_movement_cost := 1, p_scan_capability := 1, p_patrol_route: Array[StringName] = [], p_maximum_integrity := 8, p_defense := 1) -> void:
	id = p_id
	display_name = p_display_name
	detection_capability = maxi(p_detection_capability, 0)
	movement_cost = maxi(p_movement_cost, 1)
	scan_capability = maxi(p_scan_capability, 0)
	patrol_route = p_patrol_route.duplicate()
	maximum_integrity = maxi(p_maximum_integrity, 1)
	defense = maxi(p_defense, 0)
	trail_tracking = IceTrailTrackingProfile.new()
	san_attack = IceSANAttackDefinitionScript.new()
	binding = IceBindingProfileScript.new()
