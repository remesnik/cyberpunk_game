class_name HackerNPCManager
extends Node

const TutorialGuidanceStateScript = preload("res://core/story/TutorialGuidanceState.gd")

signal actor_added(actor: HackerNPC)
signal actor_appeared(actor_id: StringName, node_id: StringName)
signal actor_disappeared(actor_id: StringName, node_id: StringName)
signal actor_moved(actor_id: StringName, from_node_id: StringName, to_node_id: StringName, link_id: StringName)
signal communication_requested(actor_id: StringName, session_id: StringName)
signal pointer_requested(actor_id: StringName, target_type: StringName, target_id: StringName)
signal structured_event_emitted(event: Dictionary)
signal contextual_dialogue_requested(actor_id: StringName, reaction_id: StringName, lines: Array[Dictionary])
signal display_update_requested

var graph: NetworkGraph
var player_position: PlayerNetworkPosition
var player_knowledge: PlayerKnowledge
var actors: Dictionary = {}
var event_history: Array[Dictionary] = []
var action_index := 0
var _fired_reactions: Dictionary = {}
var _last_reaction_action: Dictionary = {}
var tutorial_guidance: RefCounted
var trail_system: HackerTrailSystem
var trail_intrusion_id: StringName
var trail_tick_provider: Callable


func configure(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge) -> void:
	graph = p_graph; player_position = p_position; player_knowledge = p_knowledge
	if player_position != null and not player_position.transition_completed.is_connected(_on_player_moved): player_position.transition_completed.connect(_on_player_moved)
	refresh_player_observations()

func configure_trails(p_trail_system: HackerTrailSystem, p_intrusion_id: StringName, p_tick_provider: Callable = Callable()) -> void:
	trail_system = p_trail_system; trail_intrusion_id = p_intrusion_id; trail_tick_provider = p_tick_provider


func add_actor(actor: HackerNPC) -> bool:
	if actor == null or actor.definition == null or actor.instance_id.is_empty() or actors.has(actor.instance_id): return false
	if not actor.current_node_id.is_empty() and (graph == null or graph.get_node(actor.current_node_id) == null): return false
	actors[actor.instance_id] = actor; actor_added.emit(actor); refresh_player_observations(); return true


func get_actor(actor_id: StringName) -> HackerNPC:
	return actors.get(actor_id) as HackerNPC

func detect_trails(actor_id: StringName, tracking_capability: float) -> Array[TrailSegment]:
	var actor := get_actor(actor_id)
	if actor == null or not actor.is_network_connected() or trail_system == null: return []
	return trail_system.detect_trails(tracking_capability, actor.current_node_id, trail_intrusion_id, actor_id)

func follow_trail(actor_id: StringName, tracking_capability: float) -> Dictionary:
	var actor := get_actor(actor_id)
	if actor == null or trail_system == null: return {"success": false, "node_path": [], "segments": [], "last_node_id": &""}
	return trail_system.follow_trail(actor.current_node_id, tracking_capability, trail_intrusion_id, actor_id)


func appear(actor_id: StringName, node_id: StringName) -> Dictionary:
	var actor := get_actor(actor_id)
	if actor == null: return _failure("Remote hacker actor does not exist.")
	if graph == null or graph.get_node(node_id) == null: return _failure("Remote hacker appearance node is invalid.")
	actor.previous_node_id = actor.current_node_id; actor.current_node_id = node_id; actor.state = HackerNPC.State.CONNECTED; actor.visible_signature = true
	if actor.movement_history.is_empty() or actor.movement_history[-1] != node_id: actor.movement_history.append(node_id)
	_emit_event(&"HACKER_APPEARED", actor_id, {"node_id": node_id}); actor_appeared.emit(actor_id, node_id); refresh_player_observations()
	return _success("Remote hacker appeared.")


func disappear(actor_id: StringName, disconnect := false) -> Dictionary:
	var actor := get_actor(actor_id)
	if actor == null or not actor.is_network_connected(): return _failure("Remote hacker is not connected.")
	var last_node := actor.current_node_id
	actor.visible_signature = false; actor.state = HackerNPC.State.DISCONNECTED if disconnect else HackerNPC.State.HIDDEN
	_emit_event(&"HACKER_DISAPPEARED", actor_id, {"node_id": last_node, "disconnected": disconnect}); actor_disappeared.emit(actor_id, last_node); refresh_player_observations()
	return _success("Remote hacker disappeared.")


func move_scripted(actor_id: StringName, destination_id: StringName) -> Dictionary:
	var actor := get_actor(actor_id)
	if actor == null or not actor.is_network_connected(): return _failure("Remote hacker is not connected.")
	if graph == null or graph.get_node(destination_id) == null: return _failure("Remote hacker destination is invalid.")
	var link := graph.find_link(actor.current_node_id, destination_id)
	if link == null or not link.connects_from(actor.current_node_id) or link.disabled: return _failure("Remote hacker scripted move requires an enabled directed graph link.")
	var origin := actor.current_node_id
	actor.previous_node_id = origin; actor.current_node_id = destination_id; actor.movement_history.append(destination_id)
	if trail_system != null:
		var tick := int(trail_tick_provider.call()) if trail_tick_provider.is_valid() else action_index
		trail_system.leave_trail(actor_id, trail_intrusion_id, origin, destination_id, tick)
	_emit_event(&"HACKER_MOVED", actor_id, {"from_node_id": origin, "node_id": destination_id, "link_id": link.id}); actor_moved.emit(actor_id, origin, destination_id, link.id); refresh_player_observations()
	return {"success": true, "reason": "Remote hacker moved.", "link_id": link.id}


func request_communication(actor_id: StringName, session_id: StringName) -> Dictionary:
	var actor := get_actor(actor_id)
	if actor == null or session_id.is_empty(): return _failure("Remote hacker communication request is invalid.")
	_emit_event(&"HACKER_COMMS_REQUESTED", actor_id, {"session_id": session_id, "channel_id": actor.definition.comms_channel_id}); communication_requested.emit(actor_id, session_id)
	return _success("Remote hacker communication requested.")


func point_out(actor_id: StringName, target_type: StringName, target_id: StringName) -> Dictionary:
	var actor := get_actor(actor_id)
	if actor == null or not actor.is_network_connected() or target_id.is_empty(): return _failure("Remote hacker pointer request is invalid.")
	if target_type == &"NODE":
		var node := graph.get_node(target_id) if graph != null else null
		if node == null: return _failure("Pointed-out network node does not exist.")
		player_knowledge.reveal_node(node, KnowledgeLevel.Value.DETECTED)
	_emit_event(&"HACKER_POINTED_OUT", actor_id, {"target_type": target_type, "target_id": target_id}); pointer_requested.emit(actor_id, target_type, target_id); display_update_requested.emit()
	return _success("Remote hacker pointed out a network contact.")


func emit_story_event(actor_id: StringName, event_type: StringName, payload: Dictionary = {}) -> Dictionary:
	if get_actor(actor_id) == null or event_type.is_empty(): return _failure("Remote hacker story event is invalid.")
	_emit_event(event_type, actor_id, payload); return _success("Remote hacker story event emitted.")


func handle_player_action(request: ActionRequest, result: ActionResult) -> void:
	action_index += 1
	for actor: HackerNPC in actors.values():
		var candidates: Array[Dictionary] = []
		for reaction: Dictionary in actor.definition.scripted_reactions:
			if _reaction_available(actor.instance_id, reaction) and _reaction_matches(reaction, request, result): candidates.append(reaction)
		_resolve_best_reaction(actor, candidates)


func handle_context_event(event: Dictionary) -> void:
	if tutorial_guidance != null:
		var guidance: Dictionary = tutorial_guidance.observe(event)
		if guidance.get("handled", false):
			var guide := get_actor(guidance.get("actor_id", &""))
			if guide != null:
				var lines: Array[Dictionary] = []
				lines.assign(guidance.get("lines", []))
				if not lines.is_empty(): contextual_dialogue_requested.emit(guide.instance_id, guidance.rule_id, lines)
				for command: Dictionary in guidance.get("commands", []): execute_scripted_command(guide.instance_id, command)
				_emit_event(&"TUTORIAL_GUIDANCE", guide.instance_id, guidance)
	for actor: HackerNPC in actors.values():
		var candidates: Array[Dictionary] = []
		for reaction: Dictionary in actor.definition.scripted_reactions:
			if _reaction_available(actor.instance_id, reaction) and _context_reaction_matches(reaction, event): candidates.append(reaction)
		_resolve_best_reaction(actor, candidates)


func configure_tutorial_guidance(authored_rules: Array[Dictionary]) -> void:
	tutorial_guidance = TutorialGuidanceStateScript.new()
	tutorial_guidance.configure(authored_rules)


func execute_scripted_command(actor_id: StringName, command: Dictionary) -> Dictionary:
	match StringName(command.get("type", &"")):
		&"APPEAR": return appear(actor_id, command.get("node_id", &""))
		&"DISAPPEAR": return disappear(actor_id, bool(command.get("disconnect", false)))
		&"MOVE": return move_scripted(actor_id, command.get("node_id", &""))
		&"COMMUNICATE": return request_communication(actor_id, command.get("session_id", &""))
		&"POINT_OUT": return point_out(actor_id, command.get("target_type", &"NODE"), command.get("target_id", &""))
		&"STORY_EVENT": return emit_story_event(actor_id, command.get("event_type", &"HACKER_EVENT"), command.get("payload", {}))
	return _failure("Unknown remote hacker script command.")


func refresh_player_observations() -> void:
	if player_knowledge == null or player_position == null: return
	for actor: HackerNPC in actors.values():
		if actor.visible_signature and actor.state == HackerNPC.State.CONNECTED and _is_local_and_known(actor.current_node_id): player_knowledge.observe_hacker(actor)
		else: player_knowledge.mark_hacker_absent(actor.instance_id)
	display_update_requested.emit()


func _is_local_and_known(node_id: StringName) -> bool:
	if node_id == player_position.current_node_id: return true
	return player_knowledge.knows_node(node_id) and graph.find_link(player_position.current_node_id, node_id) != null


func _reaction_matches(reaction: Dictionary, request: ActionRequest, result: ActionResult) -> bool:
	# Event-driven contextual reactions live beside action reactions in authored
	# data, but must never compete with an actual player-action response.
	if not reaction.has("action_type"): return false
	if reaction.has("success") and bool(reaction.success) != result.success: return false
	if reaction.has("action_type") and StringName(reaction.action_type) != StringName(request.get_action_name()): return false
	if reaction.has("target_id"):
		var target_id: StringName = request.target.get("node_id", request.target.get("service_id", request.target.get("contact_id", &""))) if request.target is Dictionary else StringName(request.target)
		if target_id != StringName(reaction.target_id): return false
	return true


func _context_reaction_matches(reaction: Dictionary, event: Dictionary) -> bool:
	if not reaction.has("event_type") or StringName(reaction.event_type) != StringName(event.get("type", &"")): return false
	if reaction.has("target_id") and StringName(reaction.target_id) != StringName(event.get("target_id", event.get("node_id", event.get("source_id", &"")))): return false
	if reaction.has("minimum_trace") and int(event.get("trace", 0)) < int(reaction.minimum_trace): return false
	if reaction.has("maximum_trace") and int(event.get("trace", 0)) > int(reaction.maximum_trace): return false
	if reaction.has("minimum_quantity") and int(event.get("quantity", 0)) < int(reaction.minimum_quantity): return false
	if reaction.has("allowed_actions") and StringName(event.get("action_type", &"")) not in reaction.allowed_actions: return false
	if reaction.has("excluded_node_ids") and event.get("node_id", &"") in reaction.excluded_node_ids: return false
	return true


func _reaction_available(actor_id: StringName, reaction: Dictionary) -> bool:
	var reaction_id: StringName = reaction.get("id", &"")
	if reaction_id.is_empty(): return false
	var key := StringName("%s::%s" % [actor_id, reaction_id])
	if bool(reaction.get("once", true)) and _fired_reactions.has(key): return false
	return action_index - int(_last_reaction_action.get(actor_id, -100000)) >= int(reaction.get("cooldown_actions", 0))


func _resolve_best_reaction(actor: HackerNPC, candidates: Array[Dictionary]) -> void:
	if candidates.is_empty(): return
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority_a := int(a.get("priority", 0)); var priority_b := int(b.get("priority", 0))
		return priority_a > priority_b if priority_a != priority_b else String(a.get("id", &"")) < String(b.get("id", &""))
	)
	var reaction: Dictionary = candidates[0]
	var reaction_id: StringName = reaction.id
	var key := StringName("%s::%s" % [actor.instance_id, reaction_id])
	_fired_reactions[key] = true
	_last_reaction_action[actor.instance_id] = action_index
	var lines: Array[Dictionary] = []
	for value: Variant in reaction.get("lines", []):
		if value is Dictionary: lines.append((value as Dictionary).duplicate(true))
		else: lines.append({"time": 0.0, "speaker_id": actor.definition.id, "text": String(value)})
	if not lines.is_empty(): contextual_dialogue_requested.emit(actor.instance_id, reaction_id, lines)
	for command: Dictionary in reaction.get("commands", []): execute_scripted_command(actor.instance_id, command)
	_emit_event(&"HACKER_CONTEXT_REACTION", actor.instance_id, {"reaction_id": reaction_id})


func _on_player_moved(_from: StringName, _to: StringName, _link: StringName) -> void: refresh_player_observations()
func _emit_event(type: StringName, actor_id: StringName, payload: Dictionary) -> void:
	var event := {"type": type, "actor_id": actor_id, "payload": payload.duplicate(true)}; event_history.append(event); structured_event_emitted.emit(event)
func _success(reason: String) -> Dictionary: return {"success": true, "reason": reason}
func _failure(reason: String) -> Dictionary: return {"success": false, "reason": reason}
