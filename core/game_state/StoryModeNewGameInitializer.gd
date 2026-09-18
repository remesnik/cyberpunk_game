class_name StoryModeNewGameInitializer
extends RefCounted

const FirstMeatspaceTutorial = preload("res://core/story/FirstMeatspaceTutorial.gd")

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
			&"FIRST_CONTACT_STARTED": false,
			&"CLAN_SELECTED": false,
			&"DECK_SELECTED": false,
			&"BOX_OPEN": false,
			&"FIRST_CONTACT_COMPLETE": false,
			&"latch_contacted": false,
		},
		"story_values": {&"corp_alert_level": 0, &"latch_reputation": 0},
		"story_states": {&"current_story_chapter": &"intro"},
		"contacts": {},
		"mission_states": {},
		"story_event_state": {},
		"objectives": {},
		"room_object_states": {},
		"campaign_unlocks": [],
		"optional_content": [],
		"prologue": {"phase": &"DECK_SELECTION", "completed": false},
	}
	state.world_state = {"entry_state": &"MEATSPACE_PROLOGUE", "meatspace_location_id": &"HOME", "current_meatspace_location_id": &"HOME", "current_meatspace_location": &"HOME", "time_of_day": "DUSK", "tutorial_state": {FirstMeatspaceTutorial.STATE_KEY: FirstMeatspaceTutorial.Step.LOOK_AROUND}}
	state.save_metadata = {"save_id": &"STORY_AUTO", "network_name": "OFFLINE", "location_name": "BEDROOM", "playtime_seconds": 0.0}
	state.player_state = {
		"fatigue": 35.0,
		"player_class": "",
		"selected_deck_variant": "",
		"active_slot_count": 2,
		"deck_id": &"STARTER_DECK",
		"hardware": {
			&"DECK_CPU": 1,
			&"DECK_RAM": 1,
			&"DECK_STORAGE": 1,
			&"DECK_SENSORS": 1,
		},
		"owned_programs": [
			{"instance_id": &"STARTER_SERVICE_PROBE_001", "definition_id": &"SERVICE_PROBE"},
			{"instance_id": &"STARTER_ROUTE_SNIFFER_001", "definition_id": &"ROUTE_SNIFFER_0_8"},
		],
		"installed_program_instance_ids": [&"STARTER_SERVICE_PROBE_001"],
		"inventory": [],
		"credits": 25,
		"resources": {
			&"MEMORY_SHARD": 4,
			&"ROUTING_KERNEL": 2,
		},
	}
	state.emit_changed()
