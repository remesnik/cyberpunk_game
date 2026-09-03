class_name SANDefenseDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var behavior_flags: Array[StringName] = []
@export var resource_costs: Dictionary = {}
@export_range(1, 1000, 1) var maximum_integrity := 100
@export_range(0, 100, 1) var access_resistance := 0
@export_range(0, 100, 1) var hostile_hacker_resistance := 0
@export_range(0, 100, 1) var ice_resistance := 0
@export_range(0, 100, 1) var integrity_damage_reduction := 0
@export_range(0, 100, 1) var deck_damage_reduction := 0
@export_range(0, 100, 1) var detection_strength := 0
@export_range(0, 100, 1) var counterattack_power := 0
@export_range(0.0, 2.0, 0.05) var trail_strength_multiplier := 1.0

func _init(p_id: StringName = &"", p_display_name := "", p_description := "") -> void:
	id = p_id; display_name = p_display_name; description = p_description

func has_behavior(behavior: StringName) -> bool: return behavior_flags.has(behavior)
