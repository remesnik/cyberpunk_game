class_name SANDumpVictimContext
extends RefCounted

var owner_actor_id: StringName
var intrusion: IntrusionSession
var deck_hardware: RefCounted
## Optional game-rule hook. Return true to preserve the intrusion instead of aborting it.
var abort_override: Callable

func _init(p_owner_actor_id: StringName = &"", p_intrusion: IntrusionSession = null, p_deck_hardware: RefCounted = null) -> void:
	owner_actor_id = p_owner_actor_id
	intrusion = p_intrusion
	deck_hardware = p_deck_hardware
