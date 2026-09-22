class_name ScanDisclosureProfile
extends Resource

@export_range(1, 8, 1) var maximum_quality := 4
@export var quality_labels: Dictionary = {1: &"CONTACT", 2: &"CLASSIFIED", 3: &"DETAILED", 4: &"FORENSIC"}
@export_range(1, 8, 1) var network_type_quality := 1
@export_range(1, 8, 1) var ice_presence_quality := 1
@export_range(1, 8, 1) var security_family_quality := 2
@export_range(1, 8, 1) var difficulty_rating_quality := 2
@export_range(1, 8, 1) var service_list_quality := 2
@export_range(1, 8, 1) var ice_identity_quality := 3
@export_range(1, 8, 1) var ice_rating_quality := 3
@export_range(1, 8, 1) var controlled_paths_quality := 3
@export_range(1, 8, 1) var remote_controller_quality := 4
@export_range(1, 8, 1) var vulnerability_quality := 4
@export_range(1, 8, 1) var affinity_hint_quality := 4
@export_range(1, 8, 1) var realtime_endpoint_quality := 3

func quality_label(quality: int) -> StringName:
	return StringName(quality_labels.get(quality, &"UNKNOWN"))
