class_name StoryModeNewGameInitializer
extends RefCounted

const CAMPAIGN_ID := &"MAIN_CAMPAIGN"
const ENTRY_CONTENT_ID := &"STORY_PROLOGUE"

static func initialize(state: PersistentGameState) -> void:
	state.set_game_mode(GameMode.Value.STORY)
	state.campaign_state = {
		"campaign_id": CAMPAIGN_ID,
		"current_content_id": ENTRY_CONTENT_ID,
		"pending_entry_content_id": ENTRY_CONTENT_ID,
		"active_mission_id": &"",
		"unlocked_mission_ids": [],
		"completed_mission_ids": [],
		"story_flags": {
			&"CAMPAIGN_STARTED": true,
			&"PROLOGUE_STARTED": true,
			&"PROLOGUE_COMPLETE": false,
			&"FIRST_CONTACT_AVAILABLE": false,
			&"FIRST_CONTACT_COMPLETE": false,
		},
		"campaign_unlocks": [],
		"optional_content": [],
		"prologue": {"phase": &"CLAN_SELECTION", "completed": false},
	}
	state.world_state = {"entry_state": &"MEATSPACE_PROLOGUE", "meatspace_location_id": &"BEDROOM", "time_of_day": "NIGHT"}
	state.save_metadata = {"save_id": &"STORY_AUTO", "network_name": "OFFLINE", "location_name": "BEDROOM", "playtime_seconds": 0.0}
	state.player_state = {
		"fatigue": 35.0,
		"deck_id": &"STARTER_DECK",
		"hardware": {
			&"DECK_CPU": 1,
			&"DECK_RAM": 1,
			&"DECK_STORAGE": 1,
		},
		"owned_programs": [
			{"instance_id": &"STARTER_SERVICE_PROBE_001", "definition_id": &"SERVICE_PROBE"},
			{"instance_id": &"STARTER_ROUTE_SNIFFER_001", "definition_id": &"ROUTE_SNIFFER_0_8"},
		],
		"installed_program_instance_ids": [&"STARTER_SERVICE_PROBE_001"],
		"inventory": [],
		"credits": 500,
		"resources": {
			&"MEMORY_SHARD": 4,
			&"ROUTING_KERNEL": 2,
		},
	}
	state.emit_changed()
