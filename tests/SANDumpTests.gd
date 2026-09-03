extends Node

const DeckHardwareStateScript := preload("res://core/intrusion/DeckHardwareState.gd")
const DumpDefinitionScript := preload("res://core/intrusion/SANDumpDefinition.gd")
const DumpVictimContextScript := preload("res://core/intrusion/SANDumpVictimContext.gd")

var failures := 0
var assertions := 0

func _ready() -> void:
	_test_dump_resolution()
	_test_abort_override()
	print("%s: %d SAN Dump assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_dump_resolution() -> void:
	var fixture := _fixture()
	var clock: ActionClock = fixture.clock
	var request: SANInteractionRequest = fixture.request
	request.actor_node_id = &"ELSEWHERE"
	var unreachable: ActionResult = fixture.controller.resolve_dump_action(clock, _action(), request, fixture.victim, fixture.definition)
	_expect(not unreachable.success and clock.current_tick == 0, "attacker must reach the victim SAN before Dump")
	request.actor_node_id = &"HOST"
	fixture.controller.execute(request_for(request, &"INSPECT"))
	var breach := request_for(request, &"BREACH"); breach.program_id = &"BREACHER"; breach.hacking_power = 20
	fixture.controller.execute(breach)
	var no_capability: ActionResult = fixture.controller.resolve_dump_action(clock, _action(), request, fixture.victim, fixture.definition)
	_expect(not no_capability.success and no_capability.events_produced.any(func(event): return event.type == &"SAN_WATCHDOG_ALERT"), "SAN defenses resolve and alert before a missing Dump capability rejects the attack")
	request.capabilities.append(&"DUMP"); request.program_id = &"DUMP_UTILITY"; request.hacking_power = 1
	var resisted: ActionResult = fixture.controller.resolve_dump_action(clock, _action(), request, fixture.victim, fixture.definition)
	_expect(not resisted.success and fixture.san.active and fixture.victim.intrusion.lifecycle == IntrusionSession.Lifecycle.ACTIVE, "Dump is not guaranteed after access and can be resisted")
	request.hacking_power = 20
	var attacker_lines: Array[String] = []; var victim_lines: Array[String] = []
	fixture.controller.attacker_feedback.connect(func(_id, lines): attacker_lines.assign(lines))
	fixture.controller.victim_feedback.connect(func(_id, lines): victim_lines.assign(lines))
	var success: ActionResult = fixture.controller.resolve_dump_action(clock, _action(), request, fixture.victim, fixture.definition)
	_expect(success.success and success.time_spent == fixture.definition.action_cost and clock.current_tick == fixture.definition.action_cost, "successful Dump consumes normal cyberspace action time")
	_expect(success.events_produced.any(func(event): return event.type == &"ICE_UPDATE") and success.events_produced.any(func(event): return event.type == &"EVENTS_RESOLVED"), "successful Dump runs normal action simulation phases")
	_expect(fixture.victim.intrusion.lifecycle == IntrusionSession.Lifecycle.ABORTED, "forced disconnect aborts the victim intrusion through its normal lifecycle")
	_expect(not fixture.san.active and fixture.san.deck_link_state == SystemAccessNode.DeckLinkState.SEVERED, "successful Dump destroys the victim SAN")
	_expect(fixture.victim.deck_hardware.integrity == 91, "Link Shield mitigation is resolved before configurable deck surge damage")
	_expect(fixture.victim.deck_hardware.temporary_faults.size() == 1 and fixture.victim.deck_hardware.corrupted_program_ids == [&"PROGRAM_A"], "Dump exposes deterministic hardware-fault and program-corruption hooks")
	_expect(attacker_lines.has("DUMP COMPLETE") and victim_lines.has("CONNECTION LOST") and victim_lines.has("FORCED DISCONNECT"), "both attacker and victim receive explicit Dump feedback")
	var repeated: ActionResult = fixture.controller.resolve_dump_action(clock, _action(), request, fixture.victim, fixture.definition)
	_expect(not repeated.success, "a destroyed SAN cannot be dumped twice")

func _test_abort_override() -> void:
	var fixture := _fixture(false)
	var request: SANInteractionRequest = fixture.request
	fixture.controller.execute(request_for(request, &"INSPECT"))
	var breach := request_for(request, &"BREACH"); breach.program_id = &"BREACHER"; breach.hacking_power = 20
	fixture.controller.execute(breach)
	request.capabilities.append(&"DUMP"); request.program_id = &"DUMP_UTILITY"; request.hacking_power = 20
	fixture.victim.abort_override = func(_victim, _san, _request): return true
	var result: ActionResult = fixture.controller.resolve_dump_action(fixture.clock, _action(), request, fixture.victim, fixture.definition)
	_expect(result.success and fixture.victim.intrusion.lifecycle == IntrusionSession.Lifecycle.ACTIVE and not fixture.san.active, "an explicit game-rule override may preserve the intrusion while the SAN is still destroyed")

func _fixture(with_defenses := true) -> Dictionary:
	var manager := SystemAccessNodeManager.new()
	var san: SystemAccessNode = manager.create_san(&"VICTIM", &"RUN", &"DECK", &"HOST").san
	var program := DeckStorageEntry.new(&"PROGRAM_A", DeckStorageEntry.Kind.PROGRAM, "Victim program")
	san.deck_accessible_storage.add_entry(program)
	var defenses := SANDefenseController.new()
	if with_defenses:
		for definition in SANDefenseCatalog.create_defaults(): defenses.install(san, definition)
	var controller := SANInteractionController.new(manager, defenses)
	var intrusion := IntrusionSession.new(&"RUN"); intrusion.register_system_access_node(san)
	var victim: RefCounted = DumpVictimContextScript.new(&"VICTIM", intrusion, DeckHardwareStateScript.new(&"DECK"))
	var definition: Resource = DumpDefinitionScript.new(); definition.program_corruption_count = 1
	var request := SANInteractionRequest.new(&"ATTACKER", san.id, &"DUMP_OWNER")
	request.actor_node_id = &"HOST"; request.intrusion_id = &"RUN"
	var clock := ActionClock.new()
	clock.register_ice_updater(func(tick, _request): return [{"type": &"ICE_UPDATE", "tick": tick}])
	return {"controller": controller, "clock": clock, "request": request, "victim": victim, "definition": definition, "san": san}

func request_for(base: SANInteractionRequest, action: StringName) -> SANInteractionRequest:
	var request := SANInteractionRequest.new(base.actor_id, base.san_id, action)
	request.actor_node_id = base.actor_node_id; request.intrusion_id = base.intrusion_id
	return request

func _action() -> ActionRequest:
	return ActionRequest.new(&"ATTACKER", ActionRequest.ActionType.DUMP_SAN, null, 3)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
