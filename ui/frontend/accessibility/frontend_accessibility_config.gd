class_name FrontendAccessibilityConfig
extends Resource

@export_group("Display")
@export_range(0.75, 2.0, 0.05) var ui_scale := 1.0
@export var reduced_animation := false
@export var glitch_effects_enabled := true
@export var scanlines_enabled := true
@export var high_contrast_focus := false

@export_group("Audio")
@export_range(0.0, 1.0, 0.01) var master_volume := 1.0
@export_range(0.0, 1.0, 0.01) var menu_ui_volume := 1.0
