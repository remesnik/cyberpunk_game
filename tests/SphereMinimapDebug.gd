extends Control

const MINIMAP_SCENE := preload("res://cyberspace/display/minimap/SphereMinimap.tscn")

var graph: NetworkGraph
var knowledge: PlayerKnowledge
var position_model: PlayerNetworkPosition
var sphere_tracker: CurrentSphereTracker
var trail_system: HackerTrailSystem
var san_controller: SystemAccessNodeController
var current_tick := 6
var reveal_all_discovery := false
var reveal_all_levels := false
var sleeves_restored := false
var ice_visible := true
var stale_visible := true

@onready var minimap_host: Control = %MinimapHost
@onready var status_label: RichTextLabel = %StatusLabel
var minimap: SphereMinimap

func _ready() -> void:
	_build_fixture()
	_bind_controls()
	_update_status("Fixture initialized: split Sleeve state, stable SPHERE_ALPHA membership.")

func _exit_tree() -> void:
	if trail_system != null and position_model != null: trail_system.untrack_actor(position_model)
	if sphere_tracker != null: sphere_tracker.unregister_player(&"PLAYER")

func _build_fixture() -> void:
	graph = NetworkGraph.new()
	graph.add_sphere(SphereDefinition.new(&"SPHERE_ALPHA", "Alpha Operations", [], &"ALPHA_ORIGINAL"))
	graph.add_sphere(SphereDefinition.new(&"SPHERE_BETA", "Beta Archive", [], &"BETA_SLEEVE"))
	for index in range(1, 11):
		var id := StringName("ALPHA_%02d" % index)
		graph.add_node(NetworkNodeDefinition.new(id, "Alpha Node %02d" % index, NetworkNodeDefinition.NodeType.SYSTEM, ((index - 1) % 5) + 1, false, &"CORP", &"SPHERE_ALPHA"))
	for index in range(1, 8):
		var id := StringName("BETA_%02d" % index)
		graph.add_node(NetworkNodeDefinition.new(id, "Beta Node %02d" % index, NetworkNodeDefinition.NodeType.SYSTEM, (index % 5) + 1, false, &"CORP", &"SPHERE_BETA"))
	_add_link(&"A01_A02", &"ALPHA_01", &"ALPHA_02")
	_add_link(&"A02_A03", &"ALPHA_02", &"ALPHA_03")
	_add_link(&"A03_A04", &"ALPHA_03", &"ALPHA_04")
	_add_link(&"A03_A05", &"ALPHA_03", &"ALPHA_05")
	_add_link(&"A04_A06", &"ALPHA_04", &"ALPHA_06")
	_add_link(&"A05_A07", &"ALPHA_05", &"ALPHA_07")
	_add_link(&"A06_A08", &"ALPHA_06", &"ALPHA_08")
	_add_link(&"A07_A09", &"ALPHA_07", &"ALPHA_09")
	_add_link(&"A08_A10", &"ALPHA_08", &"ALPHA_10")
	_add_link(&"ALPHA_BETA", &"ALPHA_09", &"BETA_01")
	for index in range(1, 7): _add_link(StringName("B%02d_B%02d" % [index, index + 1]), StringName("BETA_%02d" % index), StringName("BETA_%02d" % (index + 1)))
	graph.add_security_sleeve(SecuritySleeve.new(&"ALPHA_ORIGINAL", "Alpha Original Sleeve", [], SecuritySleeve.State.SPLIT))
	graph.add_security_sleeve(SecuritySleeve.new(&"ALPHA_CORE", "Alpha Core Sleeve", [&"ALPHA_01", &"ALPHA_02", &"ALPHA_03", &"ALPHA_04"], SecuritySleeve.State.INTACT))
	graph.add_security_sleeve(SecuritySleeve.new(&"ALPHA_EDGE", "Alpha Edge Sleeve", [&"ALPHA_05", &"ALPHA_06", &"ALPHA_07", &"ALPHA_08", &"ALPHA_10"], SecuritySleeve.State.INTACT))
	graph.add_security_sleeve(SecuritySleeve.new(&"BETA_SLEEVE", "Beta Sleeve", graph.get_nodes_in_sphere(&"SPHERE_BETA"), SecuritySleeve.State.INTACT))
	position_model = PlayerNetworkPosition.new(&"ALPHA_05", 100)
	sphere_tracker = CurrentSphereTracker.new(graph); sphere_tracker.register_player(&"PLAYER", position_model)
	trail_system = HackerTrailSystem.new()
	trail_system.leave_trail(&"PLAYER", &"DEBUG_RUN", &"ALPHA_01", &"ALPHA_02", 1, 1.0)
	trail_system.leave_trail(&"PLAYER", &"DEBUG_RUN", &"ALPHA_02", &"ALPHA_03", 3, 1.0)
	trail_system.leave_trail(&"PLAYER", &"DEBUG_RUN", &"ALPHA_03", &"ALPHA_05", 5, 1.0)
	trail_system.track_actor(position_model, &"PLAYER", &"DEBUG_RUN", func() -> int: return current_tick)
	_rebuild_knowledge()

func _rebuild_knowledge() -> void:
	var preserved_san_host: StringName = &"ALPHA_01"
	if san_controller != null and san_controller.get_san(&"DEBUG_RUN") != null: preserved_san_host = san_controller.get_san(&"DEBUG_RUN").host_node_id
	knowledge = PlayerKnowledge.new()
	knowledge.reveal_sphere_identity(graph.get_sphere(&"SPHERE_ALPHA"), &"DEBUG")
	knowledge.reveal_sphere_identity(graph.get_sphere(&"SPHERE_BETA"), &"DEBUG")
	var alpha_limit := 10 if reveal_all_discovery else 9
	for index in range(1, alpha_limit + 1):
		var node := graph.get_node(StringName("ALPHA_%02d" % index))
		knowledge.reveal_node(node, KnowledgeLevel.Value.IDENTIFIED)
		if reveal_all_levels or index in [1, 3, 5, 7]: knowledge.reveal_node_level(node, &"DEBUG_INTELLIGENCE")
	for link: NetworkLinkDefinition in graph.links.values():
		if knowledge.player_knows_node_exists(link.source) and knowledge.player_knows_node_exists(link.destination): knowledge.reveal_link(link, KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_node(graph.get_node(&"BETA_01"), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_link(graph.get_link(&"ALPHA_BETA"), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_node_capability(&"ALPHA_08", NodeCapabilityType.Value.OBJECTIVE, &"DEBUG_OBJECTIVE", &"OBJECTIVE_ALPHA")
	if ice_visible: knowledge.report_ice(&"ICE_ACTIVE", &"ALPHA_06", IceState.Value.HUNT, KnowledgeLevel.Value.IDENTIFIED, current_tick, 3)
	if stale_visible:
		knowledge.report_ice(&"ICE_STALE", &"ALPHA_04", IceState.Value.SEARCH, KnowledgeLevel.Value.IDENTIFIED, 0, 2)
		knowledge.advance_knowledge_time(current_tick)
	for sleeve_id in [&"ALPHA_ORIGINAL", &"ALPHA_CORE", &"ALPHA_EDGE", &"BETA_SLEEVE"]: knowledge.reveal_security_sleeve(graph.get_security_sleeve(sleeve_id), graph, &"DEBUG_SECURITY")
	san_controller = SystemAccessNodeController.new(graph, knowledge, &"PLAYER")
	san_controller.create_san(&"PLAYER", &"DEBUG_RUN", &"DEBUG_DECK", preserved_san_host)
	if minimap != null: minimap.queue_free()
	minimap = MINIMAP_SCENE.instantiate()
	minimap_host.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minimap.set_models(graph, position_model, knowledge, sphere_tracker)
	minimap.set_trail_source(trail_system, &"PLAYER", &"DEBUG_RUN", func() -> int: return current_tick)

func _add_link(id: StringName, source: StringName, destination: StringName) -> void:
	graph.add_link(NetworkLinkDefinition.new(id, source, destination))

func _bind_controls() -> void:
	%DiscoveryButton.pressed.connect(toggle_discovery)
	%LevelButton.pressed.connect(toggle_level_knowledge)
	%SleeveButton.pressed.connect(toggle_sleeves)
	%SanButton.pressed.connect(relocate_san)
	%PlayerButton.pressed.connect(move_player)
	%IceButton.pressed.connect(toggle_ice_detection)
	%StaleButton.pressed.connect(toggle_stale_intelligence)
	%SphereButton.pressed.connect(transition_sphere)

func toggle_discovery() -> void:
	reveal_all_discovery = not reveal_all_discovery; _rebuild_knowledge(); _update_status("Discovery: %s. Authoritative Alpha membership remains 10." % ("ALL ALPHA" if reveal_all_discovery else "PARTIAL"))

func toggle_level_knowledge() -> void:
	reveal_all_levels = not reveal_all_levels; _rebuild_knowledge(); _update_status("Level knowledge: %s." % ("ALL DISCOVERED NODES" if reveal_all_levels else "MIXED"))

func toggle_sleeves() -> void:
	sleeves_restored = not sleeves_restored
	if sleeves_restored:
		graph.restore_security_sleeve(&"ALPHA_ORIGINAL", graph.get_nodes_in_sphere(&"SPHERE_ALPHA"))
		graph.set_security_sleeve_state(&"ALPHA_CORE", SecuritySleeve.State.DISABLED); graph.set_security_sleeve_state(&"ALPHA_EDGE", SecuritySleeve.State.DISABLED)
	else:
		graph.get_security_sleeve(&"ALPHA_ORIGINAL").current_members.clear(); graph.set_security_sleeve_state(&"ALPHA_ORIGINAL", SecuritySleeve.State.SPLIT)
		graph.set_security_sleeve_state(&"ALPHA_CORE", SecuritySleeve.State.INTACT); graph.set_security_sleeve_state(&"ALPHA_EDGE", SecuritySleeve.State.INTACT)
	for sleeve_id in [&"ALPHA_ORIGINAL", &"ALPHA_CORE", &"ALPHA_EDGE"]: knowledge.reveal_security_sleeve(graph.get_security_sleeve(sleeve_id), graph, &"DEBUG_SECURITY")
	_update_status("Sleeve %s. SPHERE_ALPHA still has %d nodes; ALPHA_09 is %s." % ["RESTORED" if sleeves_restored else "BROKEN INTO TWO GROUPS", graph.get_nodes_in_sphere(&"SPHERE_ALPHA").size(), "PROTECTED" if sleeves_restored else "OUTSIDE CURRENT PROTECTION"])

func relocate_san() -> void:
	var san := san_controller.get_san(&"DEBUG_RUN")
	var destination: StringName = &"ALPHA_07" if san.host_node_id == &"ALPHA_01" else &"ALPHA_01"
	san_controller.relocate_san(&"DEBUG_RUN", destination)
	_update_status("SAN relocated to %s; player remains at %s." % [destination, position_model.current_node_id])

func move_player() -> void:
	var destination: StringName = &"ALPHA_03" if position_model.current_node_id == &"ALPHA_05" else &"ALPHA_05"
	current_tick += 1
	var known_link_ids: Array = knowledge.link_records.keys()
	var result := graph.traverse(position_model, destination, known_link_ids)
	_update_status("Player movement to %s: %s." % [destination, "OK" if result.error == NetworkGraph.TraversalError.OK else "BLOCKED"])

func toggle_ice_detection() -> void:
	ice_visible = not ice_visible; _rebuild_knowledge(); _update_status("Current ICE detection: %s." % ("VISIBLE" if ice_visible else "UNKNOWN"))

func toggle_stale_intelligence() -> void:
	stale_visible = not stale_visible; _rebuild_knowledge(); _update_status("Stale ICE intelligence: %s." % ("LAST KNOWN AT ALPHA_04" if stale_visible else "HIDDEN"))

func transition_sphere() -> void:
	var destination: StringName = &"ALPHA_10" if position_model.current_node_id.begins_with("BETA") else &"BETA_01"
	position_model.relocate(destination)
	if destination == &"BETA_01":
		knowledge.reveal_node(graph.get_node(&"BETA_01"), KnowledgeLevel.Value.IDENTIFIED)
		knowledge.reveal_security_sleeve(graph.get_security_sleeve(&"BETA_SLEEVE"), graph, &"DEBUG_SECURITY")
	minimap.set_models(graph, position_model, knowledge, sphere_tracker)
	_update_status("Sphere transition: %s. Minimap rebuilt for current Sphere only." % graph.get_node(destination).sphere_id)

func _update_status(message: String) -> void:
	var san := san_controller.get_san(&"DEBUG_RUN")
	status_label.text = "[color=#7df7c5]%s[/color]\nPLAYER: %s   SAN: %s   SPHERE: %s\nALPHA MEMBERS: %d   ALPHA_09 SPHERE: %s" % [message, position_model.current_node_id, san.host_node_id, graph.get_node(position_model.current_node_id).sphere_id, graph.get_nodes_in_sphere(&"SPHERE_ALPHA").size(), graph.get_node(&"ALPHA_09").sphere_id]
