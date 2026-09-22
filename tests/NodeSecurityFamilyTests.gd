extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var document := CyberspaceContentDocument.new()
	document.network_nodes.assign([{
		"id": &"COMMS", "display_name": "Communications", "node_type": &"SYSTEM",
		"network_type": &"COMMUNICATIONS", "security_family": &"PURPLE",
		"difficulty_rating": 4, "security_level": 1, "tags": [&"ENTRY"],
	}])
	var node := AuthoredNetworkRuntimeBuilder.build_graph(document).get_node(&"COMMS")
	_expect(node.network_type == &"COMMUNICATIONS" and node.security_family_name() == &"PURPLE" and node.difficulty_rating == 4, "node keeps independent network type, security family, and difficulty")
	_expect(node.security_level == 1, "difficulty does not overwrite the legacy security level")
	var knowledge := PlayerKnowledge.new()
	knowledge.reveal_node(node, KnowledgeLevel.Value.SCANNED)
	var known := knowledge.get_node_view(&"COMMS")
	_expect(known.network_type == &"COMMUNICATIONS" and known.security_family == &"PURPLE" and known.difficulty_rating == 4, "scanned player knowledge exposes all three node security fields")
	var lockjaw_o := ExploitUtilityCatalog.definition(&"LOCKJAW_O")
	var lockjaw_p := ExploitUtilityCatalog.definition(&"LOCKJAW_P")
	var sidecar_o := ExploitUtilityCatalog.definition(&"SIDECAR_O")
	var sidecar_p := ExploitUtilityCatalog.definition(&"SIDECAR_P")
	_expect(lockjaw_o.display_name == "Lockjaw-O" and lockjaw_p.display_name == "Lockjaw-P", "Orange and Purple Lockjaw utilities exist")
	_expect(sidecar_o.display_name == "Sidecar-O" and sidecar_p.display_name == "Sidecar-P", "Orange and Purple Sidecar utilities exist")
	_expect(lockjaw_o.utility_model == lockjaw_p.utility_model and lockjaw_o.utility_rating == lockjaw_p.utility_rating, "Lockjaw variants are mechanically identical apart from family")
	_expect(sidecar_o.utility_model == sidecar_p.utility_model and sidecar_o.utility_rating == sidecar_p.utility_rating, "Sidecar variants are mechanically identical apart from family")
	var matching := ExploitCompatibility.evaluate(node, lockjaw_p)
	var wrong_family := ExploitCompatibility.evaluate(node, lockjaw_o)
	_expect(matching.compatible and matching.family_bypass_bonus == lockjaw_p.utility_rating, "matching family contributes its utility rating")
	_expect(not wrong_family.compatible and wrong_family.family_bypass_bonus == 0, "wrong family remains usable but contributes no family benefit")
	var default_node := NetworkNodeDefinition.new(&"LEGACY", "Legacy", NetworkNodeDefinition.NodeType.SYSTEM, 3)
	_expect(default_node.security_family_name() == &"VIRAL" and default_node.difficulty_rating == 3, "legacy nodes migrate safely to VIRAL with their existing difficulty")
	print("%s: %d node security-family assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
