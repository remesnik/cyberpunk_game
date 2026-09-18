class_name FirstMeatspaceTutorial
extends RefCounted

enum Step { LOOK_AROUND, INSPECT_OBJECT, OPEN_BOX, CHOOSE_DECK, USE_TOOLBOX, USE_COMPUTER, ENTER_CLEAN_ROOM, COMPLETE }

const STATE_KEY := "first_meatspace_step"

static func get_step(state: PersistentGameState) -> Step:
	if state == null: return Step.COMPLETE
	var tutorial: Dictionary = state.world_state.get("tutorial_state", {})
	return clampi(int(tutorial.get(STATE_KEY, Step.LOOK_AROUND)), Step.LOOK_AROUND, Step.COMPLETE) as Step

static func advance_to(state: PersistentGameState, requested: Step) -> Step:
	if state == null: return Step.COMPLETE
	var tutorial: Dictionary = state.world_state.get("tutorial_state", {}).duplicate(true)
	var current := get_step(state)
	if requested > current:
		tutorial[STATE_KEY] = requested
		state.world_state["tutorial_state"] = tutorial
		state.emit_changed()
		return requested
	return current

static func reconcile(state: PersistentGameState) -> Step:
	if state == null: return Step.COMPLETE
	var step := get_step(state)
	var flags: Dictionary = state.campaign_state.get("story_flags", {})
	var entry := StringName(state.world_state.get("entry_state", &""))
	if entry == &"ACTIVE_NETWORK": step = Step.COMPLETE
	elif entry == &"CLEAN_ROOM" or bool(flags.get("CLEAN_ROOM_VISITED", false)): step = maxi(step, Step.ENTER_CLEAN_ROOM) as Step
	elif bool(flags.get("DECK_ASSEMBLED", false)): step = maxi(step, Step.USE_COMPUTER) as Step
	elif bool(flags.get("DECK_SELECTED", false)): step = maxi(step, Step.USE_TOOLBOX) as Step
	elif bool(flags.get("BOX_OPEN", false)): step = maxi(step, Step.CHOOSE_DECK) as Step
	return advance_to(state, step)

static func label(step: Step) -> String:
	return Step.keys()[step]
