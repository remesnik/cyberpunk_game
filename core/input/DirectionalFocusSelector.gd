class_name DirectionalFocusSelector
extends RefCounted

static func choose(current_id: StringName, direction: Vector2, candidates: Array[Dictionary]) -> StringName:
	if candidates.is_empty() or direction.length() < 0.1: return &""
	var current_position := _position_for(current_id, candidates)
	if current_id == &"" or current_position == Vector2.INF:
		return StringName(candidates.reduce(func(best: Dictionary, item: Dictionary): return item if float(item.get("priority", 0.0)) > float(best.get("priority", 0.0)) else best, candidates[0]).id)
	var best_id: StringName = &""; var best_score := -INF
	var wanted := direction.normalized()
	for item: Dictionary in candidates:
		var id := StringName(item.get("id", &""))
		if id == current_id or not bool(item.get("enabled", true)): continue
		var delta := Vector2(item.position) - current_position
		if delta.length_squared() < 1.0: continue
		var alignment := wanted.dot(delta.normalized())
		if alignment < 0.28: continue
		var score := alignment * 1000.0 - delta.length() * 0.35 + float(item.get("priority", 0.0))
		if score > best_score: best_score = score; best_id = id
	return best_id

static func _position_for(id: StringName, candidates: Array[Dictionary]) -> Vector2:
	for item: Dictionary in candidates:
		if StringName(item.get("id", &"")) == id: return Vector2(item.position)
	return Vector2.INF
