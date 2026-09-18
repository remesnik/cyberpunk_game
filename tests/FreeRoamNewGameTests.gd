extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var state := PersistentGameState.new()
	FreeRoamNewGameInitializer.initialize(state)
	_expect(state.is_free_roam_mode(), "initializer selects Free Roam explicitly")
	_expect(state.campaign_state.is_empty(), "mandatory campaign progression is absent")
	_expect(state.world_state.entry_state == &"HOME_DECK_MANAGEMENT", "Free Roam starts in home deck management")
	_expect(state.world_state.world_flags.DYNAMIC_JOBS_ENABLED, "dynamic jobs are enabled explicitly")
	_expect(state.world_state.available_dynamic_job_ids.size() == 5 and state.world_state.job_source_ids == [&"PUBLIC_JOB_EXCHANGE"], "starter world provides the static test job pool and a job source")
	_expect(state.world_state.discoverable_network_targets.size() >= 3, "starter directory provides several discoverable network targets")
	_expect(state.player_state.deck_id == &"FIELD_DECK_MK1" and state.player_state.hardware.DECK_RAM == 2, "valid Free Roam deck and hardware are initialized")
	_expect(state.player_state.owned_programs.size() == 4 and state.player_state.installed_program_instance_ids.size() == 2, "owned software, two Doorstop copies, and installed loadout remain distinct")
	_expect(state.player_state.credits == 750 and state.player_state.reputation.has(&"INDEPENDENT_OPERATORS"), "economy and reputation are initialized")
	var restored := PersistentGameState.from_save_data(state.to_save_data())
	_expect(restored.is_free_roam_mode() and restored.world_state.starting_network_id == &"CITY_NET_ALPHA", "Free Roam state survives save/load")
	var tutorial_state := PersistentGameState.new(); FreeRoamNewGameInitializer.initialize(tutorial_state, true)
	_expect(tutorial_state.world_state.pending_entry_content_id == &"FIRST_CONTACT_FREE_ROAM_TUTORIAL" and tutorial_state.world_state.tutorial_state.introduction_accepted, "optional introduction selects the reusable tutorial wrapper")
	_expect(tutorial_state.campaign_state.is_empty() and not tutorial_state.world_state.tutorial_state.campaign_progression_enabled, "optional tutorial does not enable campaign progression")
	print("%s: %d Free Roam initialization assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
