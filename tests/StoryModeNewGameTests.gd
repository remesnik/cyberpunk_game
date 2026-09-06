extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var state := PersistentGameState.new()
	StoryModeNewGameInitializer.initialize(state)
	_expect(state.is_story_mode(), "initializer selects Story mode explicitly")
	_expect(state.campaign_state.campaign_id == &"MAIN_CAMPAIGN", "normal campaign state is initialized")
	_expect(state.campaign_state.pending_entry_content_id == &"STORY_PROLOGUE", "the authored meat-space prologue is the campaign entry")
	_expect(not state.campaign_state.story_flags.FIRST_CONTACT_AVAILABLE and state.campaign_state.story_flags.PROLOGUE_STARTED, "FIRST_CONTACT remains gated until the prologue request")
	_expect(state.player_state.deck_id == &"STARTER_DECK", "starter deck is explicit")
	_expect(not state.player_state.hardware.is_empty(), "starter hardware is initialized")
	_expect(state.player_state.owned_programs.size() == 2 and state.player_state.installed_program_instance_ids.size() == 1, "starter software inventory and loadout are distinct")
	_expect(state.player_state.credits == 500 and state.player_state.resources.MEMORY_SHARD == 4, "starter money and programming resources are initialized")
	var restored := PersistentGameState.from_save_data(state.to_save_data())
	_expect(restored.campaign_state.current_content_id == &"STORY_PROLOGUE" and restored.player_state.deck_id == &"STARTER_DECK", "prologue and player initialization survive save/load")
	print("%s: %d Story Mode initialization assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
