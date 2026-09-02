extends SceneTree

var failures := 0
var assertions := 0


func _init() -> void:
	var level := load("res://data/authoring/first_contact.tres") as CyberspaceContentDocument
	var cache: Dictionary = level.find_entry(&"FILE_CACHE_SOFTWARE_BUNDLE")
	var reward: Dictionary = level.find_entry(&"TUTORIAL_DOORSTOP_REWARD")
	var definition_data: Dictionary = level.find_entry(&"DOORSTOP_TUTORIAL_1_0")
	_expect(cache.node_id == &"FILE_CACHE" and cache.reward_ids == [&"LATCH_UTILITY_REWARD", &"TUTORIAL_DOORSTOP_REWARD"], "FILE_CACHE contains exactly the utility and Doorstop rewards")
	_expect(not reward.repeatable and reward.quantity == 1 and reward.probability == 1.0, "tutorial Doorstop is a guaranteed one-time reward")
	_expect(reward.pickup_text.contains("Disposable backdoor utility") and reward.pickup_text.contains("One use"), "Doorstop provides concise contextual inspection text")

	var doorstop := DoorstopDefinition.new(definition_data.id, definition_data.display_name, definition_data.version)
	doorstop.description = definition_data.description
	doorstop.burn_on_deploy = definition_data.burn_on_deploy
	doorstop.one_active_anchor_per_intrusion = definition_data.one_active_anchor_per_intrusion
	var utility_data: Dictionary = level.find_entry(&"ROUTE_SNIFFER_0_8")
	var utility := ProgramDefinition.new(utility_data.id, utility_data.display_name, utility_data.version)
	var inventory := ProgramInventory.new()
	var producer := SoftwareProgrammingManager.new()
	producer.configure(inventory, null)
	var utility_result := producer.grant_loot(utility, cache.id)
	var doorstop_result := producer.grant_loot(doorstop, cache.id)
	_expect(utility_result.success and doorstop_result.success, "generic program reward pipeline grants both cache items")
	_expect(utility_result.program_instance_id != doorstop_result.program_instance_id and inventory.all_instances().size() == 2, "each cache program receives an independent instance ID")
	_expect(inventory.get_instance(doorstop_result.program_instance_id).definition is DoorstopDefinition, "guaranteed reward produces a real Doorstop program instance")

	var sequence: Dictionary = level.find_entry(&"FIRST_CONTACT_SOFTWARE_CACHE")
	var placement_beat: Dictionary = sequence.beats.filter(func(beat): return beat.objective.get("id", &"") == &"CONTINUE_BEFORE_DOORSTOP")[0]
	_expect(placement_beat.objective.minimum_additional_nodes == 1 and not placement_beat.objective.doorstop_deployment_required, "player continues at least one node without forced deployment")
	_expect(not JSON.stringify(sequence).contains("DEPLOY_DOORSTOP"), "cache tutorial never issues a Doorstop deployment command")
	print("%s: %d First Contact software-cache assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
