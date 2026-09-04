class_name LargeGraphVisualizationFixture
extends RefCounted

const ALL_CAPABILITIES: Array[int] = [
	NodeCapabilityType.Value.IO, NodeCapabilityType.Value.FEED,
	NodeCapabilityType.Value.DATASTORE, NodeCapabilityType.Value.DATABASE,
	NodeCapabilityType.Value.MEATSPACE, NodeCapabilityType.Value.COMMUNICATIONS,
	NodeCapabilityType.Value.CONTROL_SYSTEM, NodeCapabilityType.Value.SECURITY,
	NodeCapabilityType.Value.ICE, NodeCapabilityType.Value.SOFTWARE,
	NodeCapabilityType.Value.CREDENTIALS, NodeCapabilityType.Value.ACTIVE_PROCESS,
	NodeCapabilityType.Value.SYSTEM_ACCESS_NODE, NodeCapabilityType.Value.OBJECTIVE,
]

static func generate(node_count: int) -> Dictionary:
	var graph := NetworkGraph.new()
	var views: Array[Dictionary] = []
	for index in node_count:
		var node_id := StringName("STRESS_%03d" % index)
		var node := NetworkNodeDefinition.new(node_id, "Stress Node %03d" % index, index % NetworkNodeDefinition.NodeType.size(), index % 6, index % 4 != 0, &"STRESS_CORP")
		graph.add_node(node)
		var capabilities: Array[int] = []
		var state := index % 4
		if state == 2:
			capabilities.assign([NodeCapabilityType.Value.IO, NodeCapabilityType.Value.FEED])
		elif state == 3:
			capabilities.assign(ALL_CAPABILITIES if index % 11 == 3 else [NodeCapabilityType.Value.DATABASE, NodeCapabilityType.Value.DATASTORE, NodeCapabilityType.Value.SECURITY])
		if index == 0 and not capabilities.has(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE): capabilities.append(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE)
		if index > 0 and index % 17 == 0 and not capabilities.has(NodeCapabilityType.Value.OBJECTIVE): capabilities.append(NodeCapabilityType.Value.OBJECTIVE)
		if index > 0 and index % 13 == 0 and not capabilities.has(NodeCapabilityType.Value.ICE): capabilities.append(NodeCapabilityType.Value.ICE)
		var counts := {}
		for capability: int in capabilities: counts[capability] = 3 if capability in [NodeCapabilityType.Value.FEED, NodeCapabilityType.Value.DATABASE] else 1
		views.append({
			"id": node_id,
			"display_name": node.display_name,
			"short_id": "N-%03d" % index,
			"identity_known": state > 0,
			"level_known": state in [1, 3],
			"security_level": node.security_level,
			"scanned": state >= 2,
			"visited": state == 3,
			"concise_status": "ACTIVE" if state == 3 else "",
			"unknown_content_count": 2 if state in [0, 2] else 0,
			"capability_types": capabilities,
			"capability_counts": counts,
			"local_san_present": index == 0,
		})
	for index in range(1, node_count):
		var parent := maxi(0, (index - 1) / 3)
		graph.add_link(NetworkLinkDefinition.new(StringName("LINK_%03d" % index), StringName("STRESS_%03d" % parent), StringName("STRESS_%03d" % index)))
	return {"graph": graph, "views": views}

static func grid_positions(node_count: int, viewport: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var aspect := viewport.x / maxf(viewport.y, 1.0)
	var columns := maxi(2, int(ceil(sqrt(float(node_count) * aspect))))
	var rows := maxi(1, int(ceil(float(node_count) / float(columns))))
	var cell := Vector2(viewport.x / columns, viewport.y / rows)
	for index in node_count:
		result.append(Vector2((index % columns + 0.5) * cell.x, (index / columns + 0.5) * cell.y))
	return result
