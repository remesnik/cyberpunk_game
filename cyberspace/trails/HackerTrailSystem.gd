class_name HackerTrailSystem
extends RefCounted

signal trails_changed

var segments: Array[TrailSegment] = []
var default_strength := 1.0
var default_decay_per_tick := 0.08
var minimum_strength := 0.02
var _tracked_positions: Dictionary = {}

func leave_trail(owner_actor_id: StringName, intrusion_id: StringName, from_node_id: StringName, to_node_id: StringName, created_tick: int, strength := -1.0, false_trail := false) -> TrailSegment:
	if owner_actor_id == &"" or intrusion_id == &"" or from_node_id == &"" or to_node_id == &"" or from_node_id == to_node_id:
		return null
	var segment := TrailSegment.new(owner_actor_id, intrusion_id, from_node_id, to_node_id, created_tick, default_strength if strength < 0.0 else strength, default_decay_per_tick)
	segment.false_trail = false_trail
	segments.append(segment)
	trails_changed.emit()
	return segment

func track_actor(position: PlayerNetworkPosition, owner_actor_id: StringName, intrusion_id: StringName, tick_provider: Callable) -> void:
	if position == null or _tracked_positions.has(position): return
	# The position owns its signal callback. A strong capture of this tracker
	# would form tracker -> position -> callback -> tracker at application exit.
	var tracker_ref: WeakRef = weakref(self)
	var callback := func(from_node_id: StringName, to_node_id: StringName, link_id: StringName) -> void:
		if link_id == &"": return
		var tracker := tracker_ref.get_ref() as HackerTrailSystem
		if tracker == null: return
		var tick := int(tick_provider.call()) if tick_provider.is_valid() else 0
		tracker.leave_trail(owner_actor_id, intrusion_id, from_node_id, to_node_id, tick)
	_tracked_positions[position] = callback
	position.position_changed.connect(callback)

func untrack_actor(position: PlayerNetworkPosition) -> void:
	if position == null or not _tracked_positions.has(position): return
	var callback: Callable = _tracked_positions[position]
	if position.position_changed.is_connected(callback): position.position_changed.disconnect(callback)
	_tracked_positions.erase(position)

func mark_detected(segment: TrailSegment, observer_actor_id: StringName) -> bool:
	if segment == null or observer_actor_id == &"" or segment.detected_by_actor_ids.has(observer_actor_id): return false
	segment.detected_by_actor_ids.append(observer_actor_id)
	trails_changed.emit()
	return true

func detect_trails(observer_actor_id: StringName, node_id: StringName, tracking_capability: float, current_tick: int, max_age := 20, intrusion_id: StringName = &"") -> Array[TrailSegment]:
	var detected: Array[TrailSegment] = []
	for segment in segments:
		if intrusion_id != &"" and segment.intrusion_id != intrusion_id: continue
		if segment.from_node_id != node_id and segment.to_node_id != node_id: continue
		if current_tick - segment.created_tick > max_age: continue
		if segment.strength_at_tick(current_tick) < tracking_capability: continue
		mark_detected(segment, observer_actor_id)
		detected.append(segment)
	return detected

func follow_trail(observer_actor_id: StringName, current_node_id: StringName, current_tick: int, max_age := 20, intrusion_id: StringName = &"") -> Dictionary:
	var candidates: Array[TrailSegment] = []
	for segment in segments:
		if intrusion_id != &"" and segment.intrusion_id != intrusion_id: continue
		if segment.from_node_id != current_node_id: continue
		if not segment.is_visible_to(observer_actor_id): continue
		if current_tick - segment.created_tick > max_age or segment.strength_at_tick(current_tick) < minimum_strength: continue
		candidates.append(segment)
	if candidates.is_empty(): return {"success": false, "reason": "No detectable outbound trail."}
	candidates.sort_custom(func(a: TrailSegment, b: TrailSegment):
		var a_strength := a.strength_at_tick(current_tick); var b_strength := b.strength_at_tick(current_tick)
		return a.created_tick > b.created_tick if is_equal_approx(a_strength, b_strength) else a_strength > b_strength)
	var selected := candidates[0]
	return {"success": true, "segment": selected, "next_node_id": selected.to_node_id, "strength": selected.strength_at_tick(current_tick)}

func visible_trails_for(viewer_actor_id: StringName, intrusion_id: StringName, visible_node_ids: Array[StringName], current_tick: int, include_own := true) -> Array[TrailSegment]:
	var visible: Array[TrailSegment] = []
	for segment in segments:
		if segment.intrusion_id != intrusion_id: continue
		if not visible_node_ids.has(segment.from_node_id) or not visible_node_ids.has(segment.to_node_id): continue
		if segment.strength_at_tick(current_tick) < minimum_strength: continue
		if segment.owner_actor_id == viewer_actor_id:
			if include_own: visible.append(segment)
		elif segment.detected_by_actor_ids.has(viewer_actor_id):
			visible.append(segment)
	visible.sort_custom(func(a: TrailSegment, b: TrailSegment): return a.created_tick < b.created_tick)
	return visible

func decay_trails(current_tick: int) -> int:
	var removed := 0
	for index in range(segments.size() - 1, -1, -1):
		if segments[index].strength_at_tick(current_tick) < minimum_strength:
			segments.remove_at(index)
			removed += 1
	if removed > 0: trails_changed.emit()
	return removed
