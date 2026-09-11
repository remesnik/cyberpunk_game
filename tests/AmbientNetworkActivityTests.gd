extends Node

var failures := 0
var assertions := 0
var positions := {
	TestNetworkFactory.PUBLIC_GATEWAY: Vector2(100, 100),
	TestNetworkFactory.ROUTER_A: Vector2(300, 100),
	TestNetworkFactory.WORKSTATION_01: Vector2(500, 180),
}

func _ready() -> void:
	var graph := TestNetworkFactory.create_graph()
	var original_positions := positions.duplicate(true)
	var activity := AmbientNetworkActivity.new()
	activity.maximum_events = 3
	add_child(activity)
	activity.configure(graph, func(id: StringName) -> Vector2: return positions.get(id, Vector2.INF), func() -> Array[StringName]:
		var ids: Array[StringName] = []
		ids.assign(positions.keys())
		return ids
	, func() -> Array[StringName]: return [TestNetworkFactory.PUBLIC_GATEWAY] as Array[StringName], func() -> Array[StringName]: return [&"GATEWAY_ROUTER", &"ROUTER_WS01"] as Array[StringName])
	_expect(activity.trigger(&"PACKET", {"from": TestNetworkFactory.PUBLIC_GATEWAY, "to": TestNetworkFactory.ROUTER_A, "link_id": &"GATEWAY_ROUTER"}), "packet traffic follows an existing visible connection")
	_expect(activity.trigger(&"SERVICE_PULSE", {"node_id": TestNetworkFactory.PUBLIC_GATEWAY}), "known service activity can pulse without changing node state")
	_expect(activity.trigger(&"REMOTE_SESSION", {"node_id": TestNetworkFactory.ROUTER_A, "role": &"MAINT"}), "remote process presence can enter a known node")
	_expect(activity.events.any(func(event: Dictionary) -> bool: return event.type == &"REMOTE_SESSION" and event.role == &"MAINT"), "authored remote roles remain identifiable without becoming interaction targets")
	_expect(activity.events.size() == 3 and graph.get_node(TestNetworkFactory.PUBLIC_GATEWAY) != null, "ambient activity is sparse and presentation-only")
	activity.trigger_alarm(TestNetworkFactory.ROUTER_A)
	_expect(activity.events.size() <= activity.maximum_events and activity.events.any(func(event: Dictionary) -> bool: return event.type in [&"ALARM", &"ALARM_ROUTE"]), "alarm activity propagates across visible topology within the activity cap")
	activity._process(10.0)
	_expect(activity.events.size() <= 1, "brief activity expires while the network remains idle")
	activity.observe_simulation_events([{"type": &"ICE_MOVED_DEBUG", "from": TestNetworkFactory.PUBLIC_GATEWAY, "to": TestNetworkFactory.ROUTER_A}])
	_expect(activity.events.any(func(event: Dictionary) -> bool: return event.type == &"ICE_TRANSIT"), "simulation-driven ICE movement is visualized on its real route")
	_expect(not activity.trigger(&"PACKET", {"from": TestNetworkFactory.PUBLIC_GATEWAY, "to": TestNetworkFactory.SECURITY_SERVER}), "activity never invents positions for undiscovered nodes")
	_expect(not activity.trigger(&"PACKET", {"from": TestNetworkFactory.PUBLIC_GATEWAY, "to": TestNetworkFactory.WORKSTATION_01}), "activity cannot jump across nonadjacent nodes")
	_expect(AmbientNetworkActivity.actor_color(AmbientNetworkActivity.ActorType.NORMAL) == Color("ffffff"), "normal-user traffic is canonically white")
	_expect(AmbientNetworkActivity.actor_color(AmbientNetworkActivity.ActorType.HACKER_UNKNOWN) == Color("ffd84d"), "unknown-hacker traffic is canonically yellow")
	_expect(AmbientNetworkActivity.actor_color(AmbientNetworkActivity.ActorType.HACKER_FRIENDLY) == Color("58e889"), "friendly-hacker traffic is canonically green")
	_expect(AmbientNetworkActivity.actor_color(AmbientNetworkActivity.ActorType.ICE) == Color("ff4d5f"), "ICE and security traffic is canonically red")
	activity.maximum_events = 6
	_expect(activity.trigger(&"PACKET", {"actor_type": AmbientNetworkActivity.ActorType.HACKER_UNKNOWN, "source_node": TestNetworkFactory.PUBLIC_GATEWAY, "destination_node": TestNetworkFactory.ROUTER_A, "speed": 1.2, "duration": 2.0, "payload_type": &"REMOTE_COPY"}), "typed traffic accepts explicit direction, speed, duration, and payload")
	_expect(activity.events.back().source_node == TestNetworkFactory.PUBLIC_GATEWAY and activity.events.back().destination_node == TestNetworkFactory.ROUTER_A, "typed packet direction remains attached to graph topology")
	_expect(positions == original_positions, "packet effects never mutate graph projection geometry")
	print("%s: %d ambient network activity assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
