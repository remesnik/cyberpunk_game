class_name MeatspacePrologueController
extends RefCounted

signal state_changed(view: Dictionary)
signal interaction_resolved(event: Dictionary)
signal prologue_completed(next_content_id: StringName)

var definition: MeatspacePrologueDefinition
var game_state: PersistentGameState
var phase: StringName
var selected_interaction_id: StringName
var event_history: Array[Dictionary] = []

func configure(source: MeatspacePrologueDefinition, state: PersistentGameState) -> void:
	definition = source
	game_state = state
	var prologue: Dictionary = game_state.campaign_state.get("prologue", {})
	phase = StringName(prologue.get("phase", definition.initial_phase))
	_sync()

func view() -> Dictionary:
	return {
		"id": definition.id,
		"display_name": definition.display_name,
		"opening_text": definition.opening_text,
		"phase": phase,
		"selected_interaction_id": selected_interaction_id,
		"interactions": definition.interactions_for_phase(phase, _flags()),
		"completed": bool(_prologue().get("completed", false)),
	}

func select_interaction(interaction_id: StringName) -> Dictionary:
	var interaction := _find_available(interaction_id)
	if interaction.is_empty(): return _failure("That bedroom interaction is not currently available.")
	selected_interaction_id = interaction_id
	state_changed.emit(view())
	return {"success": true, "interaction": interaction}

func choose(interaction_id: StringName, choice_id: StringName) -> Dictionary:
	var interaction := _find_available(interaction_id)
	if interaction.is_empty(): return _failure("That interaction is no longer available.")
	var choice: Dictionary = {}
	for candidate: Dictionary in interaction.get("choices", []):
		if StringName(candidate.get("id", &"")) == choice_id: choice = candidate; break
	if choice.is_empty(): return _failure("That authored choice does not exist.")
	for action: Dictionary in choice.get("actions", []): _apply_action(action)
	var event := {"interaction_id": interaction_id, "choice_id": choice_id, "phase": phase, "text": choice.get("result_text", "")}
	event_history.append(event)
	selected_interaction_id = &""
	_sync()
	interaction_resolved.emit(event)
	state_changed.emit(view())
	if bool(_prologue().get("completed", false)): prologue_completed.emit(&"FIRST_CONTACT")
	return {"success": true, "event": event, "view": view()}

func _apply_action(action: Dictionary) -> void:
	match StringName(action.get("type", &"")):
		&"SET_PHASE": phase = StringName(action.get("value", phase))
		&"SET_FLAG":
			var flags := _flags(); flags[StringName(action.get("id", &""))] = action.get("value", true); game_state.campaign_state["story_flags"] = flags
		&"SET_PLAYER_FIELD": game_state.player_state[StringName(action.get("id", &""))] = action.get("value")
		&"SET_HARDWARE": game_state.player_state["hardware"] = (action.get("value", {}) as Dictionary).duplicate(true)
		&"MODIFY_HARDWARE":
			var hardware: Dictionary = game_state.player_state.get("hardware", {}).duplicate(true)
			var id := StringName(action.get("id", &"")); hardware[id] = int(hardware.get(id, 0)) + int(action.get("amount", 0)); game_state.player_state["hardware"] = hardware
		&"SET_LOADOUT": game_state.player_state["installed_program_instance_ids"] = (action.get("value", []) as Array).duplicate()
		&"SPEND_CREDITS": game_state.player_state["credits"] = maxi(0, int(game_state.player_state.get("credits", 0)) - int(action.get("amount", 0)))
		&"COMPLETE_PROLOGUE":
			var prologue := _prologue(); prologue["completed"] = true; prologue["phase"] = &"COMPLETE"; game_state.campaign_state["prologue"] = prologue
			var flags := _flags(); flags[&"PROLOGUE_COMPLETE"] = true; flags[&"FIRST_CONTACT_AVAILABLE"] = true; game_state.campaign_state["story_flags"] = flags
			game_state.campaign_state["current_content_id"] = &"FIRST_CONTACT"
			game_state.campaign_state["pending_entry_content_id"] = &"FIRST_CONTACT"
			game_state.campaign_state["active_mission_id"] = &"FIRST_CONTACT"
			game_state.campaign_state["unlocked_mission_ids"] = [&"FIRST_CONTACT"]

func _find_available(interaction_id: StringName) -> Dictionary:
	for interaction: Dictionary in definition.interactions_for_phase(phase, _flags()):
		if StringName(interaction.get("id", &"")) == interaction_id: return interaction
	return {}

func _prologue() -> Dictionary:
	return game_state.campaign_state.get("prologue", {})

func _flags() -> Dictionary:
	return game_state.campaign_state.get("story_flags", {})

func _sync() -> void:
	var prologue := _prologue(); prologue["phase"] = phase; game_state.campaign_state["prologue"] = prologue
	game_state.emit_changed()

func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
