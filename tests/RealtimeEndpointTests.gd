extends SceneTree

const EndpointScript := preload("res://core/RealtimeEndpointDefinition.gd")
const ProcessScript := preload("res://core/RealtimeProcess.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_endpoint_discovery_is_knowledge_gated()
	print("%s: %d realtime endpoint assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_endpoint_discovery_is_knowledge_gated() -> void:
	var graph := TestNetworkFactory.create_graph()
	var position := PlayerNetworkPosition.new(TestNetworkFactory.PUBLIC_GATEWAY, 20)
	var knowledge := TestNetworkFactory.create_player_knowledge(graph)
	var ice := IceController.new(graph, position, knowledge)
	var process := ProcessScript.new(&"CAMERA_01", ProcessScript.ProcessType.VIDEO_FEED, "Camera 01")
	var processes := {process.id: process}
	var endpoint = EndpointScript.new(&"CAMERA_INTERFACE", EndpointScript.EndpointType.VIDEO, TestNetworkFactory.PUBLIC_GATEWAY, &"PUBLIC_RELAY", [&"CAMERA_01"] as Array[StringName])
	var endpoints := {endpoint.id: endpoint}
	var scanner := ScanSystem.new(graph, position, knowledge, ice, endpoints, processes)

	_expect(not knowledge.knows_realtime_endpoint(endpoint.id), "objective endpoint begins absent from player knowledge")
	_expect(not knowledge.knows_realtime_process(process.id), "objective process begins absent from player knowledge")
	var node_scan := scanner.perform_scan({"kind": ScanSystem.CURRENT_NODE, "node_id": position.current_node_id}, 2)
	knowledge.commit_scan(node_scan, graph, ice)
	_expect(not knowledge.knows_realtime_endpoint(endpoint.id), "scanning the node does not leak a service-bound endpoint")

	var service_contact: StringName = knowledge.service_records[&"PUBLIC_RELAY"].contact_id
	var service_scan := scanner.perform_scan({"kind": ScanSystem.SERVICE, "contact_id": service_contact}, 2)
	knowledge.commit_scan(service_scan, graph, ice)
	_expect(knowledge.knows_realtime_endpoint(endpoint.id), "scanning the linked service discovers its endpoint")
	_expect(knowledge.knows_realtime_process(process.id), "endpoint discovery adds a sanitized process record")
	_expect(process.elapsed_time == 0.0 and not process.discovered, "knowledge commitment does not mutate objective process state")


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
