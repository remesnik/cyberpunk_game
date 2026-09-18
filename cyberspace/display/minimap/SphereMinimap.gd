class_name SphereMinimap
extends PanelContainer

signal node_focus_requested(node_id: StringName)
signal collapsed_changed(collapsed: bool)

@export var starts_collapsed := false
@export var show_center_player_control := true
var graph: NetworkGraph
var position_model: PlayerNetworkPosition
var knowledge: PlayerKnowledge
var sphere_tracker: CurrentSphereTracker
var trail_system: HackerTrailSystem
var _collapsed := false

@onready var toggle_button: Button = %ToggleButton
@onready var title_label: Label = %TitleLabel
@onready var identity_label: Label = %IdentityLabel
@onready var meta_label: Label = %MetaLabel
@onready var center_player_button: Button = %CenterPlayerButton
@onready var node_hint_label: Label = %NodeHintLabel
@onready var canvas: SphereMinimapCanvas = %Canvas

func _ready() -> void:
	toggle_button.pressed.connect(toggle_collapsed)
	center_player_button.visible = show_center_player_control
	center_player_button.pressed.connect(_on_center_player_pressed)
	canvas.node_focus_requested.connect(_on_canvas_node_focus_requested)
	canvas.node_inspection_hint_changed.connect(_on_node_inspection_hint_changed)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.network_position_changed.connect(_on_network_changed.unbind(3))
		event_bus.network_display_update_requested.connect(_on_network_changed)
		event_bus.simulation_tick_advanced.connect(_on_simulation_tick_advanced)
		event_bus.sphere_changed.connect(_on_sphere_changed)
	set_collapsed(starts_collapsed)
	var game := get_node_or_null("/root/Game")
	if game != null and bool(game.get("session_active")):
		set_models(game.get("network_graph"), game.get("player_network_position"), game.get("player_knowledge"), game.get("sphere_tracker"))
		set_trail_source(game.get("trail_system"), &"PLAYER", game.get("intrusion_run_id"), func() -> int: return int(game.get("action_clock").current_tick) if game.get("action_clock") != null else 0)

func set_models(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge, p_tracker: CurrentSphereTracker = null) -> void:
	if knowledge != null and knowledge.knowledge_changed.is_connected(_on_knowledge_changed): knowledge.knowledge_changed.disconnect(_on_knowledge_changed)
	graph = p_graph; position_model = p_position; knowledge = p_knowledge; sphere_tracker = p_tracker
	if knowledge != null: knowledge.knowledge_changed.connect(_on_knowledge_changed)
	canvas.set_models(graph, position_model, knowledge, sphere_tracker)
	_update_header()

func set_trail_source(p_trail_system: HackerTrailSystem, actor_id: StringName, p_intrusion_id: StringName, tick_provider: Callable = Callable()) -> void:
	trail_system = p_trail_system
	canvas.set_trail_source(trail_system, actor_id, p_intrusion_id, tick_provider)

func set_own_trail_visible(visible: bool) -> void:
	canvas.set_own_trail_visible(visible)

func set_security_sleeves_visible(visible: bool) -> void:
	canvas.set_security_sleeves_visible(visible)

func set_center_player_control_visible(visible: bool) -> void:
	show_center_player_control = visible
	if center_player_button != null: center_player_button.visible = visible

func toggle_collapsed() -> void:
	set_collapsed(canvas.visible)

func set_collapsed(collapsed: bool) -> void:
	var changed := _collapsed != collapsed
	_collapsed = collapsed
	canvas.visible = not collapsed
	identity_label.visible = not collapsed
	meta_label.visible = not collapsed
	toggle_button.text = "+" if collapsed else "−"
	custom_minimum_size.y = 32.0 if collapsed else 230.0
	if changed: collapsed_changed.emit(collapsed)

func is_collapsed() -> bool:
	return _collapsed

func _on_network_changed() -> void:
	if canvas != null:
		canvas.refresh()
		_update_header()

func _on_knowledge_changed() -> void:
	_update_header()

func _on_sphere_changed(player_id: StringName, _previous: StringName, _next: StringName, _entry: StringName) -> void:
	if player_id == &"PLAYER": _on_network_changed()

func _on_simulation_tick_advanced(_previous_tick: int, _current_tick: int, _amount: int) -> void:
	if canvas != null: canvas.queue_redraw()

func _on_center_player_pressed() -> void:
	canvas.focus_current_player()

func _on_canvas_node_focus_requested(node_id: StringName) -> void:
	node_focus_requested.emit(node_id)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null: event_bus.network_node_focus_requested.emit(node_id)

func _on_node_inspection_hint_changed(_node_id: StringName, text: String, visible: bool) -> void:
	node_hint_label.text = text
	node_hint_label.visible = visible and not text.is_empty()

func get_identity_header_view() -> Dictionary:
	var result := {"sphere_id": &"", "identity_known": false, "display_name": "", "known_nodes": 0, "total_known": false, "known_total_nodes": 0, "security_state_known": false, "security_state": &""}
	if graph == null or position_model == null or knowledge == null: return result
	var sphere := graph.get_sphere_for_node(position_model.current_node_id)
	if sphere == null: return result
	var view := knowledge.get_sphere_view(sphere.id)
	result.sphere_id = sphere.id
	result.identity_known = bool(view.get("identity_known", false))
	result.display_name = String(view.get("display_name", "")) if result.identity_known else ""
	result.known_nodes = canvas.visible_node_ids().size() if canvas != null else 0
	result.total_known = bool(view.get("topology_size_known", false))
	result.known_total_nodes = int(view.get("known_total_node_count", 0)) if result.total_known else 0
	result.security_state_known = bool(view.get("security_state_known", false))
	result.security_state = view.get("security_state", &"") if result.security_state_known else &""
	return result

func _update_header() -> void:
	if title_label == null or identity_label == null or meta_label == null: return
	var view := get_identity_header_view()
	title_label.text = "SPHERE // %s" % (String(view.sphere_id).to_upper() if view.identity_known else "UNKNOWN")
	identity_label.text = String(view.display_name).to_upper() if view.identity_known else ""
	var node_text := "KNOWN NODES: %d" % int(view.known_nodes)
	if view.total_known: node_text += " / %d" % int(view.known_total_nodes)
	var parts: PackedStringArray = [node_text]
	if view.security_state_known:
		var security_text := "SECURITY: %s" % String(view.security_state).replace("_", " ").to_upper()
		if view.get("security_state_freshness", &"CURRENT") == &"STALE": security_text += " [STALE]"
		parts.append(security_text)
	meta_label.text = "  |  ".join(parts)
