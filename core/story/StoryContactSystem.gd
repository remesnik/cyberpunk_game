class_name StoryContactSystem
extends RefCounted

signal contacts_changed
signal assistance_requested(contact_id: StringName, assistance_id: StringName, context: Dictionary)

var story_state: StoryState
var missions: StoryMissionSystem
var comms: RealtimeCommsService
var definitions: Dictionary = {}

func configure(state: PersistentGameState, mission_system: StoryMissionSystem, comms_service: RealtimeCommsService) -> void:
	story_state = StoryState.new(state); missions = mission_system; comms = comms_service

func load_file(path: String) -> Array[String]:
	if not FileAccess.file_exists(path): return ["Contact catalog not found: %s" % path]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)); if not parsed is Dictionary: return ["Contact catalog must be an object."]
	var errors: Array[String] = []
	for value: Variant in parsed.get("contacts", []):
		var definition := ContactDefinition.from_dict(value); errors.append_array(definition.validate()); if definition.validate().is_empty(): definitions[definition.contact_id] = definition
	errors.append_array(comms.load_definitions(parsed.get("calls", [])))
	return errors

func unlocked_contacts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in definitions.values():
		var definition := value as ContactDefinition
		if story_state.is_contact_unlocked(definition.contact_id): result.append(contact_view(definition.contact_id))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.display_name) < String(b.display_name)); return result

func contact_view(contact_id: StringName) -> Dictionary:
	if not definitions.has(contact_id) or not story_state.is_contact_unlocked(contact_id): return {}
	var definition: ContactDefinition = definitions[contact_id]; var state := story_state.get_contact_state(contact_id)
	return {"contact_id": contact_id, "display_name": definition.display_name, "portrait": definition.portrait_path, "reputation": story_state.get_reputation(contact_id), "interactions": valid_interactions(contact_id), "missions_offered": definition.missions_offered.duplicate(), "available_messages": state.get("available_messages", []), "last_interaction": state.get("last_interaction", {}), "story_tags": definition.story_tags.duplicate()}

func valid_interactions(contact_id: StringName) -> Array[Dictionary]:
	if not definitions.has(contact_id) or not story_state.is_contact_unlocked(contact_id): return []
	var result: Array[Dictionary] = []; var definition: ContactDefinition = definitions[contact_id]
	for interaction: Dictionary in definition.available_interactions:
		if story_state.get_reputation(contact_id) < float(interaction.get("minimum_reputation", -10)): continue
		var required: Array = interaction.get("required_flags", []); if not required.all(func(flag: Variant) -> bool: return story_state.get_flag(StringName(flag))): continue
		if interaction.get("type") == "ASK_ABOUT_MISSION" and missions != null and missions.status(StringName(interaction.get("mission_id", &""))) == StoryMissionSystem.LOCKED: continue
		result.append(interaction.duplicate(true))
	return result

func select_contact(contact_id: StringName) -> Dictionary:
	if not definitions.has(contact_id): return {"success": false, "reason": "Unknown contact."}
	if not story_state.is_contact_unlocked(contact_id): return {"success": false, "reason": "Contact is locked."}
	return {"success": true, "contact": contact_view(contact_id)}

func perform_interaction(contact_id: StringName, interaction_id: StringName) -> Dictionary:
	var matches := valid_interactions(contact_id).filter(func(item: Dictionary) -> bool: return StringName(item.get("interaction_id", &"")) == interaction_id)
	if matches.is_empty(): return {"success": false, "reason": "Contact interaction is unavailable."}
	var interaction: Dictionary = matches[0]; story_state.update_contact_state(contact_id, {"last_interaction": {"interaction_id": interaction_id, "at": Time.get_unix_time_from_system()}})
	match StringName(interaction.get("type", &"")):
		&"CALL": return comms.start_comms(StringName(interaction.get("call_id", &"")))
		&"ALLY_ASSISTANCE": assistance_requested.emit(contact_id, StringName(interaction.get("assistance_id", &"")), {}); return {"success": true}
	return {"success": true, "interaction": interaction}

func start_comms_action(action: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var call_id := StringName(action.get("id", action.get("call_id", &""))); var result := comms.start_comms(call_id)
	if result.success:
		var contact_id := StringName(action.get("contact_id", &"")); if not contact_id.is_empty(): story_state.update_contact_state(contact_id, {"last_interaction": {"interaction_id": call_id, "at": Time.get_unix_time_from_system()}, "available_calls": []})
	return result
