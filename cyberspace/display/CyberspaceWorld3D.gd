class_name CyberspaceWorld3D
extends SubViewportContainer

var viewport: SubViewport
var world_root: Node3D
var anchor_root: Node3D
var connection_root: Node3D
var camera_rig: Node3D
var camera: Camera3D
var anchors: Dictionary = {}
var connection_meshes: Dictionary = {}
var view_anchor := Vector3.ZERO
var pan_velocity := Vector3.ZERO
var camera_mode: StringName = &"FOLLOW"
var _graph_instance_id := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new(); viewport.name = "SpatialViewport"; viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	add_child(viewport)
	world_root = Node3D.new(); world_root.name = "FixedNetworkWorld"; viewport.add_child(world_root)
	anchor_root = Node3D.new(); anchor_root.name = "NodeAnchors"; world_root.add_child(anchor_root)
	connection_root = Node3D.new(); connection_root.name = "Connections"; world_root.add_child(connection_root)
	camera_rig = Node3D.new(); camera_rig.name = "NetspaceCameraRig"; world_root.add_child(camera_rig)
	camera = Camera3D.new(); camera.name = "TraversalCamera"; camera.fov = 55.0; camera.current = true; camera_rig.add_child(camera)
	camera.position = Vector3(0.0, 18.0, CyberspaceSpatialLayout.CAMERA_DISTANCE)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.0, -18.0), Vector3.UP)
	resized.connect(_sync_viewport_size)

func configure(graph: NetworkGraph, layout: CyberspaceSpatialLayout) -> void:
	if not is_node_ready(): await ready
	var graph_instance_id := graph.get_instance_id()
	if _graph_instance_id != 0 and _graph_instance_id != graph_instance_id:
		for child in anchor_root.get_children(): child.free()
		for child in connection_root.get_children(): child.free()
		anchors.clear(); connection_meshes.clear()
	_graph_instance_id = graph_instance_id
	for id_value: Variant in graph.nodes.keys():
		var id := StringName(id_value)
		if anchors.has(id): continue
		var anchor := Node3D.new(); anchor.name = String(id); anchor.position = layout.world_position(id)
		anchor.set_meta(&"node_id", id); anchor.set_meta(&"graph_depth", int(layout.depths.get(id, -1))); anchor.set_meta(&"lane", float(layout.lanes.get(id, 0.0)))
		anchor_root.add_child(anchor); anchors[id] = anchor
	for link_value: Variant in graph.links.keys():
		var link_id := StringName(link_value)
		if connection_meshes.has(link_id): continue
		var endpoints := layout.edge_world_endpoints(link_id)
		if endpoints.size() != 2: continue
		var mesh := ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		mesh.surface_set_color(Color(0.18, 0.78, 0.9, 0.48)); mesh.surface_add_vertex(endpoints[0]); mesh.surface_add_vertex(endpoints[1]); mesh.surface_end()
		var instance := MeshInstance3D.new(); instance.name = String(link_id); instance.mesh = mesh; connection_root.add_child(instance); connection_meshes[link_id] = instance

func set_camera_anchor(anchor_position: Vector3) -> void:
	if camera_rig == null: return
	view_anchor = anchor_position
	camera_rig.position = view_anchor

func begin_camera_motion(mode: StringName) -> void:
	camera_mode = mode; pan_velocity = Vector3.ZERO

func finish_camera_motion() -> void:
	camera_mode = &"FOLLOW"; pan_velocity = Vector3.ZERO

func pan(direction: Vector2, delta: float, discovered_ids: Array[StringName]) -> bool:
	var desired := Vector3(direction.x, 0.0, -direction.y).normalized() * 22.0
	pan_velocity = pan_velocity.move_toward(desired, 48.0 * delta)
	if direction == Vector2.ZERO: pan_velocity = pan_velocity.move_toward(Vector3.ZERO, 38.0 * delta)
	if pan_velocity.is_zero_approx(): return false
	camera_mode = &"PAN"
	view_anchor += pan_velocity * delta
	var bounds := discovered_bounds(discovered_ids, 16.0)
	view_anchor.x = clampf(view_anchor.x, bounds.position.x, bounds.end.x)
	view_anchor.z = clampf(view_anchor.z, bounds.position.y, bounds.end.y)
	camera_rig.position = view_anchor
	return true

func discovered_bounds(discovered_ids: Array[StringName], margin: float) -> Rect2:
	if discovered_ids.is_empty(): return Rect2(-margin, -margin, margin * 2.0, margin * 2.0)
	var first := (anchors[discovered_ids[0]] as Node3D).global_position
	var minimum := Vector2(first.x, first.z); var maximum := minimum
	for id: StringName in discovered_ids:
		if not anchors.has(id): continue
		var point := (anchors[id] as Node3D).global_position; var flat := Vector2(point.x, point.z)
		minimum = minimum.min(flat); maximum = maximum.max(flat)
	return Rect2(minimum - Vector2.ONE * margin, maximum - minimum + Vector2.ONE * margin * 2.0)

func set_discovered_nodes(discovered_ids: Array[StringName], graph: NetworkGraph) -> void:
	for link_value: Variant in connection_meshes:
		var link := graph.get_link(StringName(link_value))
		(connection_meshes[link_value] as MeshInstance3D).visible = link != null and discovered_ids.has(link.source) and discovered_ids.has(link.destination)

func screen_position(node_id: StringName) -> Vector2:
	var anchor := anchors.get(node_id) as Node3D
	if anchor == null or camera == null: return Vector2.ZERO
	return camera.unproject_position(anchor.global_position)

func camera_distance(node_id: StringName) -> float:
	var anchor := anchors.get(node_id) as Node3D
	return camera.global_position.distance_to(anchor.global_position) if anchor != null and camera != null else CyberspaceSpatialLayout.CAMERA_DISTANCE

func final_world_positions() -> Dictionary:
	var result := {}
	for id_value: Variant in anchors:
		var id := StringName(id_value); result[id] = (anchors[id] as Node3D).global_position
	return result

func debug_final_lines() -> PackedStringArray:
	var result := PackedStringArray(["[NET LAYOUT FINAL]"])
	var ids: Array = anchors.keys(); ids.sort_custom(func(a: Variant, b: Variant): return String(a) < String(b))
	for id_value: Variant in ids:
		var id := StringName(id_value); var anchor := anchors[id] as Node3D
		result.append("%s depth=%d lane=%.1f pos=%s" % [id, int(anchor.get_meta(&"graph_depth", -1)), float(anchor.get_meta(&"lane", 0.0)), anchor.global_position])
	return result

func _sync_viewport_size() -> void:
	if viewport != null: viewport.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
