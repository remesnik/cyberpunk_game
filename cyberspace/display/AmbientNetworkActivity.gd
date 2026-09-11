class_name AmbientNetworkActivity
extends Control
## Sparse presentation-only network activity. It never mutates graph or player state.
signal activity_started(event: Dictionary)

const NORMAL_COLOR := Color("ffffff")
const HACKER_UNKNOWN_COLOR := Color("ffd84d")
const HACKER_FRIENDLY_COLOR := Color("58e889")
const ICE_COLOR := Color("ff4d5f")
const CYAN := Color("48e8ff")
const AMBER := Color("ffc857")

enum ActorType { NORMAL, HACKER_UNKNOWN, HACKER_FRIENDLY, ICE }

var graph: NetworkGraph
var node_position_provider: Callable
var visible_node_provider: Callable
var service_node_provider: Callable
var visible_link_provider: Callable
var rng := RandomNumberGenerator.new()
var events: Array[Dictionary] = []
var elapsed := 0.0
var next_event := 4.0
var enabled := true
var reduced_animation := false
var maximum_events := 6

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.seed = 0x4e45545350414345
	set_process(true)

func configure(p_graph: NetworkGraph, positions: Callable, visible_nodes: Callable, service_nodes: Callable = Callable(), visible_links: Callable = Callable()) -> void:
	graph = p_graph
	node_position_provider = positions
	visible_node_provider = visible_nodes
	service_node_provider = service_nodes
	visible_link_provider = visible_links
	events.clear()
	elapsed = 0.0
	next_event = rng.randf_range(2.0, 4.5)
	queue_redraw()

func _process(delta: float) -> void:
	if not enabled or graph == null or not is_visible_in_tree(): return
	elapsed += maxf(delta, 0.0)
	for index in range(events.size() - 1, -1, -1):
		events[index].age = float(events[index].age) + delta
		if float(events[index].age) >= float(events[index].duration): events.remove_at(index)
	next_event -= delta
	if next_event <= 0.0 and events.size() < maximum_events:
		_start_random_event()
		next_event = rng.randf_range(2.5, 5.5)
	queue_redraw()

func trigger(type: StringName, data: Dictionary = {}) -> bool:
	if graph == null: return false
	var event := data.duplicate(true)
	if event.has("source_node"): event["from"] = event.source_node
	if event.has("destination_node"): event["to"] = event.destination_node
	if event.has("from"): event["source_node"] = event.from
	if event.has("to"): event["destination_node"] = event.to
	if not event.has("actor_type"): event["actor_type"] = ActorType.NORMAL
	if not event.has("speed"): event["speed"] = 1.0
	if event.has("from") and event.has("to") and not event.has("link_id"):
		var resolved := graph.find_link(StringName(event.from), StringName(event.to))
		if resolved != null: event.link_id = resolved.id
	event.merge({"type": type, "age": 0.0, "duration": _duration_for(type)}, false)
	if not _event_is_renderable(event): return false
	events.append(event)
	while events.size() > maximum_events: events.pop_front()
	activity_started.emit(event.duplicate(true))
	queue_redraw()
	return true

func observe_simulation_events(simulation_events: Array[Dictionary]) -> void:
	for source: Dictionary in simulation_events:
		match StringName(source.get("type", &"")):
			&"ICE_MOVED_DEBUG": trigger(&"ICE_TRANSIT", {"from": source.get("from", &""), "to": source.get("to", &""), "actor_type": ActorType.ICE, "payload_type": &"ICE_MOVEMENT"})
			&"SCAN_PULSE": trigger(&"SERVICE_PULSE", {"node_id": source.get("node_id", &"")})
			&"ALARM_TRIGGERED", &"PLAYER_DETECTED": trigger_alarm(StringName(source.get("node_id", source.get("to", &""))))

func trigger_alarm(origin: StringName) -> void:
	var visible := _visible_nodes()
	if origin == &"" or not visible.has(origin):
		origin = visible[0] if not visible.is_empty() else &""
	if origin == &"": return
	trigger(&"ALARM", {"node_id": origin})
	var neighbors := graph.get_visible_connected_nodes(origin)
	for neighbor in neighbors:
		if visible.has(neighbor):
			var link := graph.find_link(origin, neighbor)
			if link != null: trigger(&"ALARM_ROUTE", {"from": origin, "to": neighbor, "link_id": link.id, "actor_type": ActorType.ICE, "payload_type": &"SECURITY_RESPONSE"})

func _start_random_event() -> void:
	var visible := _visible_nodes()
	if visible.is_empty(): return
	var roll := rng.randi_range(0, 9)
	if roll <= 4:
		var links := _visible_links(visible)
		if links.is_empty(): return
		var link: NetworkLinkDefinition = links[rng.randi_range(0, links.size() - 1)]
		var actor := ActorType.NORMAL
		var actor_roll := rng.randi_range(0, 11)
		if actor_roll == 9: actor = ActorType.HACKER_UNKNOWN
		elif actor_roll == 10: actor = ActorType.HACKER_FRIENDLY
		elif actor_roll == 11: actor = ActorType.ICE
		var forward := rng.randi_range(0, 1) == 0 or link.one_way
		trigger(&"PACKET", {"source_node": link.source if forward else link.destination, "destination_node": link.destination if forward else link.source, "link_id": link.id, "actor_type": actor, "speed": rng.randf_range(0.8, 1.25), "payload_type": &"ROUTINE_TRAFFIC"})
	elif roll <= 7:
		var service_nodes: Array[StringName] = _service_nodes(visible)
		if service_nodes.is_empty(): service_nodes = visible
		trigger(&"SERVICE_PULSE", {"node_id": service_nodes[rng.randi_range(0, service_nodes.size() - 1)]})
	else:
		trigger(&"REMOTE_SESSION", {"node_id": visible[rng.randi_range(0, visible.size() - 1)], "role": [&"REMOTE", &"MAINT", &"SYSOP"][rng.randi_range(0, 2)], "actor_type": ActorType.NORMAL})

static func actor_color(actor_type: int) -> Color:
	match actor_type:
		ActorType.HACKER_UNKNOWN: return HACKER_UNKNOWN_COLOR
		ActorType.HACKER_FRIENDLY: return HACKER_FRIENDLY_COLOR
		ActorType.ICE: return ICE_COLOR
	return NORMAL_COLOR

func _duration_for(type: StringName) -> float:
	match type:
		&"PACKET", &"ICE_TRANSIT", &"ALARM_ROUTE": return 1.4
		&"SERVICE_PULSE", &"ALARM": return 1.8
		&"REMOTE_SESSION": return 4.5
	return 1.5

func _event_is_renderable(event: Dictionary) -> bool:
	if event.has("node_id"): return _position(StringName(event.node_id)) != Vector2.INF
	if event.has("from") and event.has("to"):
		var link := graph.find_link(StringName(event.from), StringName(event.to))
		return link != null and _visible_link_ids().has(link.id) and _position(StringName(event.from)) != Vector2.INF and _position(StringName(event.to)) != Vector2.INF
	return false

func _visible_link_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if visible_link_provider.is_valid(): result.assign(visible_link_provider.call())
	else:
		for link: NetworkLinkDefinition in graph.links.values():
			if link.is_visible(): result.append(link.id)
	return result

func _visible_nodes() -> Array[StringName]:
	var result: Array[StringName] = []
	if visible_node_provider.is_valid(): result.assign(visible_node_provider.call())
	return result

func _service_nodes(visible: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	if service_node_provider.is_valid(): result.assign(service_node_provider.call())
	for index in range(result.size() - 1, -1, -1):
		if not visible.has(result[index]): result.remove_at(index)
	return result

func _visible_links(visible: Array[StringName]) -> Array[NetworkLinkDefinition]:
	var result: Array[NetworkLinkDefinition] = []
	for link: NetworkLinkDefinition in graph.links.values():
		if not link.disabled and _visible_link_ids().has(link.id) and visible.has(link.source) and visible.has(link.destination): result.append(link)
	return result

func _position(node_id: StringName) -> Vector2:
	return node_position_provider.call(node_id) if node_position_provider.is_valid() else Vector2.INF

func _draw() -> void:
	for event: Dictionary in events:
		var progress := clampf(float(event.age) * float(event.get("speed", 1.0)) / maxf(0.01, float(event.duration)), 0.0, 1.0)
		var fade := sin(progress * PI)
		match StringName(event.type):
			&"PACKET", &"ICE_TRANSIT", &"ALARM_ROUTE":
				var start := _position(StringName(event.from)); var finish := _position(StringName(event.to))
				var color := actor_color(int(event.get("actor_type", ActorType.NORMAL)))
				draw_line(start, finish, Color(color, 0.12 + fade * 0.38), 3.0 if event.type == &"ALARM_ROUTE" else 2.0, true)
				var position := start.lerp(finish, 0.5 if reduced_animation else progress)
				draw_circle(position, 4.0, Color(color, 0.9 * fade))
			&"SERVICE_PULSE", &"ALARM":
				var center := _position(StringName(event.node_id))
				var color := AMBER if event.type == &"ALARM" else CYAN
				var radius := 25.0 if reduced_animation else lerpf(18.0, 54.0, progress)
				draw_circle(center, radius, Color(color, fade * 0.7), false, 2.0, true)
			&"REMOTE_SESSION":
				var center := _position(StringName(event.node_id)) + Vector2(30, -26)
				var points := PackedVector2Array([center + Vector2(0, -6), center + Vector2(6, 0), center + Vector2(0, 6), center + Vector2(-6, 0)])
				var color := actor_color(int(event.get("actor_type", ActorType.NORMAL)))
				draw_colored_polygon(points, Color(color, 0.72 * fade))
				draw_string(ThemeDB.fallback_font, center + Vector2(10, 4), String(event.role), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(color, 0.65 * fade))
