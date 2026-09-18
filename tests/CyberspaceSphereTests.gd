extends SceneTree

const AUTHORING_VALIDATOR := preload("res://addons/cyberspace_authoring/validators/AuthoringValidator.gd")

var failures := 0
var assertions := 0

func _init() -> void:
	_test_persistent_sphere_vs_mutable_sleeve()
	_test_multiple_spheres_and_validation()
	_test_authored_factory()
	print("%s: %d cyberspace Sphere assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_persistent_sphere_vs_mutable_sleeve() -> void:
	var graph := NetworkGraph.new()
	var sphere := SphereDefinition.new(&"CORP_DMZ", "Corporate DMZ", [&"ENTRY", &"ROUTER"], &"DMZ_SLEEVE")
	_expect(graph.add_sphere(sphere), "Sphere can be registered before its authored member nodes")
	var entry := NetworkNodeDefinition.new(&"ENTRY", "Entry", NetworkNodeDefinition.NodeType.GATEWAY, 1, true, &"CORP", sphere.id)
	var router := NetworkNodeDefinition.new(&"ROUTER", "Router", NetworkNodeDefinition.NodeType.ROUTER, 2, true, &"CORP", sphere.id)
	_expect(graph.add_node(entry) and graph.add_node(router), "nodes with valid persistent Sphere references are accepted")
	var sleeve := SecuritySleeve.new(&"DMZ_SLEEVE", "DMZ Security Sleeve", [&"ENTRY", &"ROUTER"])
	_expect(graph.add_security_sleeve(sleeve) and graph.validate_structure().is_empty(), "original sleeve and reciprocal Sphere membership validate")
	sleeve.remove_current_member(&"ROUTER")
	sleeve.set_state(SecuritySleeve.State.SPLIT)
	_expect(not sleeve.contains_node(&"ROUTER") and graph.sphere_for_node(&"ROUTER") == sphere and sphere.contains_node(&"ROUTER"), "splitting current sleeve membership does not rewrite persistent Sphere membership")
	sleeve.set_state(SecuritySleeve.State.DISABLED)
	_expect(graph.sphere_for_node(&"ENTRY") == sphere and graph.sphere_for_node(&"ROUTER") == sphere, "disabling a sleeve leaves its historical logical subnet intact")

func _test_multiple_spheres_and_validation() -> void:
	var legacy_graph := NetworkGraph.new()
	var legacy_node := NetworkNodeDefinition.new(&"LEGACY", "Legacy", NetworkNodeDefinition.NodeType.SYSTEM)
	legacy_graph.add_node(legacy_node)
	_expect(legacy_node.sphere_id == NetworkGraph.LEGACY_UNASSIGNED_SPHERE_ID and legacy_graph.sphere_for_node(legacy_node.id) != null, "legacy nodes receive explicit persistent fallback Sphere membership")
	var graph := NetworkGraph.new()
	var dmz := SphereDefinition.new(&"DMZ", "DMZ")
	var internal := SphereDefinition.new(&"INTERNAL", "Internal")
	graph.add_sphere(dmz); graph.add_sphere(internal)
	var public_node := NetworkNodeDefinition.new(&"PUBLIC", "Public", NetworkNodeDefinition.NodeType.GATEWAY, 1, false, &"CORP", dmz.id)
	var auth_node := NetworkNodeDefinition.new(&"AUTH", "Auth", NetworkNodeDefinition.NodeType.AUTH_SERVER, 4, false, &"CORP", internal.id)
	_expect(graph.add_node(public_node) and graph.add_node(auth_node) and graph.spheres.size() == 2, "one network supports multiple distinct Spheres")
	var invalid := NetworkNodeDefinition.new(&"BROKEN", "Broken", NetworkNodeDefinition.NodeType.SYSTEM, 1, false, &"CORP", &"MISSING")
	_expect(not graph.add_node(invalid) and graph.get_node(&"BROKEN") == null, "runtime graph rejects nodes that reference nonexistent Spheres")
	var document := CyberspaceContentDocument.new()
	document.document_id = &"BROKEN_SPHERE_DOC"
	document.network_nodes = [{"id": &"NODE_A", "sphere_id": &"DOES_NOT_EXIST"}]
	var issues: Array[Dictionary] = AUTHORING_VALIDATOR.new().validate(document)
	_expect(issues.any(func(issue): return issue.category == "SPHERES" and issue.level == "ERROR" and issue.message.contains("missing Sphere")), "authoring validation catches nonexistent Sphere references")

func _test_authored_factory() -> void:
	var document := CyberspaceContentDocument.new()
	document.document_id = &"SPHERE_FACTORY_TEST"
	document.spheres = [{"id": &"OPS_SPHERE", "display_name": "Operations", "node_ids": [&"ENTRY", &"OPS"], "original_security_sleeve_id": &"OPS_SLEEVE", "metadata": {"region": &"CORPORATE"}}]
	document.network_nodes = [
		{"id": &"ENTRY", "display_name": "Entry", "node_type": &"GATEWAY", "security_level": 1, "sphere_id": &"OPS_SPHERE", "services": []},
		{"id": &"OPS", "display_name": "Operations", "node_type": &"SYSTEM", "security_level": 3, "sphere_id": &"OPS_SPHERE", "services": []},
	]
	document.network_links = [{"id": &"ENTRY_OPS", "source": &"ENTRY", "destination": &"OPS"}]
	document.security_sleeves = [{"id": &"OPS_SLEEVE", "display_name": "Operations Sleeve", "current_members": [&"ENTRY"], "state": &"BREACHED"}]
	var built: Dictionary = AuthoredNetworkFactory.build(document, &"ENTRY")
	var graph: NetworkGraph = built.graph
	_expect(graph.get_node(&"OPS").sphere_id == &"OPS_SPHERE" and graph.get_sphere(&"OPS_SPHERE").contains_node(&"OPS"), "authored factory preserves node and Sphere membership")
	_expect(graph.get_security_sleeve(&"OPS_SLEEVE").state == SecuritySleeve.State.BREACHED and not graph.get_security_sleeve(&"OPS_SLEEVE").contains_node(&"OPS"), "factory loads current sleeve state independently of historical Sphere members")
	_expect(graph.validate_structure().is_empty(), "authored multi-layer network structure validates after construction")

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
