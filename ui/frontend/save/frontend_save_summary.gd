class_name FrontendSaveSummary
extends RefCounted

## Presentation-safe metadata supplied by the save system. These fields must not
## contain undiscovered objective, topology, actor, or security information.
var save_id: StringName
var network_name := ""
var location_name := ""
var display_timestamp := ""
var resumable := false

func _init(p_save_id := &"", p_network_name := "", p_location_name := "", p_display_timestamp := "", p_resumable := false) -> void:
	save_id = p_save_id
	network_name = p_network_name
	location_name = p_location_name
	display_timestamp = p_display_timestamp
	resumable = p_resumable

func is_valid() -> bool:
	return not save_id.is_empty() and resumable
