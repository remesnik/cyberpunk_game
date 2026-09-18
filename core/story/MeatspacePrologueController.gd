class_name MeatspacePrologueController
extends RefCounted

signal state_changed(view: Dictionary)
signal interaction_resolved(event: Dictionary)
signal prologue_completed(next_content_id: StringName)

var definition: MeatspacePrologueDefinition
var game_state: PersistentGameState
var phase: StringName
var selected_interaction_id: StringName
var classes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/meatspace/classes.json"))
var event_history: Array[Dictionary] = []

func configure(source: MeatspacePrologueDefinition, state: PersistentGameState) -> void:
	definition = source
	game_state = state
	var prologue: Dictionary = game_state.campaign_state.get("prologue", {})
	phase = StringName(prologue.get("phase", definition.initial_phase))
	phase = StringName(definition.phase_migrations.get(String(phase), phase))
	var stored_class := String(game_state.player_state.get("player_class", game_state.player_state.get("clan_id", "")))
	if classes.has(stored_class): _apply_action({"type": "SET_CLASS", "id": stored_class})
	else: game_state.campaign_state.get_or_add("story_flags", {})["CLAN_SELECTED"] = false
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
	for action: Dictionary in choice.get("actions", []):
		if String(action.get("type", "")) == "COMPLETE_PROLOGUE":
			var gate := connection_status()
			if not gate.success: return gate
	if not choice_available(choice): return _failure("This option is unavailable or you do not have enough ICs.")
	game_state.player_state["credits"] = int(game_state.player_state.get("credits", 0)) - choice_cost(choice)
	for action: Dictionary in choice.get("actions", []):
		if String(action.get("type", "")) != "SPEND_CREDITS": _apply_action(action)
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
		&"SET_CLASS":
			var id := String(action.get("id", ""))
			if not classes.has(id): return
			game_state.player_state["player_class"] = id
			game_state.player_state["clan_id"] = id
			game_state.player_state["class_profile"] = classes[id].duplicate(true)
			var flags := _flags()
			flags["CLAN_SELECTED"] = true
			flags["CLASS_" + id] = true
			game_state.campaign_state["story_flags"] = flags
		&"SET_PHASE": phase = StringName(action.get("value", phase))
		&"SET_FLAG":
			var flags := _flags(); flags[StringName(action.get("id", &""))] = action.get("value", true); game_state.campaign_state["story_flags"] = flags
		&"SET_PLAYER_FIELD": game_state.player_state[StringName(action.get("id", &""))] = action.get("value")
		&"SET_HARDWARE":
			var previous: Dictionary = game_state.player_state.get("hardware", {})
			var replacement := (action.get("value", {}) as Dictionary).duplicate(true)
			replacement[&"DECK_SENSORS"] = int(previous.get(&"DECK_SENSORS", previous.get(&"DECK_DETECTION", 1)))
			game_state.player_state["hardware"] = replacement
		&"MODIFY_HARDWARE":
			var hardware: Dictionary = game_state.player_state.get("hardware", {}).duplicate(true)
			var id := StringName(action.get("id", &""))
			if id == &"DECK_DETECTION": id = &"DECK_SENSORS"
			hardware[id] = int(hardware.get(id, 0)) + int(action.get("amount", 0)); game_state.player_state["hardware"] = hardware
		&"SET_LOADOUT": game_state.player_state["installed_program_instance_ids"] = (action.get("value", []) as Array).duplicate()
		&"SPEND_CREDITS": game_state.player_state["credits"] = maxi(0, int(game_state.player_state.get("credits", 0)) - int(action.get("amount", 0)))
		&"COMPLETE_PROLOGUE":
			phase = &"COMPLETE"
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

func choice_cost(choice: Dictionary) -> int:
	if choice.has("cost_ics"):
		if choice.cost_ics == null: return -1
		return maxi(0, int(choice.cost_ics))
	var cost := 0
	for action: Dictionary in choice.get("actions", []):
		if String(action.get("type", "")) == "SPEND_CREDITS": cost += maxi(0, int(action.get("amount", 0)))
	return cost

func can_afford(choice: Dictionary) -> bool:
	return game_state != null and choice_cost(choice) >= 0 and int(game_state.player_state.get("credits", 0)) >= choice_cost(choice)

func choice_available(choice: Dictionary) -> bool:
	if not can_afford(choice): return false
	for flag: String in choice.get("required_flags", []):
		if not bool(_flags().get(flag, false)): return false
	for flag: String in choice.get("absent_flags", []):
		if bool(_flags().get(flag, false)): return false
	return true

func connection_status() -> Dictionary:
	if not bool(_flags().get("DECK_SELECTED", false)): return _failure("You don't have anything to connect with.")
	if not classes.has(String(game_state.player_state.get("player_class", ""))) or not bool(_flags().get("CLAN_SELECTED", false)):
		return _failure("You hesitate. You still haven't decided who you're going to be out there.")
	if bool(_flags().get("FIRST_CONTACT_STARTED", false)): return _failure("First Contact has already started.")
	return {"success": true, "reason": "Connecting to First Contact..."}

func connect_first_contact() -> Dictionary:
	var status := connection_status()
	if not status.success: return status
	for id in ["PROLOGUE_JACKED_IN", "BBS_CONNECTED", "LATCH_CONTACTED", "FIRST_CONTACT_STARTED"]:
		_apply_action({"type": "SET_FLAG", "id": id})
	_apply_action({"type": "COMPLETE_PROLOGUE"})
	_sync()
	prologue_completed.emit(&"FIRST_CONTACT")
	return status

func progression_view() -> Dictionary:
	return {
		"box_opened": bool(_flags().get("BOX_OPEN", false)),
		"deck_selected": bool(_flags().get("DECK_SELECTED", false)),
		"selected_deck_variant": game_state.player_state.get("selected_deck_variant", ""),
		"class_selected": bool(_flags().get("CLAN_SELECTED", false)),
		"player_class": game_state.player_state.get("player_class", ""),
		"computer_unlocked": bool(_flags().get("DECK_SELECTED", false)),
		"first_contact_started": bool(_flags().get("FIRST_CONTACT_STARTED", false)),
		"first_contact_completed": bool(_flags().get("FIRST_CONTACT_COMPLETE", false)),
	}

func choice_status(choice: Dictionary) -> String:
	if choice_cost(choice) < 0: return String(choice.get("unavailable_reason", "Cost not yet specified"))
	for flag: String in choice.get("absent_flags", []):
		if bool(_flags().get(flag, false)): return "Already applied / selection locked"
	for flag: String in choice.get("required_flags", []):
		if not bool(_flags().get(flag, false)): return "Requires starter deck"
	if not can_afford(choice): return "Not enough ICs"
	return "Available"
