extends SceneTree

const VALIDATOR := preload("res://addons/cyberspace_authoring/validators/AuthoringValidator.gd")
const SPHERE_INSPECTOR := preload("res://addons/cyberspace_authoring/inspectors/SphereInspector.gd")
const NETWORK_WORKSPACE := preload("res://addons/cyberspace_authoring/workspaces/network/NetworkGraphWorkspace.gd")

var failures := 0
var assertions := 0

func _init() -> void:
	var document := CyberspaceContentDocument.new()
	document.spheres = [
		{"id": &"PUBLIC", "display_name": "Public", "original_security_sleeve_id": &"PUBLIC_SLEEVE", "metadata": {}},
		{"id": &"INTERNAL", "display_name": "Internal", "original_security_sleeve_id": &"INTERNAL_SLEEVE", "metadata": {}},
	]
	document.security_sleeves = [
		{"id": &"PUBLIC_SLEEVE", "display_name": "Public Sleeve", "current_members": [&"ENTRY"], "state": &"INTACT"},
		{"id": &"INTERNAL_SLEEVE", "display_name": "Internal Sleeve", "current_members": [&"AUTH"], "state": &"BREACHED"},
	]
	document.network_nodes = [
		{"id": &"ENTRY", "display_name": "Entry", "node_type": &"GATEWAY", "security_level": 1, "sphere_id": &"PUBLIC"},
		{"id": &"RELAY", "display_name": "Relay", "node_type": &"ROUTER", "security_level": 2, "sphere_id": &"PUBLIC"},
		{"id": &"AUTH", "display_name": "Auth", "node_type": &"AUTH_SERVER", "security_level": 4, "sphere_id": &"INTERNAL"},
	]
	document.network_links = [
		{"id": &"ENTRY_RELAY", "source": &"ENTRY", "destination": &"RELAY", "traversal_cost": 1},
		{"id": &"RELAY_AUTH", "source": &"RELAY", "destination": &"AUTH", "traversal_cost": 1},
	]
	var public_members := document.sphere_members(&"PUBLIC")
	_expect(public_members.size() == 2 and public_members.has(&"ENTRY") and public_members.has(&"RELAY"), "Sphere members are derived from canonical node sphere_id values")
	_expect(document.sphere_connections(&"PUBLIC").size() == 1 and document.sphere_connections(&"PUBLIC")[0].id == &"RELAY_AUTH", "cross-Sphere connections are derived from ordinary graph links")
	_expect(document.assign_node_to_sphere(&"RELAY", &"INTERNAL") and document.sphere_members(&"PUBLIC") == [&"ENTRY"] and document.sphere_members(&"INTERNAL").has(&"RELAY"), "assigning a node moves its single canonical Sphere membership")
	_expect(not document.assign_node_to_sphere(&"ENTRY", &"MISSING"), "authoring model rejects assignment to a missing Sphere")
	var issues := VALIDATOR.new().validate(document)
	_expect(issues.any(func(issue): return issue.category == "CROSS-SPHERE CONNECTIONS" and issue.entry_id == &"ENTRY_RELAY"), "validation identifies cross-Sphere links for author review")
	_expect(not issues.any(func(issue): return issue.level == "ERROR"), "valid Sphere and Sleeve references pass validation")

	var broken := CyberspaceContentDocument.new()
	broken.spheres = [
		{"id": &"bad id", "display_name": "Bad", "node_ids": [&"ORPHAN"], "original_security_sleeve_id": &"MISSING"},
		{"id": &"OTHER", "display_name": "Other", "node_ids": [&"ORPHAN"]},
	]
	broken.network_nodes = [{"id": &"ORPHAN", "sphere_id": &""}]
	var broken_issues := VALIDATOR.new().validate(broken)
	_expect(broken_issues.any(func(issue): return issue.message.contains("Sphere ID")), "validation rejects malformed Sphere IDs")
	_expect(broken_issues.any(func(issue): return issue.message.contains("multiple legacy Sphere")), "validation detects accidental multiple legacy membership")
	_expect(broken_issues.any(func(issue): return issue.message.contains("missing original Security Sleeve")), "validation catches invalid original Sleeve references")
	_expect(broken_issues.any(func(issue): return issue.message.contains("no persistent Sphere")), "validation reports nodes with no Sphere")

	var built := AuthoredNetworkFactory.build(document, &"ENTRY")
	_expect(built.graph.get_sphere(&"PUBLIC").node_ids == [&"ENTRY"], "runtime factory reconstructs membership from node sphere_id instead of duplicated Sphere lists")
	var inspector := SPHERE_INSPECTOR.new(); inspector.set_sphere(document, &"PUBLIC")
	var workspace := NETWORK_WORKSPACE.new(); workspace.set_models(document, AuthoringEditorState.new())
	_expect(inspector != null and workspace != null, "dedicated Sphere inspector and network visualization instantiate")
	inspector.free(); workspace.free()

	print("%s: %d Sphere authoring assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
