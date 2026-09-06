extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var graph := NetworkGraph.new()
	var sphere := SphereDefinition.new(&"LOCAL", "Local")
	graph.add_sphere(sphere)
	for node_id in [&"ENTRY", &"NODE_2", &"NODE_5", &"PLAYER_NODE"]:
		graph.add_node(NetworkNodeDefinition.new(node_id, String(node_id), NetworkNodeDefinition.NodeType.SYSTEM, 2, true, &"CORP", sphere.id))
	graph.add_link(NetworkLinkDefinition.new(&"L1", &"ENTRY", &"NODE_2"))
	graph.add_link(NetworkLinkDefinition.new(&"L2", &"NODE_2", &"NODE_5"))
	graph.add_link(NetworkLinkDefinition.new(&"L3", &"NODE_5", &"PLAYER_NODE"))
	var knowledge := PlayerKnowledge.new()
	for node_id in [&"ENTRY", &"NODE_2", &"NODE_5", &"PLAYER_NODE"]: knowledge.reveal_node(graph.get_node(node_id), KnowledgeLevel.Value.IDENTIFIED)
	for link_id in [&"L1", &"L2", &"L3"]: knowledge.reveal_link(graph.get_link(link_id), KnowledgeLevel.Value.IDENTIFIED)
	var position := PlayerNetworkPosition.new(&"ENTRY", 20)
	var tick := {"value": 0}
	var trails := HackerTrailSystem.new()
	trails.default_decay_per_tick = 0.1
	trails.track_actor(position, &"PLAYER", &"RUN", func() -> int: return tick.value)
	graph.traverse(position, &"NODE_2")
	tick.value = 4
	graph.traverse(position, &"NODE_5")
	tick.value = 5
	graph.traverse(position, &"PLAYER_NODE")
	_expect(trails.segments.size() == 3, "real player traversal creates authoritative trail segments")
	var canvas := SphereMinimapCanvas.new()
	canvas.size = Vector2(340, 178)
	canvas.set_models(graph, position, knowledge)
	tick.value = 6
	canvas.set_trail_source(trails, &"PLAYER", &"RUN", func() -> int: return tick.value)
	var visible := canvas.visible_trail_segments()
	_expect(visible.size() == 3, "minimap consumes the local player's permitted trail from the trail system")
	_expect(canvas.trail_alpha_for(visible[2]) > canvas.trail_alpha_for(visible[0]), "newest trail segment renders more clearly than an older segment")
	var enemy := trails.leave_trail(&"RIVAL", &"RUN", &"NODE_2", &"NODE_5", 5)
	_expect(canvas.visible_trail_segments().size() == 3, "undetected enemy hacker trails do not leak onto the minimap")
	trails.mark_detected(enemy, &"PLAYER")
	_expect(canvas.visible_trail_segments().size() == 4, "a detected enemy trail becomes eligible for minimap rendering")
	canvas.set_own_trail_visible(false)
	_expect(canvas.visible_trail_segments() == [enemy], "own-trail setting hides local noise without hiding permitted detected trails")
	canvas.set_own_trail_visible(true)
	var before_decay := trails.segments.size()
	tick.value = 20
	_expect(trails.decay_trails(tick.value) > 0 and trails.segments.size() < before_decay, "normal trail decay removes expired segments without minimap-owned history")
	trails.untrack_actor(position)
	canvas.free()
	var transient := HackerTrailSystem.new()
	transient.track_actor(position, &"PLAYER", &"RUN", Callable())
	var tracker_ref: WeakRef = weakref(transient)
	transient = null
	_expect(tracker_ref.get_ref() == null, "tracked signal does not retain discarded trail system at shutdown")
	print("%s: %d Sphere minimap trail assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
