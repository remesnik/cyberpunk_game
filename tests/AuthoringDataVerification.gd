extends SceneTree

const ValidatorScript := preload("res://addons/cyberspace_authoring/validators/AuthoringValidator.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	var document = load("res://data/authoring/server_facility_infiltration.tres")
	_expect(document is CyberspaceContentDocument, "authored scenario loads as a runtime-safe native Resource")
	_expect(document.network_nodes.size() == 7 and document.find_entry(&"GUARD_PHONE_CALL") != {}, "scenario bundle contains linked cyber and meatspace content")
	var issues: Array[Dictionary] = ValidatorScript.new().validate(document)
	_expect(not issues.any(func(issue): return issue.level == "ERROR"), "VALIDATE ALL finds no errors in the authored scenario")

	var broken := CyberspaceContentDocument.new()
	broken.network_nodes.assign([{"id": &"A"}, {"id": &"A"}])
	broken.network_links.assign([{"id": &"BROKEN_LINK", "source": &"A", "destination": &"MISSING", "traversal_cost": -1}])
	broken.realtime_endpoints.assign([{"id": &"BROKEN_ENDPOINT", "network_node_id": &"MISSING", "service_id": &"NO_SERVICE", "physical_location_id": &"NO_LOCATION"}])
	broken.team_operations.assign([{"id": &"BROKEN_ROUTE", "route": [{"from": &"HERE", "to": &"THERE", "travel_duration_seconds": 0.0}]}])
	var broken_issues: Array[Dictionary] = ValidatorScript.new().validate(broken)
	_expect(broken_issues.any(func(issue): return issue.message.contains("Duplicate ID")), "validator catches deliberately duplicated IDs")
	_expect(broken_issues.any(func(issue): return issue.category == "NETWORK" and issue.level == "ERROR"), "validator catches broken network references")
	_expect(broken_issues.any(func(issue): return issue.category == "MEATSPACE ENDPOINTS"), "validator catches broken endpoint references")
	_expect(broken_issues.any(func(issue): return issue.category == "TEAMS"), "validator catches invalid physical routes and durations")

	var state = load("res://data/authoring/server_facility_infiltration.editor_state.tres")
	_expect(state.graph_positions.has(&"CAMERA_SERVER") and not document.get_property_list().any(func(property): return property.name == "graph_positions"), "graph layout remains separate editor-only metadata")
	var new_player_nodes: Array = document.network_nodes.filter(func(node): return node.get("starting_discovery_state", &"UNKNOWN") != &"UNKNOWN")
	_expect(new_player_nodes.size() == 2 and not new_player_nodes.any(func(node): return node.id == &"PBX_SERVER"), "new-player knowledge preview does not leak hidden objective topology")
	_expect(not JSON.stringify(document.realtime_events).contains("CyberspaceClock"), "authored realtime events contain no CyberspaceClock dependency")

	print("%s: %d authoring data assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
