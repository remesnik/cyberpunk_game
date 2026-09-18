extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var graph := NetworkGraph.new()
	var public_sphere := SphereDefinition.new(&"PUBLIC_SPHERE", "Public Services", [], &"PUBLIC_SLEEVE")
	var secure_sphere := SphereDefinition.new(&"SECURE_SPHERE", "Secure Services", [], &"SECURE_SLEEVE")
	graph.add_sphere(public_sphere); graph.add_sphere(secure_sphere)
	graph.add_node(NetworkNodeDefinition.new(&"ENTRY", "Entry", NetworkNodeDefinition.NodeType.GATEWAY, 1, true, &"CORP", public_sphere.id))
	graph.add_node(NetworkNodeDefinition.new(&"RELAY", "Relay", NetworkNodeDefinition.NodeType.ROUTER, 2, true, &"CORP", public_sphere.id))
	graph.add_node(NetworkNodeDefinition.new(&"VAULT", "Vault", NetworkNodeDefinition.NodeType.FILE_SERVER, 4, true, &"CORP", secure_sphere.id))
	graph.add_link(NetworkLinkDefinition.new(&"ENTRY_RELAY", &"ENTRY", &"RELAY"))
	graph.add_link(NetworkLinkDefinition.new(&"RELAY_VAULT", &"RELAY", &"VAULT"))
	graph.add_security_sleeve(SecuritySleeve.new(&"PUBLIC_SLEEVE", "Public Sleeve", [&"ENTRY", &"RELAY"]))
	graph.add_security_sleeve(SecuritySleeve.new(&"SECURE_SLEEVE", "Secure Sleeve", [&"VAULT"]))
	var player := PlayerNetworkPosition.new(&"ENTRY", 10)
	var tracker := CurrentSphereTracker.new(graph)
	var events: Array[Dictionary] = []
	tracker.sphere_changed.connect(func(player_id: StringName, previous: StringName, next: StringName, entry_node: StringName): events.append({"player_id": player_id, "previous_sphere_id": previous, "new_sphere_id": next, "entry_node_id": entry_node}))
	_expect(tracker.register_player(&"PLAYER", player), "player can register for current Sphere tracking")
	_expect(tracker.get_current_sphere(&"PLAYER") == public_sphere and tracker.get_current_sphere_id(&"PLAYER") == public_sphere.id, "current Sphere derives from occupied node sphere_id")
	var public_nodes := tracker.get_nodes_in_sphere(public_sphere.id)
	_expect(tracker.get_sphere_for_node(&"VAULT") == secure_sphere and public_nodes.size() == 2 and public_nodes.has(&"ENTRY") and public_nodes.has(&"RELAY"), "Sphere queries expose node lookup and persistent membership")
	graph.traverse(player, &"RELAY")
	_expect(tracker.get_current_sphere(&"PLAYER") == public_sphere and events.is_empty(), "movement within one Sphere does not emit a change")
	graph.get_security_sleeve(&"PUBLIC_SLEEVE").remove_current_member(&"RELAY")
	graph.get_security_sleeve(&"PUBLIC_SLEEVE").set_state(SecuritySleeve.State.SPLIT)
	_expect(tracker.get_current_sphere(&"PLAYER") == public_sphere and events.is_empty(), "Security Sleeve changes inside a Sphere do not change current Sphere")
	graph.traverse(player, &"VAULT")
	_expect(tracker.get_current_sphere(&"PLAYER") == secure_sphere and events.size() == 1, "cross-Sphere traversal updates current Sphere exactly once")
	_expect(events[0].previous_sphere_id == &"PUBLIC_SPHERE" and events[0].new_sphere_id == &"SECURE_SPHERE" and events[0].entry_node_id == &"VAULT", "sphere_changed contains previous, new, and entry node IDs")
	player.relocate(&"ENTRY")
	_expect(events.size() == 2 and events[1].new_sphere_id == &"PUBLIC_SPHERE", "direct relocation such as re-entry uses the same Sphere tracking path")
	var rival := PlayerNetworkPosition.new(&"VAULT", 5)
	tracker.register_player(&"RIVAL", rival)
	_expect(tracker.get_current_sphere(&"RIVAL") == secure_sphere and tracker.get_current_sphere(&"PLAYER") == public_sphere, "tracker maintains independent Sphere state for multiple actors")
	print("%s: %d current Sphere tracking assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
