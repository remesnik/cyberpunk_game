class_name ProgressionTestNetworkFactory
extends RefCounted

const ANCHOR := &"ANCHOR"
const ENTRY_ROUTER := &"ENTRY_ROUTER"
const TOOL_REPOSITORY := &"TOOL_REPOSITORY"
const ENCRYPTED_ARCHIVE := &"ENCRYPTED_ARCHIVE"
const IDENTITY_GATE := &"IDENTITY_GATE"

static func create_fixture() -> Dictionary:
	var graph := NetworkGraph.new()
	graph.add_node(NetworkNodeDefinition.new(ANCHOR, "Anchor", NetworkNodeDefinition.NodeType.GATEWAY, 0, true, &"PLAYER"))
	graph.add_node(NetworkNodeDefinition.new(ENTRY_ROUTER, "Entry Router", NetworkNodeDefinition.NodeType.ROUTER, 1, true, &"ARCHIVE_NET"))
	graph.add_node(NetworkNodeDefinition.new(TOOL_REPOSITORY, "Tool Repository", NetworkNodeDefinition.NodeType.SERVICE_CLUSTER, 1, true, &"ABANDONED"))
	graph.add_node(NetworkNodeDefinition.new(ENCRYPTED_ARCHIVE, "Encrypted Archive", NetworkNodeDefinition.NodeType.FILE_SERVER, 3, true, &"ARCHIVE_NET"))
	graph.add_node(NetworkNodeDefinition.new(IDENTITY_GATE, "Identity Gate", NetworkNodeDefinition.NodeType.AUTH_SERVER, 2, true, &"ARCHIVE_NET"))
	graph.get_node(TOOL_REPOSITORY).granted_capability_ids.append(CapabilityCatalog.DECRYPT)
	graph.get_node(ENCRYPTED_ARCHIVE).required_capabilities_all.append(CapabilityCatalog.DECRYPT)
	graph.get_node(IDENTITY_GATE).required_capabilities_any.append(CapabilityCatalog.SPOOF)
	graph.get_node(IDENTITY_GATE).accepted_credentials.append(&"ARCHIVE_CREDENTIAL")

	graph.add_link(NetworkLinkDefinition.new(&"ANCHOR_ENTRY", ANCHOR, ENTRY_ROUTER, false, false, false, false, true, 1))
	graph.add_link(NetworkLinkDefinition.new(&"EARLY_ENCRYPTED_BRANCH", ENTRY_ROUTER, ENCRYPTED_ARCHIVE, false, false, false, false, true, 2))
	graph.get_link(&"EARLY_ENCRYPTED_BRANCH").required_capabilities_all.append(CapabilityCatalog.DECRYPT)
	graph.add_link(NetworkLinkDefinition.new(&"ALTERNATE_TOOL_PATH", ENTRY_ROUTER, TOOL_REPOSITORY, false, false, false, false, true, 1))
	graph.add_link(NetworkLinkDefinition.new(&"ARCHIVE_IDENTITY_GATE", ENCRYPTED_ARCHIVE, IDENTITY_GATE, false, false, false, false, true, 1))
	graph.add_link(NetworkLinkDefinition.new(&"ARCHIVE_ANCHOR_SHORTCUT", ENCRYPTED_ARCHIVE, ANCHOR, true, true, false, false, true, 1))
	graph.get_link(&"ARCHIVE_ANCHOR_SHORTCUT").required_capabilities_all.append(CapabilityCatalog.DECRYPT)

	var player := PlayerNetworkPosition.new(ANCHOR, 20)
	var knowledge := PlayerKnowledge.new()
	for node_id in [ANCHOR, ENTRY_ROUTER, TOOL_REPOSITORY, ENCRYPTED_ARCHIVE]:
		knowledge.reveal_node(graph.get_node(node_id), KnowledgeLevel.Value.IDENTIFIED)
	for link_id in [&"ANCHOR_ENTRY", &"EARLY_ENCRYPTED_BRANCH", &"ALTERNATE_TOOL_PATH"]:
		knowledge.reveal_link(graph.get_link(link_id), KnowledgeLevel.Value.IDENTIFIED)
	var progression := GraphProgressionController.new(graph, player, knowledge)
	progression.register_shortcut_reveal(ENCRYPTED_ARCHIVE, &"ARCHIVE_ANCHOR_SHORTCUT")
	return {"graph": graph, "player": player, "knowledge": knowledge, "progression": progression, "capabilities": CapabilityCatalog.create_definitions()}
