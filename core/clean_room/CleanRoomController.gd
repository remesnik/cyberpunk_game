class_name CleanRoomController
extends RefCounted
const FirstMeatspaceTutorial = preload("res://core/story/FirstMeatspaceTutorial.gd")

signal state_changed(view: Dictionary)
signal ally_contacted(event: Dictionary)

const LINK_COSTS := {2: 20, 3: 45, 4: 80}
var game_state: PersistentGameState
var management: MeatspaceManagement
var connection_value := 1
var inbox: SocialMessageInbox
var story_events: StoryEventSystem
var story_missions: StoryMissionSystem
var contacts: StoryContactSystem

func configure(state: PersistentGameState, manager: MeatspaceManagement, messages: SocialMessageInbox = null, events: StoryEventSystem = null, missions: StoryMissionSystem = null, contact_system: StoryContactSystem = null) -> void:
	game_state = state
	management = manager
	inbox = messages
	story_events = events
	story_missions = missions
	contacts = contact_system
	if inbox != null and not inbox.inbox_changed.is_connected(_on_inbox_changed): inbox.inbox_changed.connect(_on_inbox_changed)
	connection_value = clampi(int(game_state.player_state.get("connection_value", 1)), 1, 4)
	game_state.player_state["connection_value"] = connection_value

func enter() -> Dictionary:
	var first_visit := not bool(_flags().get(&"CLEAN_ROOM_VISITED", false))
	_flags()[&"CLEAN_ROOM_VISITED"] = true
	FirstMeatspaceTutorial.advance_to(game_state, FirstMeatspaceTutorial.Step.ENTER_CLEAN_ROOM)
	var latch_event: Dictionary = {}
	if inbox != null: inbox.evaluate(&"CLEAN_ROOM_ENTER", {"progress": int(game_state.save_metadata.get("completed_runs", 0))})
	if story_events != null:
		var fired := story_events.publish(&"clean_room_entered", {"first_visit": first_visit})
		if not fired.is_empty(): latch_event = fired[0]
	if StoryState.new(game_state).get_flag(&"latch_contacted"): _flags()[&"CLEAN_ROOM_LATCH_CONTACTED"] = true
	game_state.emit_changed()
	state_changed.emit(view())
	return {"success": true, "first_visit": first_visit, "latch_event": latch_event}

func view() -> Dictionary:
	var deck := management.inspect_deck() if management != null else {}
	var mission_view := _mission_presentation()
	return {"connection_value": connection_value, "trace_resolution_multiplier": trace_resolution_multiplier(), "transfer_duration_multiplier": transfer_duration_multiplier(), "next_link_cost": next_link_cost(), "credits": management.equipment_orders.credits if management != null and management.equipment_orders != null else 0, "owned_programs": deck.get("owned_programs", []), "installed_instance_ids": deck.get("installed_instance_ids", []), "active_slot_capacity": deck.get("capacity", 0), "latch_contacted": bool(_flags().get(&"CLEAN_ROOM_LATCH_CONTACTED", false)), "ally_status": "AVAILABLE" if bool(_flags().get(&"CLEAN_ROOM_LATCH_CONTACTED", false)) else "OFFLINE", "unread_count": inbox.unread_count() if inbox != null else 0, "critical_unread": inbox.has_critical_unread() if inbox != null else false, "mission_briefing": mission_view.briefing, "mission_debrief": mission_view.debrief, "allies": contacts.unlocked_contacts() if contacts != null else []}

func read_next_message() -> Dictionary:
	if inbox == null: return _failure("Inbox unavailable.")
	var message := inbox.mark_next_read(SocialMessageInbox.Priority.CRITICAL)
	state_changed.emit(view())
	return {"success": not message.is_empty(), "message": message, "reason": "No unread messages." if message.is_empty() else "Message read."}

func trace_resolution_multiplier() -> float: return 1.0 + float(connection_value - 1) * 0.35
func transfer_duration_multiplier() -> float: return 1.0 + float(connection_value - 1) * 0.35
func adjusted_transfer_cost(base_cost: int) -> int: return maxi(1, int(ceil(float(base_cost) * transfer_duration_multiplier())))
func next_link_cost() -> int: return int(LINK_COSTS.get(connection_value + 1, -1))
func can_buy_link() -> bool:
	var cost := next_link_cost()
	return cost >= 0 and management != null and management.equipment_orders != null and management.equipment_orders.credits >= cost

func buy_link() -> Dictionary:
	if connection_value >= 4: return _failure("Connection is already at maximum value.")
	if not can_buy_link(): return _failure("Insufficient ICs for the next link.")
	var cost := next_link_cost()
	management.equipment_orders.credits -= cost
	connection_value += 1
	game_state.player_state["connection_value"] = connection_value
	game_state.player_state["credits"] = management.equipment_orders.credits
	game_state.emit_changed(); state_changed.emit(view())
	return {"success": true, "reason": "Connection link purchased.", "cost": cost, "connection_value": connection_value}

func install_program(instance_id: StringName) -> Dictionary:
	var result := management.install_program(instance_id) if management != null else _failure("Deck management is unavailable.")
	if result.success: _persist_loadout()
	state_changed.emit(view()); return result

func remove_program(instance_id: StringName) -> Dictionary:
	var result := management.remove_program(instance_id) if management != null else _failure("Deck management is unavailable.")
	if result.success: _persist_loadout()
	state_changed.emit(view()); return result

func contact_ally(ally_id: StringName) -> Dictionary:
	if ally_id == &"": return _failure("No ally selected.")
	if contacts != null:
		var selected := contacts.select_contact(StringName(String(ally_id).to_lower()))
		if selected.success and management != null: management.perform_story_interaction(&"CLEAN_ROOM_ALLY_CONTACT", ally_id)
		return selected
	return _contact_ally(ally_id, false)

func contact_interaction(contact_id: StringName, interaction_id: StringName) -> Dictionary:
	return contacts.perform_interaction(contact_id, interaction_id) if contacts != null else _failure("Contacts unavailable.")

func _contact_ally(ally_id: StringName, incoming: bool) -> Dictionary:
	var event := {"success": true, "ally_id": ally_id, "incoming": incoming, "text": "Latch: Clean signal. Configure the deck, then use GO when you're ready." if ally_id == &"LATCH" else "%s channel opened." % ally_id}
	if management != null: management.perform_story_interaction(&"CLEAN_ROOM_ALLY_CONTACT", ally_id)
	ally_contacted.emit(event); return event

func _handle_start_comms(action: Dictionary, _context: Dictionary) -> Dictionary:
	var contact_id := StringName(action.get("contact_id", action.get("id", &"")))
	if contact_id.is_empty(): return _failure("Story comms action has no contact reference.")
	var result := _contact_ally(contact_id.to_upper(), bool(action.get("incoming", true)))
	if result.success and bool(action.get("incoming", true)) and contact_id.to_lower() == &"latch": _flags()[&"CLEAN_ROOM_LATCH_CONTACTED"] = true
	return result

func _mission_presentation() -> Dictionary:
	if story_missions == null: return {"briefing": {}, "debrief": {}}
	if not story_missions.active_mission_id.is_empty(): return {"briefing": story_missions.briefing(story_missions.active_mission_id), "debrief": {}}
	for mission_id: Variant in story_missions.definitions:
		if story_missions.status(StringName(mission_id)) == StoryMissionSystem.AVAILABLE: return {"briefing": story_missions.briefing(StringName(mission_id)), "debrief": story_missions.debrief(StringName(mission_id))}
		var debrief := story_missions.debrief(StringName(mission_id))
		if not debrief.is_empty(): return {"briefing": {}, "debrief": debrief}
	return {"briefing": {}, "debrief": {}}

func _persist_loadout() -> void:
	game_state.player_state["installed_program_instance_ids"] = management.program_loadout.installed_instance_ids.duplicate()
	game_state.emit_changed()
func _on_inbox_changed(_inbox_view: Dictionary) -> void: state_changed.emit(view())
func _flags() -> Dictionary: return game_state.campaign_state.get_or_add("story_flags", {})
func _failure(reason: String) -> Dictionary: return {"success": false, "reason": reason}
