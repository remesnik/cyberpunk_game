extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var state := PersistentGameState.new()
	StoryModeNewGameInitializer.initialize(state)
	Game.persistent_game_state = state
	_expect(Game.active_slot_capacity() == 2, "base starter deck has exactly two active slots")
	state.player_state["selected_deck_variant"] = "MORE_STORAGE"
	state.player_state["active_slot_count"] = 2
	_expect(Game.active_slot_capacity() == 2, "More Storage keeps exactly two active slots")
	state.player_state["selected_deck_variant"] = "MORE_SLOTS"
	state.player_state["active_slot_count"] = 3
	_expect(Game.active_slot_capacity() == 3, "More Slots has exactly three active slots")
	var loadout := ProgramLoadout.new(Game.active_slot_capacity())
	_expect(loadout.capacity == 3 and loadout.active_slots.size() == 3, "HUD-facing loadout capacity follows authoritative deck state")
	Game.persistent_game_state = null
	print("%s: %d starter deck slot assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
