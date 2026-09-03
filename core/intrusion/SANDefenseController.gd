class_name SANDefenseController
extends RefCounted

signal defense_installed(san: SystemAccessNode, defense: SANDefenseInstance)
signal owner_alerted(event: Dictionary)

var _sequence := 0

func install(san: SystemAccessNode, definition: SANDefenseDefinition, installed_at := 0.0, resource_pool: Dictionary = {}) -> Dictionary:
	if san == null or not san.active or definition == null or definition.id.is_empty(): return _failure("SAN defense installation is invalid.")
	if not _can_pay(definition.resource_costs, resource_pool): return _failure("Insufficient resources for SAN defense installation.")
	_pay(definition.resource_costs, resource_pool)
	_sequence += 1
	var instance := SANDefenseInstance.new(StringName("SAN_DEFENSE_%06d" % _sequence), definition, installed_at)
	san.defensive_systems.append(instance); defense_installed.emit(san, instance)
	return {"success": true, "reason": "SAN defense installed.", "defense": instance}

func access_resistance(san: SystemAccessNode, actor_kind: StringName = &"HOSTILE_HACKER") -> int:
	var resistance := 0
	for instance in _active(san):
		resistance += instance.definition.access_resistance
		if actor_kind == &"ICE": resistance += instance.definition.ice_resistance
		elif actor_kind == &"HOSTILE_HACKER": resistance += instance.definition.hostile_hacker_resistance
	return resistance

func interact(san: SystemAccessNode, actor_id: StringName, interaction_type: StringName, actor_kind: StringName = &"HOSTILE_HACKER") -> Dictionary:
	if san == null or not san.active: return _failure("System Access Node is unavailable.")
	var events: Array[Dictionary] = []
	if actor_id != san.owner_player_id:
		for instance in _active(san):
			if instance.definition.has_behavior(&"OWNER_ALERT"):
				var event := {"type": &"SAN_WATCHDOG_ALERT", "san_id": san.id, "owner_actor_id": san.owner_player_id, "interacting_actor_id": actor_id, "interaction_type": interaction_type, "detection_strength": instance.definition.detection_strength}
				events.append(event); owner_alerted.emit(event)
			if instance.definition.has_behavior(&"COUNTERATTACK") and instance.definition.counterattack_power > 0:
				events.append({"type": &"SAN_DEFENSE_COUNTERATTACK", "san_id": san.id, "target_actor_id": actor_id, "power": instance.definition.counterattack_power})
	return {"success": true, "reason": "SAN interaction evaluated.", "access_resistance": access_resistance(san, actor_kind), "events": events}

func apply_integrity_damage(san: SystemAccessNode, amount: int, attacker_kind: StringName = &"ICE") -> Dictionary:
	var reduction := 0
	for instance in _active(san):
		reduction += instance.definition.integrity_damage_reduction
		if attacker_kind == &"ICE": reduction += instance.definition.ice_resistance
		elif attacker_kind == &"HOSTILE_HACKER": reduction += instance.definition.hostile_hacker_resistance
	var delivered := maxi(0, amount - reduction)
	return {"requested_damage": amount, "reduction": mini(amount, reduction), "delivered_damage": san.apply_damage(delivered)}

func mitigate_deck_damage(san: SystemAccessNode, incoming_damage: int) -> Dictionary:
	var reduction := 0
	for instance in _active(san): reduction += instance.definition.deck_damage_reduction
	return {"incoming_damage": incoming_damage, "reduction": mini(maxi(incoming_damage, 0), reduction), "delivered_damage": maxi(0, incoming_damage - reduction)}

func trail_multiplier(san: SystemAccessNode) -> float:
	var multiplier := 1.0
	for instance in _active(san): multiplier *= instance.definition.trail_strength_multiplier
	return multiplier

func inspection_view(san: SystemAccessNode) -> Dictionary:
	if san == null: return {}
	var defenses: Array[Dictionary] = []
	for instance in san.defensive_systems:
		defenses.append({"id": instance.id, "definition_id": instance.definition.id, "display_name": instance.definition.display_name, "state": instance.state_label(), "integrity": instance.integrity})
	return {"id": san.id, "owner_actor_id": san.owner_player_id, "host_node_id": san.host_node_id, "integrity": san.integrity, "maximum_integrity": san.maximum_integrity, "integrity_percent": roundi(100.0 * san.integrity / float(san.maximum_integrity)), "deck_link_state": SystemAccessNode.DeckLinkState.keys()[san.deck_link_state], "visual_state": SystemAccessNode.VisualState.keys()[san.visual_state()], "defenses": defenses}

func display_view(san: SystemAccessNode, viewer_actor_id: StringName, access_level := SANAccessSession.AccessLevel.NONE) -> Dictionary:
	if san == null: return {}
	if viewer_actor_id == san.owner_player_id:
		var own := inspection_view(san); own["owner_label"] = "LOCAL"; own["is_local"] = true
		return own
	if access_level < SANAccessSession.AccessLevel.OBSERVED: return {}
	var view := {"id": san.id, "host_node_id": san.host_node_id, "owner_label": "REMOTE", "is_local": false, "visual_state": "NORMAL"}
	if access_level >= SANAccessSession.AccessLevel.BREACHED:
		view.merge({"owner_actor_id": san.owner_player_id, "integrity": san.integrity, "maximum_integrity": san.maximum_integrity, "integrity_percent": roundi(100.0 * san.integrity / float(san.maximum_integrity)), "deck_link_state": SystemAccessNode.DeckLinkState.keys()[san.deck_link_state], "visual_state": SystemAccessNode.VisualState.keys()[san.visual_state()]}, true)
	if access_level >= SANAccessSession.AccessLevel.DECK_ACCESS:
		view["defenses"] = inspection_view(san).defenses
	return view

func _active(san: SystemAccessNode) -> Array[SANDefenseInstance]:
	var result: Array[SANDefenseInstance] = []
	if san != null:
		for instance in san.defensive_systems:
			if instance != null and instance.is_operational(): result.append(instance)
	return result

func _can_pay(costs: Dictionary, pool: Dictionary) -> bool:
	for resource_id in costs:
		if int(pool.get(resource_id, 0)) < int(costs[resource_id]): return false
	return true

func _pay(costs: Dictionary, pool: Dictionary) -> void:
	for resource_id in costs: pool[resource_id] = int(pool.get(resource_id, 0)) - int(costs[resource_id])

func _failure(reason: String) -> Dictionary: return {"success": false, "reason": reason, "defense": null, "events": []}
