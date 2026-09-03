class_name IceController
extends RefCounted

signal ice_updated(instance: IceInstance)

var graph: NetworkGraph
var player_position: PlayerNetworkPosition
var player_knowledge: PlayerKnowledge
var instances: Dictionary = {}
var pending_trace_increase := 0
var trail_system: HackerTrailSystem
var trail_intrusion_id: StringName
var trail_target_actor_id: StringName = &"PLAYER"
var san_manager: SystemAccessNodeManager
var san_defense_controller: SANDefenseController
var san_deck_hardware: Dictionary = {}
var san_intrusions: Dictionary = {}
var simulation_tick := 0

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

func configure_trails(p_trail_system: HackerTrailSystem, intrusion_id: StringName, target_actor_id: StringName = &"PLAYER", p_san_manager: SystemAccessNodeManager = null) -> void:
	trail_system = p_trail_system; trail_intrusion_id = intrusion_id; trail_target_actor_id = target_actor_id; san_manager = p_san_manager

func configure_san_attacks(p_defense_controller: SANDefenseController) -> void:
	san_defense_controller = p_defense_controller

func register_san_attack_target(san: SystemAccessNode, deck_hardware: RefCounted, intrusion: IntrusionSession) -> bool:
	if san == null or deck_hardware == null or intrusion == null or san.intrusion_id != intrusion.id or san.deck_id != deck_hardware.deck_id:
		return false
	san_deck_hardware[san.id] = deck_hardware
	san_intrusions[san.id] = intrusion
	return true

func detect_trails(instance_id: StringName) -> Array[TrailSegment]:
	var ice := get_ice(instance_id)
	if ice == null or not ice.operational or trail_system == null: return []
	return trail_system.detect_trails(float(ice.definition.detection_capability), ice.current_node_id, trail_intrusion_id, ice.instance_id)

func follow_trail(instance_id: StringName) -> Dictionary:
	var ice := get_ice(instance_id)
	if ice == null or trail_system == null: return {"success": false, "node_path": [], "segments": [], "last_node_id": &""}
	return trail_system.follow_trail(ice.current_node_id, float(ice.definition.detection_capability), trail_intrusion_id, ice.instance_id)

func update(time_units: int, request: ActionRequest) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if time_units <= 0:
		return events
	simulation_tick += time_units
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
	if _update_san_attack(ice, time_units, events):
		ice_updated.emit(ice)
		return
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
		ice.last_known_player_position = ice.known_player_position
		ice.target_node_id = ice.known_player_position
		ice.known_player_position = &""
	elif ice.state in [IceState.Value.SEARCH, IceState.Value.HUNT] and ice.current_node_id == ice.target_node_id and ice.current_node_id != player_position.current_node_id:
		ice.last_known_player_position = ice.known_player_position
		ice.known_player_position = &""

	if ice.state in [IceState.Value.INVESTIGATE, IceState.Value.SEARCH, IceState.Value.HUNT] and ice.known_player_position.is_empty():
		_track_hacker_trail(ice, time_units, events)
	elif ice.state not in [IceState.Value.INVESTIGATE, IceState.Value.SEARCH, IceState.Value.HUNT] and not ice.followed_trail_segment_id.is_empty():
		ice.forget_trail()

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

func _update_san_attack(ice: IceInstance, time_units: int, events: Array[Dictionary]) -> bool:
	var attack := ice.definition.san_attack
	if attack == null or not attack.san_attack_enabled or san_manager == null: return false
	var targets := san_manager.get_active_at(ice.current_node_id, trail_intrusion_id)
	if targets.is_empty(): return false
	var san: SystemAccessNode
	for candidate: SystemAccessNode in targets:
		if trail_target_actor_id.is_empty() or candidate.owner_player_id == trail_target_actor_id:
			san = candidate; break
	if san == null: return false
	ice.state = IceState.Value.ENGAGE
	ice.san_attack_progress += time_units
	if ice.san_attack_progress < attack.action_interval: return true
	ice.san_attack_progress = 0
	var defense := san_defense_controller.interact(san, ice.instance_id, &"ICE_SAN_ATTACK", &"ICE") if san_defense_controller != null else {"access_resistance": 0, "events": []}
	san.mark_under_attack(true)
	events.append_array(defense.events)
	var integrity_result := san_defense_controller.apply_integrity_damage(san, attack.integrity_damage, &"ICE") if san_defense_controller != null else {"requested_damage": attack.integrity_damage, "reduction": 0, "delivered_damage": san.apply_damage(attack.integrity_damage)}
	events.append(_event(&"ICE_SAN_INTEGRITY_ATTACK", ice, true, {"san_id": san.id, "damage": integrity_result.delivered_damage, "remaining_integrity": san.integrity, "reduction": integrity_result.reduction}))
	if not san.active and attack.force_disconnect_on_san_destroy:
		_abort_intrusion_for_ice(san, ice, events)
		return true
	if not attack.deck_attack_enabled or not san.active or san.deck_link_state == SystemAccessNode.DeckLinkState.SEVERED:
		return true
	var defenses_breached: bool = attack.deck_breach_power >= san.access_security_level + int(defense.access_resistance) and san.integrity <= attack.deck_breach_integrity_threshold
	if not defenses_breached:
		events.append(_event(&"ICE_DECK_ATTACK_BLOCKED", ice, true, {"san_id": san.id}))
		return true
	var deck: RefCounted = san_deck_hardware.get(san.id) as RefCounted
	if deck == null:
		events.append(_event(&"ICE_DECK_LINK_UNRESOLVED", ice, false, {"san_id": san.id}))
		return true
	var mitigated := san_defense_controller.mitigate_deck_damage(san, attack.physical_deck_damage) if san_defense_controller != null else {"reduction": 0, "delivered_damage": attack.physical_deck_damage}
	var damage: Dictionary = deck.apply_physical_damage(int(mitigated.delivered_damage))
	if attack.component_degradation > 0: deck.degrade_component(&"DECK_LINK", attack.component_degradation)
	if not attack.temporary_disable_id.is_empty() and attack.temporary_disable_duration > 0.0:
		deck.add_temporary_fault(attack.temporary_disable_id, attack.temporary_disable_duration, {"source_ice_id": ice.instance_id})
	var programs: Array[StringName] = []
	for entry: DeckStorageEntry in san.deck_accessible_storage.entries_of_kind(DeckStorageEntry.Kind.PROGRAM): programs.append(entry.id)
	programs.sort()
	for index in mini(attack.program_corruption_count, programs.size()):
		deck.corrupt_program(programs[index])
		var entry := san.deck_accessible_storage.get_entry(programs[index]); if entry != null: entry.corrupted = true
	events.append(_event(&"ICE_DECK_LINK_ATTACK", ice, true, {"san_id": san.id, "hardware_damage": damage.applied, "remaining_deck_integrity": deck.integrity, "component_degradation": attack.component_degradation, "programs_corrupted": deck.corrupted_program_ids.duplicate()}))
	if deck.integrity <= attack.force_disconnect_integrity_threshold:
		_abort_intrusion_for_ice(san, ice, events)
	return true

func _abort_intrusion_for_ice(san: SystemAccessNode, ice: IceInstance, events: Array[Dictionary]) -> void:
	var intrusion := san_intrusions.get(san.id) as IntrusionSession
	if intrusion != null: intrusion.abort("ICE forced disconnect through System Access Node.", {"ice_id": ice.instance_id, "san_id": san.id})
	if san.active: san_manager.destroy_san(san.id)
	events.append(_event(&"ICE_FORCED_DISCONNECT", ice, true, {"san_id": san.id, "owner_actor_id": san.owner_player_id}))

func _detect_player(ice: IceInstance, events: Array[Dictionary], exact: bool) -> void:
	ice.forget_trail()
	ice.last_known_player_position = ice.known_player_position
	ice.known_player_position = player_position.current_node_id
	ice.target_node_id = player_position.current_node_id
	ice.alert_level = mini(100, ice.alert_level + (45 if exact else 25))
	pending_trace_increase += 2 if exact else 1
	player_knowledge.report_ice(ice.instance_id, ice.current_node_id, ice.state)
	events.append(_event(&"PLAYER_DETECTED" if exact else &"PLAYER_SIGNAL_ACQUIRED", ice, true, {"exact": exact}))

func _track_hacker_trail(ice: IceInstance, time_units: int, events: Array[Dictionary]) -> void:
	var profile := ice.definition.trail_tracking
	if profile == null or not profile.enabled or trail_system == null: return
	if san_manager != null:
		for san in san_manager.get_active_at(ice.current_node_id, trail_intrusion_id):
			if trail_target_actor_id.is_empty() or san.owner_player_id == trail_target_actor_id:
				ice.target_node_id = ice.current_node_id; ice.state = IceState.Value.ENGAGE; ice.forget_trail()
				events.append(_event(&"SAN_FOUND", ice, false, {"san_id": san.id, "owner_actor_id": san.owner_player_id}))
				return
	var target_owner := ice.trail_target_actor_id if not ice.trail_target_actor_id.is_empty() else trail_target_actor_id
	var candidates := trail_system.detect_trails(profile.tracking_quality, ice.current_node_id, trail_intrusion_id, ice.instance_id, false, {
		"detection_threshold": profile.detection_threshold,
		"current_tick": simulation_tick,
		"max_age": profile.max_age,
		"owner_actor_id": target_owner,
		"outbound_only": true,
	})
	if not candidates.is_empty():
		var trail: TrailSegment = candidates[0]
		ice.followed_trail_segment_id = trail.id; ice.trail_last_detected_tick = simulation_tick
		ice.trail_memory_remaining = profile.memory_ticks; ice.trail_tracking_confidence = trail.detection_score(profile.tracking_quality)
		ice.target_node_id = trail.to_node_id
		events.append(_event(&"HACKER_TRAIL_ACQUIRED", ice, false, {"trail_id": trail.id, "target_node_id": trail.to_node_id, "apparent_owner_actor_id": trail.apparent_owner_actor_id, "confidence": ice.trail_tracking_confidence}))
		return
	if not ice.followed_trail_segment_id.is_empty():
		ice.trail_memory_remaining = maxi(0, ice.trail_memory_remaining - time_units)
		if ice.trail_memory_remaining == 0:
			ice.forget_trail(); ice.target_node_id = &""
			events.append(_event(&"HACKER_TRAIL_LOST", ice, false, {}))

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
