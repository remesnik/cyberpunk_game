extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var story := PersistentGameState.new(); StoryModeNewGameInitializer.initialize(story)
	var free_roam := PersistentGameState.new(); FreeRoamNewGameInitializer.initialize(free_roam)
	var availability := ContentAvailability.new()
	availability.register_content(&"SHARED_VENDOR", &"AVAILABLE_IN_ALL_MODES")
	availability.register_content(&"CAMPAIGN_MISSION", &"STORY_ONLY")
	availability.register_content(&"DYNAMIC_JOB", &"FREE_ROAM_ONLY")
	availability.register_content(&"MODE_VENDOR", &"MODE_SPECIFIC_VARIANT", {&"STORY": &"STORY_VENDOR", &"FREE_ROAM": &"SANDBOX_VENDOR"})
	_expect(availability.is_content_available(&"SHARED_VENDOR", story) and availability.is_content_available(&"SHARED_VENDOR", free_roam), "all-mode content is shared")
	_expect(availability.is_content_available(&"CAMPAIGN_MISSION", story) and not availability.is_content_available(&"CAMPAIGN_MISSION", free_roam), "Story-only content is centrally gated")
	_expect(not availability.is_content_available(&"DYNAMIC_JOB", story) and availability.is_content_available(&"DYNAMIC_JOB", free_roam), "Free-Roam-only content is centrally gated")
	_expect(availability.resolve_content_id(&"MODE_VENDOR", story) == &"STORY_VENDOR" and availability.resolve_content_id(&"MODE_VENDOR", free_roam) == &"SANDBOX_VENDOR", "mode-specific variants resolve centrally")
	_expect(not availability.is_content_available(&"MISSING", story), "unregistered content fails closed")
	var condition := ConditionDefinition.new(&"FREE_MODE", ConditionDefinition.ConditionType.GAME_MODE, &"FREE_ROAM")
	_expect(condition.evaluate({"game_state": free_roam}) and not condition.evaluate({"game_state": story}), "generic prerequisite conditions can test mode")
	var document := CyberspaceContentDocument.new(); document.document_id = &"STORY_DOCUMENT"; document.availability = "STORY_ONLY"
	document.objectives = [{"id": &"INHERITED_OBJECTIVE"}]
	availability.register_document(document)
	_expect(availability.is_content_available(&"INHERITED_OBJECTIVE", story) and not availability.is_content_available(&"INHERITED_OBJECTIVE", free_roam), "authored entries inherit document availability")
	document.objectives = [{"id": &"SHARED_SIDE_JOB", "availability": &"AVAILABLE_IN_ALL_MODES"}]
	availability.register_document(document)
	_expect(availability.is_content_available(&"SHARED_SIDE_JOB", story) and availability.is_content_available(&"SHARED_SIDE_JOB", free_roam), "entries may override document availability")
	var mixed := CyberspaceContentDocument.new(); mixed.document_id = &"MIXED_NETWORK"; mixed.availability = "AVAILABLE_IN_ALL_MODES"
	mixed.network_nodes = [
		{"id": &"STORY_NODE", "display_name": "Story Node", "availability": &"STORY_ONLY", "tags": [&"ENTRY"]},
		{"id": &"SANDBOX_NODE", "display_name": "Sandbox Node", "availability": &"FREE_ROAM_ONLY", "tags": [&"ENTRY"]},
	]
	mixed.network_links = [{"id": &"CROSS_MODE_LINK", "source": &"STORY_NODE", "destination": &"SANDBOX_NODE"}]
	availability.register_document(mixed)
	var story_graph := AuthoredNetworkRuntimeBuilder.build_graph(mixed, func(id: StringName) -> bool: return availability.is_content_available(id, story))
	var sandbox_graph := AuthoredNetworkRuntimeBuilder.build_graph(mixed, func(id: StringName) -> bool: return availability.is_content_available(id, free_roam))
	_expect(story_graph.nodes.has(&"STORY_NODE") and not story_graph.nodes.has(&"SANDBOX_NODE"), "authored Story runtime filters Free-Roam-only locations")
	_expect(sandbox_graph.nodes.has(&"SANDBOX_NODE") and not sandbox_graph.nodes.has(&"STORY_NODE"), "authored Free Roam runtime filters Story-only locations")
	_expect(story_graph.links.is_empty() and sandbox_graph.links.is_empty(), "links cannot leak filtered locations across modes")
	print("%s: %d content availability assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
