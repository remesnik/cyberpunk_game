extends SceneTree

const SanController := preload("res://core/san/SystemAccessNodeController.gd")

var failures := 0
var assertions := 0

func _init() -> void:
	var graph := NetworkGraph.new()
	graph.add_node(NetworkNodeDefinition.new(&"ENTRY", "Entry", NetworkNodeDefinition.NodeType.GATEWAY, 1))
	graph.add_node(NetworkNodeDefinition.new(&"RELAY", "Relay", NetworkNodeDefinition.NodeType.ROUTER, 2))
	var knowledge := PlayerKnowledge.new()
	var controller: RefCounted = SanController.new(graph, knowledge, &"PLAYER")
	var created: Dictionary = controller.create_san(&"PLAYER", &"RUN", &"DECK", &"ENTRY", 4.0)
	var san: RefCounted = created.san
	_expect(created.success and controller.get_san(&"RUN") == san, "jack-in creates exactly one SAN for the intrusion")
	_expect(not controller.create_san(&"PLAYER", &"RUN", &"DECK", &"ENTRY").success, "a second SAN cannot be created for the same intrusion")
	_expect(knowledge.get_known_node_capabilities(&"ENTRY").has(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE), "local SAN appears through PlayerKnowledge")
	_expect(bool(knowledge.get_node_view(&"ENTRY").local_san_present), "local ownership marking is retained in the sanitized view")
	san.integrity = 73
	san.defensive_systems = [&"ICE_WALL"]
	var relocated: Dictionary = controller.relocate_san(&"RUN", &"RELAY")
	_expect(relocated.success and san.host_node_id == &"RELAY", "Doorstop-style relocation moves the existing SAN")
	_expect(san.integrity == 73 and san.defensive_systems == [&"ICE_WALL"], "SAN integrity and defenses move with the same instance")
	_expect(not knowledge.get_known_node_capabilities(&"ENTRY").has(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE), "old host loses the local SAN indicator")
	_expect(knowledge.get_known_node_capabilities(&"RELAY").has(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE), "new host gains the local SAN indicator")
	var visual := NodeVisual.new()
	visual.configure_view(knowledge.get_node_view(&"RELAY"), false, true, false)
	var assignments := visual.capability_socket_assignments()
	_expect(assignments[0].capability_type == NodeCapabilityType.Value.SYSTEM_ACCESS_NODE and assignments[0].socket == 0, "local SAN occupies the highest-priority preferred socket")
	_expect(visual.local_san_present, "node visual receives local ownership without changing node type or security style")
	var rival: RefCounted = controller.create_san(&"RIVAL", &"RIVAL_RUN", &"RIVAL_DECK", &"ENTRY").san as RefCounted
	_expect(not knowledge.get_known_node_capabilities(&"ENTRY").has(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE), "rival SAN remains hidden before discovery")
	controller.reveal_san_to_player(rival)
	_expect(knowledge.get_known_node_capabilities(&"ENTRY").has(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE) and not bool(knowledge.get_node_view(&"ENTRY").local_san_present), "discovered rival SAN uses normal knowledge rules without local ownership styling")
	var doorstop_created: Dictionary = controller.create_san(&"PLAYER", &"DOORSTOP_RUN", &"DECK", &"ENTRY")
	var inventory := ProgramInventory.new()
	var loadout := ProgramLoadout.new(2)
	var definition := DoorstopDefinition.new(&"DOORSTOP_TEST", "Doorstop", "1.0")
	var instance := ProgramInstance.new(&"DOORSTOP_SAN_RELOCATOR", definition)
	inventory.add_instance(instance)
	loadout.install(instance.instance_id, inventory)
	var doorstop := DoorstopController.new(inventory, loadout)
	doorstop.configure_san_controller(controller)
	var deployment: Dictionary = doorstop.deploy(instance.instance_id, &"DOORSTOP_RUN", &"RELAY", 5.0, {}, {"node_id": &"RELAY", "node_is_valid": true, "node_transition_unresolved": false, "modal_action_unresolved": false, "jack_out_prohibited": false})
	_expect(doorstop_created.success and deployment.success, "production Doorstop deployment relocates the intrusion SAN")
	_expect(controller.get_san(&"DOORSTOP_RUN").host_node_id == &"RELAY", "Doorstop SAN host matches its exact deployed node")
	_expect(not inventory.has_instance(instance.instance_id), "SAN relocation does not change Doorstop's one-shot burn behavior")
	visual.free()
	print("%s: %d SAN indicator assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
