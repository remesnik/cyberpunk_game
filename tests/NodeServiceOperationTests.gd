extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_expect(NodeServiceCatalog.ALL.size() == 19, "all supported node service types are canonical")
	_expect(PlayerOperationCatalog.ALL.size() == 29, "all generic player operations are canonical")
	_expect(PlayerOperationCatalog.is_supported("Run Program") and PlayerOperationCatalog.normalize("Unload Utility") == &"UNLOAD_UTILITY", "human-readable operation labels normalize to generic IDs")

	var node := NetworkNodeDefinition.new(&"COMMS_HOST", "Communications Host", NetworkNodeDefinition.NodeType.ROUTER, 3)
	node.network_type = &"COMMUNICATIONS"
	node.add_service_record({"id": &"LOGIN", "display_name": "Login", "service_type": &"AUTHENTICATION", "security_level": 3})
	node.add_service_record({"id": &"CALLS", "display_name": "Calls", "service_type": &"VOICE_COMMS", "security_level": 2})
	node.add_service_record({"id": &"AUDIT", "display_name": "Audit", "service_type": &"LOGGING", "security_level": 2, "supported_operations": [&"READ", &"FORGE"]})
	_expect(node.service_definitions.size() == 3 and node.services.size() == 3, "one node independently exposes multiple typed services")
	_expect(node.get_services_by_type(&"VOICE_COMMS").size() == 1 and node.network_type == &"COMMUNICATIONS", "service type remains independent from network type")
	_expect(node.get_services_by_type(&"AUTHENTICATION")[0].supports(&"SPOOF"), "service types receive generic default operations")
	_expect(node.get_services_by_type(&"LOGGING")[0].supported_operations == [&"READ", &"FORGE"], "authored operations can narrowly override service defaults")
	_expect(PassiveUtilityCatalog.definition(&"HERMES").supports_service(node.get_services_by_type(&"VOICE_COMMS")[0].service_type), "specialist utilities match service types after access")
	_expect(PassiveUtilityCatalog.definition(&"LOCKJAW_O").exploit_security_family == &"ORANGE" and not PassiveUtilityCatalog.definition(&"LOCKJAW_O").supports_service(&"VOICE_COMMS"), "exploit family affinity does not become service specialization")

	print("%s: %d node service/operation assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
