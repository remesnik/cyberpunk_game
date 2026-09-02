extends SceneTree

var failures := 0
var assertions := 0


func _init() -> void:
	_test_realtime_doorstop_programming_pipeline()
	print("%s: %d Doorstop programming assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_realtime_doorstop_programming_pipeline() -> void:
	var clock := RealtimeWorldClock.new()
	clock.start(true)
	var inventory := ProgramInventory.new()
	var programming := SoftwareProgrammingManager.new()
	programming.configure(inventory, clock)
	programming.maximum_queued_tasks = 3
	programming.add_resource(&"MEMORY_SHARD", 10)
	programming.add_resource(&"ROUTING_KERNEL", 4)
	var standard := _definition(&"DOORSTOP_STANDARD", "1.0", 5.0, &"UNCOMMON", 2)
	var hardened := _definition(&"DOORSTOP_HARDENED", "2.1", 9.0, &"RARE", 3)
	hardened.security_modifiers = {&"suspicion": -1}
	hardened.deployment_restrictions = {&"prohibited_node_ids": [&"BLACK_ICE_CORE"]}
	var first := programming.start_task(&"BUILD_STANDARD", standard)
	var second := programming.start_task(&"BUILD_HARDENED", hardened)
	_expect(first.success and first.duration == 5.0, "Doorstop programming starts with its definition duration")
	_expect(second.success and second.duration == 9.0, "a different Doorstop version uses its own duration")
	_expect(programming.tasks.size() == 2, "multiple Doorstop builds can be queued when capacity permits")
	_expect(programming.resources.MEMORY_SHARD == 5 and programming.resources.ROUTING_KERNEL == 2, "each queued recipe consumes its configured resources")
	clock.restore(6.0, true)
	programming.update()
	var collected_first := programming.collect(&"BUILD_STANDARD")
	_expect(collected_first.success and inventory.has_instance(collected_first.program_instance_id), "completed Doorstop task places an instance in inventory")
	_expect(programming.tasks.BUILD_HARDENED.state == SoftwareProgrammingTask.State.PROGRAMMING, "longer variant remains in progress on the same realtime clock")
	clock.restore(10.0, true)
	var collected_second := programming.collect(&"BUILD_HARDENED")
	_expect(collected_second.success and inventory.has_instance(collected_second.program_instance_id), "second completed build creates another owned instance")
	_expect(collected_first.program_instance_id != collected_second.program_instance_id, "programmed Doorstop copies receive unique instance IDs")
	_expect(inventory.get_instance(collected_first.program_instance_id).definition == standard and inventory.get_instance(collected_second.program_instance_id).definition == hardened, "instances retain their exact Doorstop version definitions")
	var loot := programming.grant_loot(standard, &"LEVEL_REWARD_CACHE")
	_expect(loot.success and inventory.has_instance(loot.program_instance_id), "Doorstop can also enter inventory through the generic loot/reward path")
	_expect(loot.program_instance_id not in [collected_first.program_instance_id, collected_second.program_instance_id], "loot and programmed instances share collision-safe unique identity generation")
	clock.free()


func _definition(id: StringName, version: String, duration: float, rarity: StringName, memory_cost: int) -> DoorstopDefinition:
	var definition := DoorstopDefinition.new(id, "Doorstop %s" % version, version)
	definition.rarity = rarity
	definition.programming_duration = duration
	definition.programming_recipe = {&"MEMORY_SHARD": memory_cost, &"ROUTING_KERNEL": 1}
	definition.programming_requirements = {&"minimum_deck_cpu": 1}
	definition.trace_modifiers = {&"deployment_trace": 0}
	definition.burn_on_deploy = true
	definition.destroy_anchor_on_return = true
	return definition


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
