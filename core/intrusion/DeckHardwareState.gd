class_name DeckHardwareState
extends RefCounted

var deck_id: StringName
var maximum_integrity := 100
var integrity := 100
var temporary_faults: Array[Dictionary] = []
var corrupted_program_ids: Array[StringName] = []
var component_degradation: Dictionary = {}

func _init(p_deck_id: StringName = &"", p_integrity := 100) -> void:
	deck_id = p_deck_id
	maximum_integrity = maxi(1, p_integrity)
	integrity = maximum_integrity

func apply_physical_damage(amount: int) -> Dictionary:
	var before := integrity
	integrity = maxi(0, integrity - maxi(0, amount))
	return {"requested": maxi(0, amount), "applied": before - integrity, "remaining_integrity": integrity}

func add_temporary_fault(fault_id: StringName, duration: float, metadata: Dictionary = {}) -> void:
	if fault_id.is_empty(): return
	temporary_faults.append({"id": fault_id, "duration": maxf(0.0, duration), "metadata": metadata.duplicate(true)})

func corrupt_program(instance_id: StringName) -> bool:
	if instance_id.is_empty() or corrupted_program_ids.has(instance_id): return false
	corrupted_program_ids.append(instance_id)
	return true

func degrade_component(component_id: StringName, amount: int) -> int:
	if component_id.is_empty() or amount <= 0: return 0
	component_degradation[component_id] = int(component_degradation.get(component_id, 0)) + amount
	return int(component_degradation[component_id])
