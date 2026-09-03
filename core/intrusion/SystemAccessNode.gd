class_name SystemAccessNode
extends RefCounted

enum DeckLinkState { CONNECTING, LINKED, DEGRADED, SEVERED }
enum VisualState { NORMAL, DEFENDED, UNDER_ATTACK, BREACHED, DAMAGED, DISCONNECTED }

var id: StringName
## Actor identifier. The name is retained for the initial player-facing model;
## NPC and rival hacker IDs are valid here as well.
var owner_player_id: StringName
var intrusion_id: StringName
var deck_id: StringName
var host_node_id: StringName
var integrity := 100
var maximum_integrity := 100
## Base difficulty before installed defenses are applied to hostile access attempts.
var access_security_level := 2
var defensive_systems: Array[SANDefenseInstance] = []
## Explicit deck-local boundary. This is deliberately not the owner's inventory.
var deck_accessible_storage: DeckAccessibleStorage
var deck_link_state: DeckLinkState = DeckLinkState.LINKED
var created_at := 0.0
var active := true
var metadata: Dictionary = {}
var under_attack := false
var breached_by_actor_ids: Array[StringName] = []

func _init(
		p_id: StringName,
		p_owner_player_id: StringName,
		p_intrusion_id: StringName,
		p_deck_id: StringName,
		p_host_node_id: StringName,
		p_created_at := 0.0,
		p_integrity := 100
) -> void:
	id = p_id
	owner_player_id = p_owner_player_id
	intrusion_id = p_intrusion_id
	deck_id = p_deck_id
	host_node_id = p_host_node_id
	created_at = p_created_at
	maximum_integrity = maxi(1, p_integrity)
	integrity = maximum_integrity
	deck_accessible_storage = DeckAccessibleStorage.new(deck_id, owner_player_id)

func relocate(new_host_node_id: StringName) -> bool:
	if not active or new_host_node_id.is_empty(): return false
	host_node_id = new_host_node_id
	return true

func apply_damage(amount: int) -> int:
	if not active or amount <= 0: return 0
	var before := integrity
	integrity = maxi(0, integrity - amount)
	if integrity == 0: destroy()
	return before - integrity

func destroy() -> void:
	active = false
	deck_link_state = DeckLinkState.SEVERED
	under_attack = false

func mark_under_attack(active_attack := true) -> void:
	under_attack = active_attack

func mark_breached(actor_id: StringName) -> void:
	if not actor_id.is_empty() and not breached_by_actor_ids.has(actor_id): breached_by_actor_ids.append(actor_id)

func visual_state() -> VisualState:
	if not active or deck_link_state == DeckLinkState.SEVERED: return VisualState.DISCONNECTED
	if under_attack: return VisualState.UNDER_ATTACK
	if not breached_by_actor_ids.is_empty(): return VisualState.BREACHED
	if integrity < maximum_integrity: return VisualState.DAMAGED
	if not defensive_systems.is_empty(): return VisualState.DEFENDED
	return VisualState.NORMAL

func connection_key() -> String:
	return "%s::%s" % [intrusion_id, owner_player_id]
