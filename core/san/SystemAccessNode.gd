class_name SystemAccessNode
extends RefCounted

enum DeckLinkState { ACTIVE, SUSPENDED, DISCONNECTED }

var id: StringName
var owner_player_id: StringName
var intrusion_id: StringName
var deck_id: StringName
var host_node_id: StringName
var integrity := 100
var defensive_systems: Array = []
var deck_link_state := DeckLinkState.ACTIVE
var created_at: float

func _init(p_id: StringName, owner: StringName, intrusion: StringName, deck: StringName, host: StringName, timestamp := 0.0) -> void:
	id = p_id
	owner_player_id = owner
	intrusion_id = intrusion
	deck_id = deck
	host_node_id = host
	created_at = timestamp

