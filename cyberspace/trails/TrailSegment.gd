class_name TrailSegment
extends RefCounted

var owner_actor_id: StringName
var intrusion_id: StringName
var from_node_id: StringName
var to_node_id: StringName
var created_tick: int
var strength: float
var decay_per_tick: float
var false_trail := false
var detected_by_actor_ids: Array[StringName] = []

func _init(p_owner: StringName, p_intrusion: StringName, p_from: StringName, p_to: StringName, p_tick: int, p_strength := 1.0, p_decay_per_tick := 0.08) -> void:
	owner_actor_id = p_owner
	intrusion_id = p_intrusion
	from_node_id = p_from
	to_node_id = p_to
	created_tick = p_tick
	strength = clampf(p_strength, 0.0, 1.0)
	decay_per_tick = maxf(0.0, p_decay_per_tick)

func strength_at_tick(tick: int) -> float:
	return maxf(0.0, strength - float(maxi(0, tick - created_tick)) * decay_per_tick)

func is_visible_to(actor_id: StringName) -> bool:
	return owner_actor_id == actor_id or detected_by_actor_ids.has(actor_id)
