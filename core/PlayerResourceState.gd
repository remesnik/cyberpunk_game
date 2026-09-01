class_name PlayerResourceState
extends RefCounted

var volatile_resources: Dictionary = {}
var stored_resources: Dictionary = {}

func add_volatile(resource_id: StringName, amount: int) -> void:
	if amount > 0:
		volatile_resources[resource_id] = int(volatile_resources.get(resource_id, 0)) + amount

func commit_all() -> Dictionary:
	var committed := volatile_resources.duplicate(true)
	for resource_id in volatile_resources:
		stored_resources[resource_id] = int(stored_resources.get(resource_id, 0)) + int(volatile_resources[resource_id])
	volatile_resources.clear()
	return committed

func take_all_volatile() -> Dictionary:
	var resources := volatile_resources.duplicate(true)
	volatile_resources.clear()
	return resources

func restore_volatile(resources: Dictionary) -> void:
	for resource_id in resources:
		add_volatile(resource_id, int(resources[resource_id]))
