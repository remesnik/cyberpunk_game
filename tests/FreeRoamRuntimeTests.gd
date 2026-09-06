extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var game := get_node("/root/Game")
	game.create_new_game(GameMode.Value.FREE_ROAM)
	game.start_session()
	_expect(game.is_free_roam_mode() and game.active_content_document == null, "Free Roam does not load Story Mode content")
	_expect(game.is_content_available(&"FREE_ROAM_HOME") and not game.is_content_available(&"FIRST_CONTACT"), "central eligibility exposes Free Roam content and rejects Story content")
	_expect(game.game_domain == game.GameDomain.MEATSPACE, "runtime opens in meat-space deck management")
	_expect(game.network_graph.get_sphere(&"PUBLIC_MESH") != null and game.network_graph.get_sphere(&"INDUSTRIAL_MESH") != null, "broader world has multiple Spheres")
	_expect(game.network_graph.get_security_sleeve(&"PUBLIC_SLEEVE") != null, "shared Security Sleeve system is active")
	_expect(game.mission == null and game.facility_scenario == null, "authored campaign and fixed facility mission are bypassed")
	_expect(not game.realtime_process_manager.processes.has(&"TEAM_ALPHA_PROCESS") and not game.comms_manager.sessions.has(&"GUARD_PHONE_CALL"), "campaign prototype processes and dialogue are not injected")
	_expect(game.equipment_order_manager.vendors.size() > 0, "shared vendors and economy remain available")
	_expect(game.free_roam_job_board != null and game.free_roam_job_board.available_jobs().size() == 5, "static Free Roam job board is immediately available")
	var accepted: Dictionary = game.free_roam_job_board.accept_job(&"JOB_NETWORK_RECON_01")
	_expect(accepted.success and &"JOB_NETWORK_RECON_01" in game.persistent_game_state.world_state.active_job_ids, "a starter job can be accepted into persistent state")
	var restored := PersistentGameState.from_save_data(game.serialize_persistent_state())
	_expect(&"JOB_NETWORK_RECON_01" in restored.world_state.active_job_ids, "accepted job state survives persistence")
	_expect(_has_service(game.network_graph.get_node(&"JOB_BROKER"), &"PUBLIC_JOB_EXCHANGE") and _has_service(game.network_graph.get_node(&"ARCHIVE_NODE"), &"FREIGHT_DATASTORE"), "job source and target services exist in the playable graph")
	_expect(game.program_inventory.has_instance(&"FREEROAM_DOORSTOP_001") and game.program_inventory.get_instance(&"FREEROAM_DOORSTOP_001").definition is DoorstopDefinition, "starter Doorstop uses the production program type")
	_expect(game.san_controller != null and game.trail_system != null and game.ice_controller != null and game.meatspace_management != null, "SAN, trails, ICE, and meat-space systems remain shared")
	var panel := (load("res://ui/meatspace/MeatspaceManagementPanel.tscn") as PackedScene).instantiate()
	add_child(panel)
	await get_tree().process_frame
	_expect(panel.visible and panel.get_node("Margin/Rows/Title").text.contains("FREE ROAM"), "Free Roam presents its home deck-management entry screen")
	var entry: Dictionary = game.enter_free_roam_network()
	_expect(entry.success and game.game_domain == game.GameDomain.CLEAN_ROOM, "home entry opens the Clean-Room before the sandbox network")
	_expect(game.persistent_game_state.world_state.entry_state == &"CLEAN_ROOM", "Clean-Room entry state is persisted")
	_expect(game.enter_netspace_from_clean_room().success and game.game_domain == game.GameDomain.CYBERSPACE, "GO explicitly enters the sandbox network")
	panel.queue_free()
	game.end_session()
	print("%s: %d Free Roam runtime assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)

func _has_service(node: NetworkNodeDefinition, service_id: StringName) -> bool:
	for service: Dictionary in node.services:
		if StringName(service.get("id", &"")) == service_id: return true
	return false
