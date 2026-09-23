class_name DeleteNodeCommand
extends NetworkAuthorCommand

var node_id: StringName
var removed_node: NetworkNodeDefinition
var removed_links: Array[NetworkLinkDefinition] = []
var sphere_memberships: Array[StringName] = []
var sleeve_memberships: Array[StringName] = []
var ice_snapshots: Array[Dictionary] = []

func _init(p_context: Dictionary = {}, p_node_id: StringName = &"") -> void:
	super(p_context); node_id = p_node_id

func execute() -> Dictionary:
	var live_graph := graph()
	var refusal := _refusal_reason(live_graph)
	if not refusal.is_empty(): return {"success": false, "reason": refusal}
	removed_node = live_graph.get_node(node_id)
	removed_links.clear(); sphere_memberships.clear(); sleeve_memberships.clear(); ice_snapshots.clear()
	for sphere: SphereDefinition in live_graph.spheres.values():
		if sphere.contains_node(node_id): sphere_memberships.append(sphere.id)
	for sleeve: SecuritySleeve in live_graph.security_sleeves.values():
		if sleeve.contains_node(node_id): sleeve_memberships.append(sleeve.id)
	var fallback := _surviving_neighbor(live_graph)
	var ice_controller := context.get("ice_controller") as IceController
	if ice_controller != null:
		for ice: IceInstance in ice_controller.instances.values().duplicate():
			if ice.current_node_id != node_id and ice.home_node != node_id and ice.target_node_id != node_id: continue
			ice_snapshots.append({"ice": ice, "present": ice_controller.instances.has(ice.instance_id), "current": ice.current_node_id, "home": ice.home_node, "target": ice.target_node_id, "operational": ice.operational})
			if ice.current_node_id == node_id:
				if ice.definition.is_host_bound() or fallback == &"": ice_controller.instances.erase(ice.instance_id)
				else: ice.current_node_id = fallback
			if ice.home_node == node_id: ice.home_node = fallback
			if ice.target_node_id == node_id: ice.target_node_id = &""
	for link_id: StringName in removed_node.connected_links.duplicate():
		var removed := live_graph.remove_link(link_id)
		if removed != null: removed_links.append(removed)
	removed_node = live_graph.remove_node(node_id)
	result = {"success": removed_node != null, "reason": "Node deleted" if removed_node != null else "Could not delete node", "node_id": node_id}
	return result

func undo() -> Dictionary:
	var live_graph := graph()
	if live_graph == null or removed_node == null or not live_graph.add_node(removed_node): return {"success": false, "reason": "Could not restore node"}
	for sphere_id in sphere_memberships:
		var sphere := live_graph.get_sphere(sphere_id); if sphere != null: sphere.register_node(node_id)
	for sleeve_id in sleeve_memberships:
		var sleeve := live_graph.get_security_sleeve(sleeve_id); if sleeve != null: sleeve.add_current_member(node_id)
	for link in removed_links: live_graph.add_link(link)
	var ice_controller := context.get("ice_controller") as IceController
	if ice_controller != null:
		for snapshot in ice_snapshots:
			var ice := snapshot.ice as IceInstance
			ice.current_node_id = snapshot.current; ice.home_node = snapshot.home; ice.target_node_id = snapshot.target; ice.operational = snapshot.operational
			if bool(snapshot.present): ice_controller.instances[ice.instance_id] = ice
	live_graph.display_update_requested.emit()
	return {"success": true, "reason": "Node restored"}

func _refusal_reason(live_graph: NetworkGraph) -> String:
	if live_graph == null or live_graph.get_node(node_id) == null: return "Node not found"
	if live_graph.nodes.size() <= 1: return "Cannot delete the network's only node"
	var position := context.get("position") as PlayerNetworkPosition
	if position != null and position.current_node_id == node_id: return "Cannot delete the author's current node"
	var anchor_controller := context.get("anchor_controller") as AnchorController
	if anchor_controller != null and anchor_controller.anchors.has(node_id): return "Cannot delete a registered anchor node"
	var san_controller: Variant = context.get("san_controller")
	if san_controller != null:
		for san: RefCounted in san_controller.sans_by_intrusion.values():
			if san.host_node_id == node_id: return "Cannot delete a System Access Node host"
	var boss: NetspaceBossEncounter = context.get("boss_encounter") as NetspaceBossEncounter
	if boss != null and boss.node_id == node_id: return "Cannot delete the active encounter node"
	for link: NetworkLinkDefinition in live_graph.links.values():
		if link.source == node_id or link.destination == node_id: continue
		for direction: TraversalDirectionDefinition in link.traversal_directions.values():
			if direction.controller_node_id == node_id or direction.remote_controller_node_id == node_id: return "Cannot delete a node controlling another path"
	return ""

func _surviving_neighbor(live_graph: NetworkGraph) -> StringName:
	var node := live_graph.get_node(node_id)
	if node == null: return &""
	for link_id in node.connected_links:
		var link := live_graph.get_link(link_id)
		if link == null: continue
		var candidate := link.destination if link.source == node_id else link.source
		if candidate != &"" and candidate != node_id: return candidate
	return &""
