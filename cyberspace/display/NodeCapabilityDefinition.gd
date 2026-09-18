class_name NodeCapabilityDefinition
extends Resource

@export var capability_type: NodeCapabilityType.Value = NodeCapabilityType.Value.IO
@export var display_name := "I/O"
@export var glyph := "IO"
@export_multiline var tooltip_description := "Detected node capability"
@export var palette_role: NodeCapabilityIconTheme.PaletteRole = NodeCapabilityIconTheme.PaletteRole.STANDARD
@export var source_tags: Array[StringName] = []
@export var priority := 0
@export_range(0, 11, 1) var preferred_socket := 0
