class_name NodeVisualizationLab
extends Control

const NODE_SCENE := preload("res://cyberspace/display/NodeVisual.tscn")
const LINK_SCRIPT := preload("res://cyberspace/display/LinkVisual.gd")
const CONFIG := preload("res://cyberspace/display/cyberspace_visualization_config.tres")

var _primary: NodeVisual
var _previous_primary_view: Dictionary = {}
var _reference_visuals: Array[NodeVisual] = []

@onready var preview_canvas: Control = %PreviewCanvas
@onready var link_layer: Node2D = %LinkLayer
@onready var node_layer: Control = %NodeLayer
@onready var knowledge_toggle: CheckButton = %KnowledgeToggle
@onready var level_toggle: CheckButton = %LevelToggle
@onready var scan_toggle: CheckButton = %ScanToggle
@onready var capability_toggle: CheckButton = %CapabilityToggle
@onready var san_toggle: CheckButton = %SanToggle
@onready var ice_toggle: CheckButton = %IceToggle
@onready var objective_toggle: CheckButton = %ObjectiveToggle
@onready var compromise_toggle: CheckButton = %CompromiseToggle
@onready var security_level: SpinBox = %SecurityLevel
@onready var reduced_animation: CheckButton = %ReducedAnimation
@onready var zoom_slider: HSlider = %ZoomSlider
@onready var lod_readout: Label = %LodReadout

func _ready() -> void:
	for control in [knowledge_toggle, level_toggle, scan_toggle, capability_toggle, san_toggle, ice_toggle, objective_toggle, compromise_toggle]:
		(control as BaseButton).toggled.connect(_refresh_primary.unbind(1))
	reduced_animation.toggled.connect(_refresh_all.unbind(1))
	security_level.value_changed.connect(_refresh_primary.unbind(1))
	zoom_slider.value_changed.connect(_refresh_all.unbind(1))
	resized.connect(_layout_previews)
	_build_reference_previews()
	_refresh_primary()
	queue_redraw()

func _build_reference_previews() -> void:
	_primary = _create_visual()
	var references: Array[Dictionary] = [
		{"id": &"UNKNOWN", "display_name": "Unknown", "identity_known": false, "level_known": false, "unknown_content_count": 2},
		{"id": &"PARTIAL", "display_name": "Relay 02", "short_id": "RELAY-02", "identity_known": true, "level_known": true, "security_level": 2, "unknown_content_count": 2},
		{"id": &"SCANNED", "display_name": "Archive", "identity_known": true, "level_known": true, "security_level": 3, "scanned": true, "capability_types": [NodeCapabilityType.Value.DATABASE, NodeCapabilityType.Value.DATASTORE, NodeCapabilityType.Value.FEED], "capability_counts": {NodeCapabilityType.Value.FEED: 3}},
		{"id": &"SAN", "display_name": "Ingress", "identity_known": true, "level_known": true, "security_level": 1, "local_san_present": true, "capability_types": [NodeCapabilityType.Value.SYSTEM_ACCESS_NODE]},
		{"id": &"ICE", "display_name": "Security", "identity_known": true, "level_known": true, "security_level": 4, "capability_types": [NodeCapabilityType.Value.SECURITY, NodeCapabilityType.Value.ICE]},
		{"id": &"OBJECTIVE", "display_name": "Target", "identity_known": true, "level_known": true, "security_level": 5, "capability_types": [NodeCapabilityType.Value.OBJECTIVE, NodeCapabilityType.Value.ACTIVE_PROCESS]},
	]
	for view: Dictionary in references:
		var visual := _create_visual()
		visual.configure_view(view, false, true, (view.get("capability_types", []) as Array).has(NodeCapabilityType.Value.SECURITY))
		_reference_visuals.append(visual)
	_layout_previews()
	_build_links()

func _create_visual() -> NodeVisual:
	var visual := NODE_SCENE.instantiate() as NodeVisual
	node_layer.add_child(visual)
	visual.apply_visualization_config(CONFIG)
	return visual

func _primary_view() -> Dictionary:
	var capabilities: Array[int] = []
	var counts := {}
	if capability_toggle.button_pressed:
		capabilities.assign([NodeCapabilityType.Value.IO, NodeCapabilityType.Value.FEED, NodeCapabilityType.Value.DATABASE, NodeCapabilityType.Value.DATASTORE])
		counts = {NodeCapabilityType.Value.FEED: 3, NodeCapabilityType.Value.DATABASE: 2}
	if san_toggle.button_pressed: capabilities.append(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE)
	if ice_toggle.button_pressed:
		capabilities.append(NodeCapabilityType.Value.SECURITY)
		capabilities.append(NodeCapabilityType.Value.ICE)
	if objective_toggle.button_pressed: capabilities.append(NodeCapabilityType.Value.OBJECTIVE)
	return {
		"id": &"LIVE_TEST", "display_name": "Live Test Node", "short_id": "LIVE-TEST",
		"identity_known": knowledge_toggle.button_pressed,
		"level_known": level_toggle.button_pressed,
		"security_level": int(security_level.value),
		"scanned": scan_toggle.button_pressed,
		"concise_status": "COMPROMISED" if compromise_toggle.button_pressed else ("SCANNED" if scan_toggle.button_pressed else ""),
		"unknown_content_count": 0 if capability_toggle.button_pressed else (2 if knowledge_toggle.button_pressed else 0),
		"capability_types": capabilities, "capability_counts": counts,
		"local_san_present": san_toggle.button_pressed,
	}

func _refresh_primary() -> void:
	var next_view := _primary_view()
	_primary.set_reduced_animation(reduced_animation.button_pressed)
	_primary.set_view_context(float(zoom_slider.value), 7)
	_primary.configure_view(next_view, true, true, ice_toggle.button_pressed)
	if not _previous_primary_view.is_empty(): _primary.play_knowledge_resolution(_previous_primary_view)
	_previous_primary_view = next_view.duplicate(true)
	_update_lod_readout()

func _refresh_all() -> void:
	_refresh_primary()
	for visual: NodeVisual in _reference_visuals:
		visual.set_reduced_animation(reduced_animation.button_pressed)
		visual.set_view_context(float(zoom_slider.value), 7)
	_update_lod_readout()

func _update_lod_readout() -> void:
	var names := ["CLOSE", "MEDIUM", "FAR"]
	lod_readout.text = "ZOOM %.2f // LOD %s" % [zoom_slider.value, names[_primary.detail_level]]

func _layout_previews() -> void:
	if _primary == null: return
	var width := maxf(760.0, preview_canvas.size.x)
	_primary.position = Vector2(width * 0.5 - _primary.size.x * 0.5, 20.0)
	for index in _reference_visuals.size():
		var columns := 3
		var cell_width := width / float(columns)
		var row := index / columns
		var column := index % columns
		_reference_visuals[index].position = Vector2(column * cell_width + cell_width * 0.5 - _reference_visuals[index].size.x * 0.5, 230.0 + row * 210.0)

func _build_links() -> void:
	for child in link_layer.get_children(): child.queue_free()
	if _primary == null: return
	var start := _primary.position + _primary.size * 0.5
	for index in _reference_visuals.size():
		var target := _reference_visuals[index]
		var finish := target.position + target.size * 0.5
		var link := LINK_SCRIPT.new() as LinkVisual
		link_layer.add_child(link)
		link.configure(StringName("LAB_LINK_%d" % index), start, finish, index == 0, CONFIG)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("020814"))
	for x in range(0, int(size.x), 40): draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.8, 0.9, 0.035))
	for y in range(0, int(size.y), 40): draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.8, 0.9, 0.035))
