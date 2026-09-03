class_name TrailSegment
extends RefCounted

var id: StringName
var owner_actor_id: StringName
var intrusion_id: StringName
var from_node_id: StringName
var to_node_id: StringName
var created_tick := 0
var strength := 1.0
var decay_per_tick := 0.1
var last_decay_tick := 0
var apparent_owner_actor_id: StringName
var concealment := 0.0
var false_trail := false
var active := true
var tags: Array[StringName] = []
var metadata: Dictionary = {}

func _init(p_id: StringName, p_owner: StringName, p_intrusion: StringName, p_from: StringName, p_to: StringName, p_tick: int, p_strength := 1.0, options: Dictionary = {}) -> void:
	id = p_id; owner_actor_id = p_owner; apparent_owner_actor_id = options.get("apparent_owner_actor_id", p_owner)
	intrusion_id = p_intrusion; from_node_id = p_from; to_node_id = p_to
	created_tick = p_tick; last_decay_tick = p_tick; strength = maxf(0.0, p_strength)
	decay_per_tick = maxf(0.0, float(options.get("decay_per_tick", 0.1)))
	concealment = maxf(0.0, float(options.get("concealment", 0.0)))
	false_trail = bool(options.get("false_trail", false)); metadata = options.get("metadata", {}).duplicate(true)
	tags.assign(options.get("tags", []))

func decay_to(tick: int) -> float:
	if not active or tick <= last_decay_tick: return strength
	strength = maxf(0.0, strength - float(tick - last_decay_tick) * decay_per_tick)
	last_decay_tick = tick
	if strength <= 0.0001: active = false
	return strength

func erase() -> void:
	strength = 0.0; active = false

func detection_score(tracking_capability: float) -> float:
	return maxf(0.0, strength + float(metadata.get("detection_modifier", 0.0)) - concealment) * maxf(0.0, tracking_capability)
