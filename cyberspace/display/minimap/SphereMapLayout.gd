class_name SphereMapLayout
extends RefCounted

## Returns stable normalized positions. Authored positions in Sphere metadata win;
## the deterministic ring fallback uses the complete persistent membership so
## newly learned nodes never reshuffle nodes already shown.
static func positions_for(graph: NetworkGraph, sphere_id: StringName) -> Dictionary:
	var result := {}
	if graph == null: return result
	var sphere := graph.get_sphere(sphere_id)
	if sphere == null: return result
	var authored: Dictionary = sphere.metadata.get("node_positions", {})
	var ids := sphere.node_ids.duplicate()
	ids.sort()
	for index in ids.size():
		var node_id: StringName = ids[index]
		var authored_value: Variant = authored.get(node_id, authored.get(String(node_id), null))
		if authored_value is Vector2:
			result[node_id] = _normalized(authored_value)
		elif authored_value is Array and authored_value.size() >= 2:
			result[node_id] = _normalized(Vector2(float(authored_value[0]), float(authored_value[1])))
		else:
			result[node_id] = _fallback_position(index, ids.size())
	return result

## Compact knowledge-only layout for player-facing maps. It deliberately does
## not reserve sockets for authoritative hidden members.
static func positions_for_known(known_node_ids: Array[StringName]) -> Dictionary:
	var result := {}
	var ids := known_node_ids.duplicate()
	ids.sort()
	for index in ids.size(): result[ids[index]] = _fallback_position(index, ids.size())
	return result

static func _fallback_position(index: int, count: int) -> Vector2:
	if count <= 1: return Vector2(0.5, 0.5)
	if index == 0: return Vector2(0.5, 0.5)
	var remaining := index - 1
	var ring := 1
	var capacity := 8
	while remaining >= capacity:
		remaining -= capacity
		ring += 1
		capacity = ring * 8
	var angle := -PI * 0.5 + TAU * float(remaining) / float(capacity)
	var ring_count := maxi(1, int(ceil((float(count) - 1.0) / 8.0)))
	var radius := 0.16 + 0.28 * float(ring - 1) / float(maxi(1, ring_count - 1))
	return Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * radius

static func _normalized(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, 0.06, 0.94), clampf(value.y, 0.08, 0.92))
