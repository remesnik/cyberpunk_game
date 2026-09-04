class_name IceController
extends RefCounted

signal ice_updated(instance: IceInstance)

var graph: NetworkGraph
var player_position: PlayerNetworkPosition
var player_knowledge: PlayerKnowledge
var instances: Dictionary = {}
var pending_trace_increase := 0

func _init(p_graph: NetworkGraph, p_player_position: PlayerNetworkPosition, p_player_knowledge: PlayerKnowledge) -> void:
	graph = p_graph
	player_position = p_player_position
	player_knowledge = p_player_knowledge

func add_ice(instance: IceInstance) -> bool:
	if instance.instance_id == &"" or instances.has(instance.instance_id) or graph.get_node(instance.current_node_id) == null:
		return false
	instances[instance.instance_id] = instance
	return true

func get_ice(instance_id: StringName) -> IceInstance:
	return instances.get(instance_id) as IceInstance

func update(time_units: int, request: ActionRequest) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if time_units <= 0:
		return events
	var ordered_ids: Array = instances.keys()
	ordered_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for instance_id in ordered_ids:
		var ice := get_ice(instance_id)
		if not ice.operational:
			continue
		if ice.disrupted_time > 0:
			ice.disrupted_time = maxi(0, ice.disrupted_time - time_units)
			events.append(_event(&"ICE_DISRUPTED", ice, true, {"remaining": ice.disrupted_time}))
			continue
		_update_instance(ice, time_units, request, events)
	return events

func _update_instance(ice: IceInstance, time_units: int, request: ActionRequest, events: Array[Dictionary]) -> void:
	var distance := _graph_distance(ice.current_node_id, player_position.current_node_id)
	var player_was_active := request.action_type != ActionRequest.ActionType.WAIT
	if distance == 0:
		ice.state = IceState.Value.ENGAGE
		_detect_player(ice, events, true)
	elif distance >= 0 and distance <= ice.detection_capability and player_was_active:
		ice.state = IceState.Value.HUNT
		_detect_player(ice, events, false)
	elif ice.state == IceState.Value.DORMANT and distance >= 0 and distance <= ice.scan_capability + 1 and player_was_active:
		ice.state = IceState.Value.INVESTIGATE
		ice.target_node_id = player_position.current_node_id
		ice.alert_level = maxi(ice.alert_level, 25)
		player_knowledge.add_observation(&"SIGNAL_DETECTED", &"")
		events.append(_event(&"SIGNAL_DETECTED", ice, true, {"region": &"UNKNOWN"}))
	elif ice.state == IceState.Value.ENGAGE:
		ice.state = IceState.Value.SEARCH
		ice.target_node_id = ice.last_known_player_position

	if ice.state in [IceState.Value.INVESTIGATE, IceState.Value.SEARCH, IceState.Value.HUNT]:
		_scan(ice, events)

	ice.movement_progress += time_units
	while ice.movement_progress >= ice.movement_cost and ice.state != IceState.Value.ENGAGE:
		ice.movement_progress -= ice.movement_cost
		if not _move_once(ice, events):
			break
		if ice.current_node_id == player_position.current_node_id:
			ice.state = IceState.Value.ENGAGE
			_detect_player(ice, events, true)
			break
	ice_updated.emit(ice)

func _detect_player(ice: IceInstance, events: Array[Dictionary], exact: bool) -> void:
	ice.last_known_player_position = ice.known_player_position
	ice.known_player_position = player_position.current_node_id
	ice.target_node_id = player_position.current_node_id
	ice.alert_level = mini(100, ice.alert_level + (45 if exact else 25))
	pending_trace_increase += 2 if exact else 1
	player_knowledge.report_ice(ice.instance_id, ice.current_node_id, ice.state)
	events.append(_event(&"PLAYER_DETECTED" if exact else &"PLAYER_SIGNAL_ACQUIRED", ice, true, {"exact": exact}))

func _scan(ice: IceInstance, events: Array[Dictionary]) -> void:
	var distance := _graph_distance(ice.current_node_id, player_position.current_node_id)
	if distance >= 0 and distance <= ice.scan_capability:
		events.append(_event(&"SCAN_PULSE", ice, true, {"distance": distance}))
		player_knowledge.add_observation(&"SCAN_PULSE", ice.current_node_id)

func _move_once(ice: IceInstance, events: Array[Dictionary]) -> bool:
	var destination := _choose_destination(ice)
	if destination == &"" or destination == ice.current_node_id:
		return false
	var origin := ice.current_node_id
	ice.current_node_id = destination
	if player_knowledge.ice_records.has(ice.instance_id) and player_knowledge.ice_records[ice.instance_id].get("node_id", &"") == origin:
		player_knowledge.mark_ice_position_stale(ice.instance_id)
	var player_can_infer := _graph_distance(destination, player_position.current_node_id) <= 1 or _graph_distance(origin, player_position.current_node_id) <= 1
	if player_can_infer:
		player_knowledge.add_observation(&"ROUTE_ACTIVITY", &"")
		events.append(_event(&"ROUTE_ACTIVITY", ice, false, {"near": player_position.current_node_id}))
	events.append(_event(&"ICE_MOVED_DEBUG", ice, false, {"from": origin, "to": destination, "debug_only": true}))
	return true

func _choose_destination(ice: IceInstance) -> StringName:
	match ice.state:
		IceState.Value.PATROL:
			if ice.definition.patrol_route.is_empty():
				return ice.current_node_id
			ice.patrol_index = (ice.patrol_index + 1) % ice.definition.patrol_route.size()
			return _next_step(ice.current_node_id, ice.definition.patrol_route[ice.patrol_index])
		IceState.Value.INVESTIGATE, IceState.Value.SEARCH, IceState.Value.HUNT:
			return _next_step(ice.current_node_id, ice.target_node_id)
		IceState.Value.RETURN:
			var step := _next_step(ice.current_node_id, ice.home_node)
			if step == ice.home_node:
				ice.state = IceState.Value.PATROL
			return step
	return ice.current_node_id

func _next_step(start: StringName, goal: StringName) -> StringName:
	if start == goal or graph.get_node(goal) == null:
		return start
	var frontier: Array[StringName] = [start]
	var came_from: Dictionary = {start: &""}
	while not frontier.is_empty():
		var current := StringName(frontier.pop_front())
		for neighbor in _ice_neighbors(current):
			if came_from.has(neighbor):
				continue
			came_from[neighbor] = current
			if neighbor == goal:
				var step := goal
				while StringName(came_from[step]) != start:
					step = StringName(came_from[step])
				return step
			frontier.append(neighbor)
	return start

func _graph_distance(start: StringName, goal: StringName) -> int:
	if start == goal:
		return 0
	var frontier: Array[StringName] = [start]
	var distances: Dictionary = {start: 0}
	while not frontier.is_empty():
		var current := StringName(frontier.pop_front())
		for neighbor in _ice_neighbors(current):
			if distances.has(neighbor):
				continue
			distances[neighbor] = int(distances[current]) + 1
			if neighbor == goal:
				return int(distances[neighbor])
			frontier.append(neighbor)
	return -1

func _ice_neighbors(node_id: StringName) -> Array[StringName]:
	var neighbors: Array[StringName] = []
	var node := graph.get_node(node_id)
	if node == null:
		return neighbors
	var ordered_links := node.connected_links.duplicate()
	ordered_links.sort()
	for link_id in ordered_links:
		var link := graph.get_link(link_id)
		if link == null or link.disabled or not link.connects_from(node_id):
			continue
		var destination := link.destination_from(node_id)
		if destination != &"":
			neighbors.append(destination)
	return neighbors

func _event(type: StringName, ice: IceInstance, player_visible: bool, extra: Dictionary = {}) -> Dictionary:
	var event := {"type": type, "ice_id": ice.instance_id, "player_visible": player_visible}
	event.merge(extra, true)
	return event
