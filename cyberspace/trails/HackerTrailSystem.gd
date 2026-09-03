class_name HackerTrailSystem
extends RefCounted

var segments: Array[TrailSegment] = []
var detection_threshold := 0.5
var default_decay_per_tick := 0.1
var _sequence := 0

func leave_trail(owner_actor_id: StringName, intrusion_id: StringName, from_node_id: StringName, to_node_id: StringName, created_tick: int, strength := 1.0, options: Dictionary = {}) -> TrailSegment:
	if owner_actor_id.is_empty() or intrusion_id.is_empty() or from_node_id.is_empty() or to_node_id.is_empty() or from_node_id == to_node_id: return null
	_sequence += 1
	var settings := options.duplicate(true)
	if not settings.has("decay_per_tick"): settings["decay_per_tick"] = default_decay_per_tick
	var segment := TrailSegment.new(StringName("TRAIL_%06d" % _sequence), owner_actor_id, intrusion_id, from_node_id, to_node_id, created_tick, strength, settings)
	segments.append(segment)
	return segment

func decay_trails(current_tick: int) -> int:
	var faded := 0
	for segment in segments:
		var was_active := segment.active
		segment.decay_to(current_tick)
		if was_active and not segment.active: faded += 1
	return faded

func detect_trails(tracking_capability: float, node_id: StringName = &"", intrusion_id: StringName = &"", observer_actor_id: StringName = &"", include_own := false, criteria: Dictionary = {}) -> Array[TrailSegment]:
	var detected: Array[TrailSegment] = []
	var threshold := float(criteria.get("detection_threshold", detection_threshold))
	var current_tick := int(criteria.get("current_tick", -1))
	var max_age := int(criteria.get("max_age", -1))
	var owner_actor_id: StringName = criteria.get("owner_actor_id", &"")
	var outbound_only := bool(criteria.get("outbound_only", false))
	for segment in segments:
		if not segment.active: continue
		if not intrusion_id.is_empty() and segment.intrusion_id != intrusion_id: continue
		if not owner_actor_id.is_empty() and segment.owner_actor_id != owner_actor_id: continue
		if max_age >= 0 and current_tick >= 0 and current_tick - segment.created_tick > max_age: continue
		if not node_id.is_empty() and (segment.from_node_id != node_id if outbound_only else segment.from_node_id != node_id and segment.to_node_id != node_id): continue
		if not include_own and not observer_actor_id.is_empty() and segment.owner_actor_id == observer_actor_id: continue
		if segment.detection_score(tracking_capability) >= threshold: detected.append(segment)
	detected.sort_custom(func(a: TrailSegment, b: TrailSegment) -> bool:
		return a.created_tick > b.created_tick if a.strength == b.strength else a.strength > b.strength
	)
	return detected

func follow_trail(start_node_id: StringName, tracking_capability: float, intrusion_id: StringName = &"", observer_actor_id: StringName = &"", maximum_steps := 32) -> Dictionary:
	var available := detect_trails(tracking_capability, &"", intrusion_id, observer_actor_id)
	var current := start_node_id
	var path: Array[StringName] = [current]
	var followed: Array[TrailSegment] = []
	var used: Dictionary = {}
	for _step in maximum_steps:
		var candidate: TrailSegment
		for segment in available:
			if not used.has(segment.id) and segment.from_node_id == current:
				candidate = segment; break
		if candidate == null: break
		used[candidate.id] = true; followed.append(candidate); current = candidate.to_node_id; path.append(current)
	return {"success": not followed.is_empty(), "node_path": path, "segments": followed, "last_node_id": current}

func erase_trail(segment_id: StringName) -> bool:
	for segment in segments:
		if segment.id == segment_id and segment.active: segment.erase(); return true
	return false
