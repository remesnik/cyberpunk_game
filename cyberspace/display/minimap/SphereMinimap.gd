class_name SphereMinimap
extends PanelContainer

@export var starts_collapsed := false
var graph: NetworkGraph
var position_model: PlayerNetworkPosition
var knowledge: PlayerKnowledge
var sphere_tracker: CurrentSphereTracker

@onready var toggle_button: Button = %ToggleButton
@onready var title_label: Label = %TitleLabel
@onready var canvas: SphereMinimapCanvas = %Canvas

func _ready() -> void:
	toggle_button.pressed.connect(toggle_collapsed)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.network_position_changed.connect(_on_network_changed.unbind(3))
		event_bus.network_display_update_requested.connect(_on_network_changed)
		event_bus.sphere_changed.connect(_on_sphere_changed)
	set_collapsed(starts_collapsed)
	var game := get_node_or_null("/root/Game")
	if game != null and bool(game.get("session_active")):
		set_models(game.get("network_graph"), game.get("player_network_position"), game.get("player_knowledge"), game.get("sphere_tracker"))

func set_models(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge, p_tracker: CurrentSphereTracker = null) -> void:
	graph = p_graph; position_model = p_position; knowledge = p_knowledge; sphere_tracker = p_tracker
	canvas.set_models(graph, position_model, knowledge, sphere_tracker)
	_update_title()

func toggle_collapsed() -> void:
	set_collapsed(canvas.visible)

func set_collapsed(collapsed: bool) -> void:
	canvas.visible = not collapsed
	toggle_button.text = "+" if collapsed else "−"
	custom_minimum_size.y = 32.0 if collapsed else 210.0

func _on_network_changed() -> void:
	if canvas != null:
		canvas.refresh()
		_update_title()

func _on_sphere_changed(player_id: StringName, _previous: StringName, _next: StringName, _entry: StringName) -> void:
	if player_id == &"PLAYER": _on_network_changed()

func _update_title() -> void:
	var sphere := graph.get_sphere_for_node(position_model.current_node_id) if graph != null and position_model != null else null
	title_label.text = "SPHERE // %s" % (sphere.display_name.to_upper() if sphere != null else "UNKNOWN")
