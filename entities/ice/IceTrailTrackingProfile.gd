class_name IceTrailTrackingProfile
extends Resource

@export var enabled := false
@export_range(0.0, 10.0, 0.05) var detection_threshold := 0.5
@export_range(0, 1000, 1) var max_age := 8
@export_range(0.0, 10.0, 0.05) var tracking_quality := 1.0
@export_range(0, 100, 1) var memory_ticks := 3
