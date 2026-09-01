@tool
class_name AuthoringEditorState
extends Resource

@export var document_path: String
@export var active_workspace: StringName = &"NETWORK"
@export var selected_id: StringName
@export var graph_positions: Dictionary = {}
@export var graph_zoom: float = 1.0
@export var graph_scroll: Vector2 = Vector2.ZERO
@export var preview_profile: StringName = &"NEW_PLAYER"
@export var preview_realtime_speed: float = 1.0
@export var preview_flags: Dictionary = {}
@export var preview_capabilities: Array[StringName] = []
@export var preview_credentials: Array[StringName] = []


func position_for(entry_id: StringName, fallback: Vector2) -> Vector2:
	return graph_positions.get(entry_id, fallback)


func set_position(entry_id: StringName, position: Vector2) -> void:
	graph_positions[entry_id] = position
