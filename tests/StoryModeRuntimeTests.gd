extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var game := get_node("/root/Game")
	game.create_new_game(GameMode.Value.STORY)
	game.start_session()
	_expect(game.active_content_profile.get("kind", &"") == &"MEATSPACE_PROLOGUE" and game.prologue_controller != null, "Story Mode enters the authored bedroom prologue")
	_expect(game.is_content_available(&"FIRST_CONTACT") and not game.is_content_available(&"FREE_ROAM_HOME"), "central eligibility exposes Story content and rejects Free Roam content")
	_expect(game.player_network_position.current_node_id == &"PROLOGUE_LOCAL" and game.game_domain == game.GameDomain.MEATSPACE, "campaign begins in meat space rather than inside an intrusion")
	_expect(game.network_graph.get_node(&"PROLOGUE_LOCAL") != null and game.network_graph.get_node(&"OPS_SERVER") == null, "prologue uses only a private non-navigable runtime boundary")
	_expect(game.action_clock != null and game.realtime_world_clock != null and game.ice_controller != null, "shared sandbox simulation systems remain active")
	_expect(game.hacker_npc_manager.get_actor(&"LATCH_REMOTE_ACTOR") == null, "Latch is not spawned before the player requests guidance")
	_expect(game.mission == null and game.facility_scenario == null, "unrelated legacy campaign fixtures are not injected into authored Story content")
	_expect(not game.realtime_process_manager.processes.has(&"TEAM_ALPHA_PROCESS"), "facility prototype realtime actors are absent from FIRST_CONTACT")
	_expect(game.free_roam_job_board == null, "Free Roam job bootstrap is not injected into Story Mode")
	_expect(game.program_inventory.has_instance(&"STARTER_SERVICE_PROBE_001") and game.program_loadout.is_installed(&"STARTER_SERVICE_PROBE_001"), "starter inventory and loadout are applied to runtime")
	_expect(game.equipment_order_manager.credits == 500 and game.meatspace_management.hardware_levels.DECK_CPU == 1, "starter resources and hardware are applied")
	_expect(game.get_campaign_state().pending_entry_content_id == &"", "prologue entry request is consumed once its runtime starts")
	game.end_session()
	print("%s: %d Story Mode runtime assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
