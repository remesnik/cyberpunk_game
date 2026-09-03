class_name SANDefenseInstance
extends RefCounted

enum State { ACTIVE, DISABLED, DESTROYED }

var id: StringName
var definition: SANDefenseDefinition
var state := State.ACTIVE
var integrity: int
var installed_at := 0.0
var metadata: Dictionary = {}

func _init(p_id: StringName, p_definition: SANDefenseDefinition, p_installed_at := 0.0) -> void:
	id = p_id; definition = p_definition; installed_at = p_installed_at
	integrity = definition.maximum_integrity if definition != null else 0

func is_operational() -> bool: return state == State.ACTIVE and integrity > 0

func apply_damage(amount: int) -> int:
	if not is_operational() or amount <= 0: return 0
	var before := integrity; integrity = maxi(0, integrity - amount)
	if integrity == 0: state = State.DESTROYED
	return before - integrity

func state_label() -> String: return State.keys()[state]
