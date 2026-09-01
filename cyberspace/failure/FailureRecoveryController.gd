class_name FailureRecoveryController
extends RefCounted

signal crash_cache_created(node_id: StringName, resources: Dictionary)
signal crash_cache_recovered(node_id: StringName, resources: Dictionary)
signal forced_disconnect(failure_node_id: StringName, reconnect_node_id: StringName)

var crash_cache := CrashCache.new()
var anchors: AnchorController
var resources: PlayerResourceState
var position: PlayerNetworkPosition

func _init(p_anchors: AnchorController, p_resources: PlayerResourceState, p_position: PlayerNetworkPosition) -> void:
	anchors = p_anchors
	resources = p_resources
	position = p_position

func force_disconnect_at_current_node(tick: int) -> bool:
	if anchors.last_anchor_node_id == &"":
		return false
	var failure_node_id := position.current_node_id
	var dropped := resources.take_all_volatile()
	crash_cache.create_at(failure_node_id, dropped, tick)
	position.relocate(anchors.last_anchor_node_id)
	crash_cache_created.emit(failure_node_id, dropped)
	forced_disconnect.emit(failure_node_id, anchors.last_anchor_node_id)
	return true

func recover_at(node_id: StringName) -> Dictionary:
	if not crash_cache.active or crash_cache.node_id != node_id or position.current_node_id != node_id:
		return {}
	var recovered := crash_cache.resources.duplicate(true)
	resources.restore_volatile(recovered)
	crash_cache.clear()
	crash_cache_recovered.emit(node_id, recovered)
	return recovered
