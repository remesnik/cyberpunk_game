class_name CyberspaceVisualizationConfig
extends Resource

const LevelStyle := preload("res://cyberspace/display/NodeLevelStyle.gd")

@export_group("Hex Nodes")
@export_range(0.5, 2.0, 0.05) var node_scale := 1.30
@export var base_connected_radius := 42.0
@export var base_current_radius := 54.0
@export var base_visual_size := Vector2(210.0, 132.0)
@export var perimeter_icon_clearance := 36.0
@export var title_font_size := 15
@export var subtitle_font_size := 11
@export var level_font_size := 12
@export var status_font_size := 8
@export_range(6, 24, 1) var node_label_max_characters := 14

@export_group("Capability Indicators")
@export var capability_catalog: Resource
@export var capability_icon_theme: Resource
@export var capability_indicator_radius := 10.0
@export var capability_socket_border_gap := 6.0
@export var capability_indicator_font_size := 8
@export_range(0, 11, 1) var unknown_content_preferred_socket := 11

@export_group("Security Level Styles")
@export var unknown_level_style: Resource
@export var known_level_fallback_style: Resource
@export var level_styles: Array[Resource] = []

@export_group("Interaction Overlays")
@export var hover_color := Color("d9f7ff")
@export var selection_color := Color("ffc857")
@export var current_marker_color := Color("ffffff")
@export var security_marker_color := Color("ff496c")

@export_group("State Animation")
@export_range(0.2, 2.0, 0.05) var current_pulse_speed := 0.65
@export_range(0.2, 2.0, 0.05) var san_tether_pulse_speed := 0.45
@export_range(1.0, 8.0, 0.1) var feed_signal_period := 3.2
@export_range(1.0, 8.0, 0.1) var active_process_flicker_period := 4.7
@export_range(0.2, 2.0, 0.05) var ice_activity_speed := 0.8
@export_range(0.2, 2.0, 0.05) var objective_pulse_speed := 0.5
@export_range(0.25, 0.75, 0.01) var scan_resolution_duration := 0.46
@export_range(0.01, 0.08, 0.01) var scan_icon_stagger := 0.035
@export var scan_sweep_color := Color("9eeeff")
@export var scan_discovery_highlight_color := Color("fff2a8")

@export_group("Level of Detail")
@export_range(0.5, 1.0, 0.01) var close_lod_min_zoom := 0.82
@export_range(0.2, 0.8, 0.01) var medium_lod_min_zoom := 0.48
@export_range(0.3, 1.0, 0.05) var medium_hex_scale := 0.82
@export_range(0.3, 1.0, 0.05) var far_hex_scale := 0.45
@export_range(4, 30, 1) var close_density_limit := 12
@export_range(8, 60, 1) var medium_density_limit := 30
@export var medium_capability_priority_limit := 60
@export var far_capability_types: Array[int] = [NodeCapabilityType.Value.SYSTEM_ACCESS_NODE, NodeCapabilityType.Value.OBJECTIVE, NodeCapabilityType.Value.ICE]

@export_group("Graph Layout")
@export var minimum_center_spacing := 190.0
@export var preferred_horizontal_orbit := 315.0
@export var preferred_vertical_orbit := 220.0
@export var map_edge_padding := 12.0

@export_group("Connections")
@export var endpoint_clearance := 5.0
@export var edge_width := 1.6
@export var highlighted_edge_width := 4.0
@export var edge_arc_offset := 14.0

func radius(current: bool) -> float:
	return (base_current_radius if current else base_connected_radius) * node_scale

func radius_for_lod(current: bool, detail_level: int) -> float:
	var scale_factor := 1.0
	if detail_level == 1: scale_factor = medium_hex_scale
	elif detail_level == 2: scale_factor = far_hex_scale
	return radius(current) * scale_factor

func detail_level_for(zoom: float, visible_node_count: int) -> int:
	if zoom < medium_lod_min_zoom or visible_node_count > medium_density_limit: return 2
	if zoom < close_lod_min_zoom or visible_node_count > close_density_limit: return 1
	return 0

func visual_size() -> Vector2:
	return Vector2(base_visual_size.x * node_scale, base_visual_size.y * node_scale + perimeter_icon_clearance)

func style_for_level(level: int, known: bool) -> Resource:
	if not known:
		return unknown_level_style
	for style: Resource in level_styles:
		if style != null and int(style.get("level")) == level:
			return style
	return known_level_fallback_style
