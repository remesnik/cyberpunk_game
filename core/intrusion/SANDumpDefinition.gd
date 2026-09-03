class_name SANDumpDefinition
extends Resource

@export var id: StringName = &"DUMP"
@export var display_name := "Dump"
@export_range(1, 100, 1) var action_cost := 3
@export_range(0, 100, 1) var base_difficulty := 4
@export var required_capability: StringName = &"DUMP"
@export_range(0, 1000, 1) var deck_surge_damage := 12
@export_range(0, 16, 1) var program_corruption_count := 0
@export var temporary_fault_id: StringName = &"DECK_LINK_SURGE"
@export_range(0.0, 3600.0, 0.5) var temporary_fault_duration := 30.0
