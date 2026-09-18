class_name FreeRoamNewGameInitializer
extends RefCounted

const HOME_LOCATION_ID := &"SAFEHOUSE_DECK_BAY"
const STARTING_NETWORK_ID := &"CITY_NET_ALPHA"

static func initialize(state: PersistentGameState, run_introduction := false) -> void:
	state.set_game_mode(GameMode.Value.FREE_ROAM)
	# Campaign state intentionally remains empty. Free Roam never infers or
	# advances authored campaign gates from the absence of dialogue.
	state.campaign_state = {}
	state.player_state = {
		"deck_id": &"FIELD_DECK_MK1",
		"active_slot_count": 2,
		"hardware": {&"DECK_CPU": 1, &"DECK_RAM": 2, &"DECK_STORAGE": 2, &"DECK_SENSORS": 1},
		"owned_programs": [
			{"instance_id": &"FREEROAM_SERVICE_PROBE_001", "definition_id": &"SERVICE_PROBE"},
			{"instance_id": &"FREEROAM_ROUTE_SNIFFER_001", "definition_id": &"ROUTE_SNIFFER_0_8"},
			{"instance_id": &"FREEROAM_DOORSTOP_001", "definition_id": &"DOORSTOP_STANDARD"},
			{"instance_id": &"FREEROAM_DOORSTOP_002", "definition_id": &"DOORSTOP_STANDARD"},
		],
		"installed_program_instance_ids": [&"FREEROAM_SERVICE_PROBE_001", &"FREEROAM_ROUTE_SNIFFER_001"],
		"inventory": [{"item_id": &"BASIC_NETWORK_ADAPTER", "quantity": 1}],
		"credits": 750,
		"resources": {&"MEMORY_SHARD": 6, &"ROUTING_KERNEL": 3, &"GHOST_SIGNATURE": 1},
		"reputation": {&"INDEPENDENT_OPERATORS": 0, &"CORPORATE_CONTACTS": 0},
	}
	state.world_state = {
		"current_meatspace_location_id": HOME_LOCATION_ID,
		"starting_network_id": STARTING_NETWORK_ID,
		"known_network_ids": [STARTING_NETWORK_ID],
		"discoverable_network_targets": [
			{"network_id": STARTING_NETWORK_ID, "display_name": "City Net Alpha", "access_state": &"AVAILABLE", "entry_node_id": &"HOME_UPLINK"},
			{"network_id": &"DOCKWORKS_NET", "display_name": "Dockworks Logistics", "access_state": &"LEAD", "discovery_source": &"PUBLIC_JOB_EXCHANGE"},
			{"network_id": &"CIVIC_ARCHIVE_NET", "display_name": "Civic Archive Mirror", "access_state": &"LEAD", "discovery_source": &"PUBLIC_JOB_EXCHANGE"},
		],
		"job_source_ids": [&"PUBLIC_JOB_EXCHANGE"],
		"available_dynamic_job_ids": [&"JOB_DATA_EXTRACTION_01", &"JOB_FEED_TAP_01", &"JOB_SYSTEM_CONTROL_01", &"JOB_DATABASE_QUERY_01", &"JOB_NETWORK_RECON_01"],
		"active_job_ids": [],
		"completed_dynamic_job_ids": [],
		"world_flags": {&"FREE_ROAM_INITIALIZED": true, &"DYNAMIC_JOBS_ENABLED": true},
		"entry_state": &"OPTIONAL_TUTORIAL" if run_introduction else &"HOME_DECK_MANAGEMENT",
		"pending_entry_content_id": &"FIRST_CONTACT_FREE_ROAM_TUTORIAL" if run_introduction else &"FREE_ROAM_HOME",
		"return_content_id": &"FREE_ROAM_HOME",
		"tutorial_state": {
			&"introduction_offered": true,
			&"introduction_accepted": run_introduction,
			&"campaign_progression_enabled": false,
		},
	}
	state.save_metadata = {"save_id": &"FREE_ROAM_AUTO", "network_name": "PUBLIC MESH", "location_name": "SAFEHOUSE // DECK", "playtime_seconds": 0.0}
	state.emit_changed()
