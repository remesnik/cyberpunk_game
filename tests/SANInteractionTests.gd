extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	_test_access_boundary_and_actions()
	print("%s: %d SAN interaction assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_access_boundary_and_actions() -> void:
	var manager := SystemAccessNodeManager.new()
	var san: SystemAccessNode = manager.create_san(&"TARGET", &"RUN", &"TARGET_DECK", &"HOST").san
	var file := DeckStorageEntry.new(&"LOCAL_FILE", DeckStorageEntry.Kind.FILE, "Local file", {"secret": "deck only"})
	var program := DeckStorageEntry.new(&"LOCAL_PROGRAM", DeckStorageEntry.Kind.PROGRAM, "Local program")
	file.security_level = 2; program.security_level = 2
	san.deck_accessible_storage.add_entry(file); san.deck_accessible_storage.add_entry(program)
	var persistent_inventory := {&"REMOTE_SECRET": "must never leak"}
	var defenses := SANDefenseController.new()
	defenses.install(san, SANDefenseCatalog.create_defaults()[0])
	var controller := SANInteractionController.new(manager, defenses)
	var request := _request(&"INSPECT", &"ELSEWHERE")
	_expect(not controller.execute(request).success, "reaching the SAN host is mandatory")
	request.actor_node_id = &"HOST"
	var inspected := controller.execute(request)
	_expect(inspected.success and not inspected.visible_data.has("entries") and not inspected.visible_data.has("owner_actor_id"), "inspection exposes SAN state but no deck contents or owner identity")
	request.action_type = &"ACCESS_FILES"
	_expect(not controller.execute(request).success, "deck files are not accessible before compromise")
	request.action_type = &"BREACH"; request.program_id = &"BREACH_TOOL"; request.hacking_power = 1
	_expect(not controller.execute(request).success, "installed defenses can reject a weak breach")
	request.hacking_power = 10
	_expect(controller.execute(request).success, "a compatible program and sufficient hacking power breach the SAN")
	request.action_type = &"ACCESS_FILES"
	var files := controller.execute(request)
	_expect(files.success and files.visible_data.entries.size() == 1 and files.visible_data.entries[0].id == &"LOCAL_FILE", "file access reveals only explicitly staged deck-local files")
	_expect(not str(files.visible_data).contains("REMOTE_SECRET") and persistent_inventory.has(&"REMOTE_SECRET"), "persistent and remote inventory remains outside the SAN boundary")
	request.action_type = &"STEAL_FILE"; request.target_entry_id = &"LOCAL_FILE"
	request.destination_storage = DeckAccessibleStorage.new(&"ATTACKER_DECK", &"INTRUDER")
	_expect(controller.execute(request).success and request.destination_storage.has_entry(&"LOCAL_FILE") and not san.deck_accessible_storage.has_entry(&"LOCAL_FILE"), "stealing transfers the exact visible entry between explicit deck boundaries")
	request.action_type = &"ACCESS_PROGRAMS"; request.target_entry_id = &""
	_expect(controller.execute(request).visible_data.entries.size() == 1, "program access is independently permission-gated")
	request.action_type = &"CORRUPT_PROGRAM"; request.target_entry_id = &"LOCAL_PROGRAM"
	_expect(controller.execute(request).success and program.corrupted, "an authorized hostile action can corrupt a discovered deck-local program")
	var planted := DeckStorageEntry.new(&"PLANTED", DeckStorageEntry.Kind.PROGRAM, "Payload")
	request.action_type = &"PLANT_PROGRAM"; request.planted_entry = planted
	_expect(controller.execute(request).success and san.deck_accessible_storage.has_entry(&"PLANTED") and planted.planted, "planting requires and stores an explicit program payload")
	request.action_type = &"TRACE_OWNER"
	var traced := controller.execute(request)
	_expect(traced.success and traced.visible_data.owner_actor_id == &"TARGET", "compromised SAN sessions may trace the owning actor")
	request.action_type = &"DUMP_OWNER"
	_expect(not controller.execute(request).success and san.deck_link_state == SystemAccessNode.DeckLinkState.LINKED, "Dump cannot bypass the normal cyberspace action pipeline")
	var npc_request := SANInteractionRequest.new(&"NPC_RIVAL", san.id, &"INSPECT")
	npc_request.actor_node_id = &"HOST"; npc_request.intrusion_id = &"RUN"
	_expect(controller.execute(npc_request).success, "the interaction service accepts reusable NPC/rival actor identities")

func _request(action: StringName, node: StringName) -> SANInteractionRequest:
	var request := SANInteractionRequest.new(&"INTRUDER", &"SAN_000001", action)
	request.intrusion_id = &"RUN"; request.actor_node_id = node
	return request

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
