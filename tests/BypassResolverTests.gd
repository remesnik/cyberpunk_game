extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var profile := BypassProfile.new()
	profile.defense_roll_min = 0
	profile.defense_roll_max = 2
	var resolver := BypassResolver.new(profile)
	var purple := NetworkNodeDefinition.new(&"PURPLE_NODE", "Purple Node", NetworkNodeDefinition.NodeType.SYSTEM, 4)
	purple.network_type = &"ROUTING"
	purple.security_family = NetworkNodeDefinition.SecurityFamily.PURPLE
	var lockjaw := ProgramInstance.new(&"LOCKJAW_P_INSTANCE", ExploitUtilityCatalog.definition(&"LOCKJAW_P"))
	var correct := resolver.resolve(purple, 3, lockjaw, true, {}, 1)
	_expect(correct.success and not correct.noisy and correct.attack_value == 5 and correct.defense_value == 5, "correct installed exploit resolves quietly with rating")
	var failed := resolver.resolve(purple, 1, lockjaw, true, {}, 2)
	_expect(not failed.success and failed.noisy and not failed.generated_security_event.is_empty(), "failed compatible exploit generates a noisy security event")

	var sleeze_definition := ActiveBypassProgramCatalog.definition(&"SLEEZE")
	var sleeze := ProgramInstance.new(&"SLEEZE_INSTANCE", sleeze_definition)
	var stealth := resolver.resolve(purple, 3, sleeze, true, {}, 0)
	_expect(stealth.success and not stealth.noisy and stealth.approach == "STEALTH_PROGRAM", "installed Sleeze can perform a quiet bypass")
	_expect(sleeze_definition.storage_cost > 0 and sleeze_definition.memory_cost > 0 and sleeze_definition.consumes_active_slot, "Sleeze consumes Storage, Memory, and an Active Slot")

	var disguise_definition := ActiveBypassProgramCatalog.definition(&"DISGUISE")
	var disguise := ProgramInstance.new(&"DISGUISE_INSTANCE", disguise_definition)
	var identity := resolver.resolve(purple, 2, disguise, true, {"bypass_operations": [&"AUTHENTICATION"]}, 1)
	_expect(identity.success and not identity.noisy and identity.approach == "IDENTITY_PROGRAM" and identity.effective_rating == disguise_definition.utility_rating, "Disguise contributes its rating to supported identity operations")
	var unsupported_disguise := resolver.resolve(purple, 5, disguise, true, {"bypass_operations": [&"DATA_EXTRACTION"]}, 0)
	_expect(unsupported_disguise.success and unsupported_disguise.noisy and unsupported_disguise.effective_rating == 0, "Disguise is a bare noisy operation outside its data-driven support list")
	_expect(disguise_definition.storage_cost > 0 and disguise_definition.memory_cost > 0 and disguise_definition.consumes_active_slot, "Disguise consumes Storage, Memory, and an Active Slot")

	var bare := resolver.resolve(purple, 5, null, false, {}, 0)
	_expect(bare.success and bare.noisy and bare.utility_or_program_used == &"BARE_COMMAND", "bare command is allowed but noisy on success")
	var orange := ProgramInstance.new(&"LOCKJAW_O_INSTANCE", ExploitUtilityCatalog.definition(&"LOCKJAW_O"))
	var wrong := resolver.resolve(purple, 5, orange, true, {}, 0)
	_expect(wrong.success and wrong.noisy and wrong.effective_rating == 0, "wrong exploit family falls back to a noisy bare operation")
	var stored := resolver.resolve(purple, 5, lockjaw, false, {}, 0)
	_expect(stored.effective_rating == 0 and stored.noisy, "stored but uninstalled utility provides no bypass benefit")
	var preview := resolver.preview(purple, 3, lockjaw, true)
	_expect(preview.preview and preview.defense_roll_range == [0, 2], "preview uses the same resolver and exposes the tunable roll range")

	var clock := ActionClock.new()
	var action := ActionRequest.new(&"PLAYER", ActionRequest.ActionType.EXPLOIT, {}, 3)
	var action_result := clock.resolve_action(action, func(_request): return {"success": true}, func(_request): return {"success": false, "action_resolved": true, "reason": "Bypass failed", "details": failed, "events": [failed.generated_security_event]})
	_expect(not action_result.success and action_result.time_spent == 3 and clock.current_tick == 3 and action_result.details.node == &"PURPLE_NODE", "failed bypass remains a resolved time-consuming action with structured details")

	print("%s: %d bypass resolver assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
