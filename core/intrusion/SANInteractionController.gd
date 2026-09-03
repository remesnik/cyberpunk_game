class_name SANInteractionController
extends RefCounted

const DumpDefinitionScript := preload("res://core/intrusion/SANDumpDefinition.gd")

signal interaction_resolved(result: SANInteractionResult)
signal attacker_feedback(actor_id: StringName, lines: Array[String])
signal victim_feedback(actor_id: StringName, lines: Array[String])

var san_manager: SystemAccessNodeManager
var defense_controller: SANDefenseController
var _sessions: Dictionary = {}

func _init(p_san_manager: SystemAccessNodeManager = null, p_defense_controller: SANDefenseController = null) -> void:
	san_manager = p_san_manager
	defense_controller = p_defense_controller if p_defense_controller != null else SANDefenseController.new()

func execute(request: SANInteractionRequest) -> SANInteractionResult:
	var invalid := _validate_reach(request)
	if invalid != null:
		return _finish(invalid)
	var san := san_manager.get_san(request.san_id)
	var session := _session(request.actor_id, san.id)
	var defense := defense_controller.interact(san, request.actor_id, request.action_type, request.actor_kind)
	var result := SANInteractionResult.new()
	result.events.append_array(defense.events)
	match request.action_type:
		SANInteractionRequest.INSPECT:
			session.grant(SANAccessSession.AccessLevel.OBSERVED)
			result.success = true
			result.reason = "System Access Node observed. Deck contents remain sealed."
			result.visible_data = _public_view(san)
		SANInteractionRequest.BREACH:
			_resolve_breach(request, san, session, result, int(defense.access_resistance))
		SANInteractionRequest.ACCESS_FILES:
			_resolve_access(san, session, result, DeckStorageEntry.Kind.FILE)
		SANInteractionRequest.ACCESS_PROGRAMS:
			_resolve_access(san, session, result, DeckStorageEntry.Kind.PROGRAM)
		SANInteractionRequest.STEAL_FILE:
			_resolve_steal(request, san, session, result, DeckStorageEntry.Kind.FILE)
		SANInteractionRequest.STEAL_PROGRAM:
			_resolve_steal(request, san, session, result, DeckStorageEntry.Kind.PROGRAM)
		SANInteractionRequest.CORRUPT_PROGRAM:
			_resolve_corrupt(request, san, session, result)
		SANInteractionRequest.PLANT_PROGRAM:
			_resolve_plant(request, san, session, result)
		SANInteractionRequest.TRACE_OWNER:
			_resolve_trace(san, session, result)
		SANInteractionRequest.DUMP_OWNER:
			result.reason = "Dump must resolve through the cyberspace action system."
		_:
			result.reason = "Unsupported SAN action."
	result.access_level = session.access_level
	return _finish(result)

func get_session(actor_id: StringName, san_id: StringName) -> SANAccessSession:
	return _sessions.get(_key(actor_id, san_id)) as SANAccessSession

func revoke_access(actor_id: StringName, san_id: StringName) -> void:
	_sessions.erase(_key(actor_id, san_id))

func resolve_dump_action(
		action_clock: ActionClock,
		action_request: ActionRequest,
		request: SANInteractionRequest,
		victim: RefCounted,
		definition: Resource = null
) -> ActionResult:
	var config: Resource = definition if definition != null else DumpDefinitionScript.new()
	var resolution := {"result": null}
	if action_clock == null:
		return ActionResult.new(false, 0, "Cyberspace action clock is unavailable.")
	return action_clock.resolve_action(
		action_request,
		func(_action: ActionRequest) -> Dictionary:
			var checked := _validate_dump(action_request, request, victim, config)
			resolution.result = checked
			return {"success": checked.success, "reason": checked.reason, "events": checked.events},
		func(_action: ActionRequest) -> Dictionary:
			var checked: SANInteractionResult = resolution.result
			_apply_dump(request, victim, config, checked)
			return {"success": checked.success, "reason": checked.reason, "events": [checked.events.back()]}
	)

func _validate_reach(request: SANInteractionRequest) -> SANInteractionResult:
	if request == null or san_manager == null:
		return SANInteractionResult.denied("SAN interaction service is unavailable.")
	var san := san_manager.get_san(request.san_id)
	if san == null or not san.active:
		return SANInteractionResult.denied("System Access Node is unavailable.")
	if request.actor_id.is_empty() or request.actor_node_id != san.host_node_id:
		return SANInteractionResult.denied("Actor must occupy the SAN host node.")
	if request.intrusion_id != san.intrusion_id:
		return SANInteractionResult.denied("Actor and SAN are not in the same intrusion.")
	return null

func _resolve_breach(request: SANInteractionRequest, san: SystemAccessNode, session: SANAccessSession, result: SANInteractionResult, defense_resistance: int) -> void:
	if session.access_level < SANAccessSession.AccessLevel.OBSERVED:
		result.reason = "Inspect the SAN before attempting a breach."
		return
	if request.program_id.is_empty() and not request.capabilities.has(&"SAN_BREACH"):
		result.reason = "BREACH requires a compatible hacking program or SAN_BREACH capability."
		return
	var difficulty := san.access_security_level + defense_resistance
	var score := request.hacking_power + request.authority_level
	if score < difficulty:
		result.reason = "Breach blocked by SAN security (%d required)." % difficulty
		result.events.append({"type": &"SAN_BREACH_FAILED", "san_id": san.id, "actor_id": request.actor_id})
		return
	session.grant(SANAccessSession.AccessLevel.CONTROL if score >= difficulty + 3 else SANAccessSession.AccessLevel.BREACHED)
	san.mark_breached(request.actor_id)
	result.success = true
	result.reason = "SAN security compromised."
	result.events.append({"type": &"SAN_BREACHED", "san_id": san.id, "actor_id": request.actor_id})

func _resolve_access(san: SystemAccessNode, session: SANAccessSession, result: SANInteractionResult, kind: int) -> void:
	if session.access_level < SANAccessSession.AccessLevel.BREACHED:
		result.reason = "A successful SAN breach is required."
		return
	session.grant(SANAccessSession.AccessLevel.DECK_ACCESS)
	var summaries := san.deck_accessible_storage.list_summaries(kind, session.access_level)
	for summary in summaries:
		if not session.discovered_entry_ids.has(summary.id): session.discovered_entry_ids.append(summary.id)
	result.success = true
	result.reason = "Deck-local %s index accessed." % ("file" if kind == DeckStorageEntry.Kind.FILE else "program")
	result.visible_data = {"entries": summaries}

func _resolve_steal(request: SANInteractionRequest, san: SystemAccessNode, session: SANAccessSession, result: SANInteractionResult, kind: int) -> void:
	var entry := _authorized_entry(request, san, session, kind, result)
	if entry == null: return
	if not entry.stealable:
		result.reason = "Selected deck entry cannot be transferred."
		return
	if request.destination_storage == null:
		result.reason = "A deck-accessible destination is required."
		return
	if not request.destination_storage.add_entry(entry):
		result.reason = "Destination deck cannot accept the entry."
		return
	san.deck_accessible_storage.remove_entry(entry.id)
	result.success = true
	result.reason = "Deck-local entry transferred."
	result.transferred_entry = entry
	result.events.append({"type": &"SAN_ENTRY_STOLEN", "san_id": san.id, "entry_id": entry.id, "actor_id": request.actor_id})

func _resolve_corrupt(request: SANInteractionRequest, san: SystemAccessNode, session: SANAccessSession, result: SANInteractionResult) -> void:
	var entry := _authorized_entry(request, san, session, DeckStorageEntry.Kind.PROGRAM, result)
	if entry == null: return
	if not entry.corruptible:
		result.reason = "Selected program resists corruption."
		return
	entry.corrupted = true
	result.success = true
	result.reason = "Deck-local program corrupted."
	result.events.append({"type": &"SAN_PROGRAM_CORRUPTED", "san_id": san.id, "entry_id": entry.id, "actor_id": request.actor_id})

func _resolve_plant(request: SANInteractionRequest, san: SystemAccessNode, session: SANAccessSession, result: SANInteractionResult) -> void:
	if session.access_level < SANAccessSession.AccessLevel.DECK_ACCESS:
		result.reason = "Deck access is required to plant a program."
		return
	if request.planted_entry == null or request.planted_entry.kind != DeckStorageEntry.Kind.PROGRAM:
		result.reason = "An explicit deck-local program payload is required."
		return
	request.planted_entry.planted = true
	if not san.deck_accessible_storage.add_entry(request.planted_entry):
		result.reason = "Target deck rejected the program payload."
		return
	result.success = true
	result.reason = "Program planted in deck-accessible storage."
	result.events.append({"type": &"SAN_PROGRAM_PLANTED", "san_id": san.id, "entry_id": request.planted_entry.id, "actor_id": request.actor_id})

func _resolve_trace(san: SystemAccessNode, session: SANAccessSession, result: SANInteractionResult) -> void:
	if session.access_level < SANAccessSession.AccessLevel.BREACHED:
		result.reason = "A successful SAN breach is required to trace its owner."
		return
	result.success = true
	result.reason = "SAN owner connection identified."
	result.visible_data = {"owner_actor_id": san.owner_player_id, "deck_id": san.deck_id}

func _validate_dump(action_request: ActionRequest, request: SANInteractionRequest, victim: RefCounted, definition: Resource) -> SANInteractionResult:
	var invalid := _validate_reach(request)
	if invalid != null: return invalid
	var result := SANInteractionResult.new()
	var san := san_manager.get_san(request.san_id)
	# Defenses resolve before access, capability, or attack checks and may alert/counterattack.
	var defense := defense_controller.interact(san, request.actor_id, request.action_type, request.actor_kind)
	result.events.append_array(defense.events)
	if action_request.action_type != ActionRequest.ActionType.DUMP_SAN or action_request.cost != definition.action_cost:
		result.reason = "Dump action type or action cost is invalid."
		return result
	var session := get_session(request.actor_id, san.id)
	if session == null or session.access_level < SANAccessSession.AccessLevel.CONTROL:
		result.reason = "CONTROL access to the victim SAN is required."
		return result
	if not request.capabilities.has(definition.required_capability):
		result.reason = "%s capability is required to Dump a hacker." % definition.required_capability
		return result
	if request.program_id.is_empty():
		result.reason = "An active Dump-capable program is required."
		return result
	if victim == null or victim.intrusion == null or victim.deck_hardware == null:
		result.reason = "Victim intrusion or connected deck state is unavailable."
		return result
	if victim.owner_actor_id != san.owner_player_id or victim.intrusion.id != san.intrusion_id or victim.deck_hardware.deck_id != san.deck_id:
		result.reason = "Victim context does not match this SAN connection."
		return result
	var difficulty: int = definition.base_difficulty + int(defense.access_resistance)
	if request.hacking_power + request.authority_level < difficulty:
		result.reason = "Dump blocked by SAN defenses (%d power required)." % difficulty
		result.events.append({"type": &"SAN_DUMP_FAILED", "san_id": san.id, "attacker_id": request.actor_id, "victim_id": san.owner_player_id})
		return result
	result.success = true
	result.reason = "Dump attack validated."
	return result

func _apply_dump(request: SANInteractionRequest, victim: RefCounted, definition: Resource, result: SANInteractionResult) -> void:
	var san := san_manager.get_san(request.san_id)
	var mitigated := defense_controller.mitigate_deck_damage(san, definition.deck_surge_damage)
	result.damage_result = victim.deck_hardware.apply_physical_damage(int(mitigated.delivered_damage))
	result.damage_result["mitigated"] = int(mitigated.reduction)
	if not definition.temporary_fault_id.is_empty() and definition.temporary_fault_duration > 0.0:
		victim.deck_hardware.add_temporary_fault(definition.temporary_fault_id, definition.temporary_fault_duration, {"source_san_id": san.id})
	var candidates: Array[StringName] = []
	for entry: DeckStorageEntry in san.deck_accessible_storage.entries_of_kind(DeckStorageEntry.Kind.PROGRAM):
		candidates.append(entry.id)
	candidates.sort()
	for index in mini(definition.program_corruption_count, candidates.size()):
		var program_id := candidates[index]
		victim.deck_hardware.corrupt_program(program_id)
		var entry := san.deck_accessible_storage.get_entry(program_id)
		if entry != null: entry.corrupted = true
	var override_abort: bool = victim.abort_override.is_valid() and bool(victim.abort_override.call(victim, san, request))
	if not override_abort:
		victim.intrusion.abort("Forced disconnect through System Access Node.", {"attacker_id": request.actor_id, "san_id": san.id})
	san_manager.destroy_san(san.id)
	result.reason = "Victim forcibly disconnected."
	result.attacker_feedback.assign(["DUMP COMPLETE", "TARGET CONNECTION TERMINATED", "DECK SURGE DELIVERED: %d" % int(result.damage_result.applied)])
	result.victim_feedback.assign(["CONNECTION LOST", "FORCED DISCONNECT", "DECK LINK SURGE DETECTED", "HARDWARE DAMAGE: %d" % int(result.damage_result.applied)])
	result.events.append({"type": &"SAN_OWNER_DUMPED", "san_id": san.id, "attacker_id": request.actor_id, "victim_id": san.owner_player_id, "intrusion_aborted": not override_abort, "hardware_damage": int(result.damage_result.applied), "programs_corrupted": victim.deck_hardware.corrupted_program_ids.duplicate(), "faults": victim.deck_hardware.temporary_faults.duplicate(true)})
	attacker_feedback.emit(request.actor_id, result.attacker_feedback)
	victim_feedback.emit(san.owner_player_id, result.victim_feedback)
	_finish(result)

func _authorized_entry(request: SANInteractionRequest, san: SystemAccessNode, session: SANAccessSession, kind: int, result: SANInteractionResult) -> DeckStorageEntry:
	if session.access_level < SANAccessSession.AccessLevel.DECK_ACCESS:
		result.reason = "Deck access is required."
		return null
	var entry := san.deck_accessible_storage.get_entry(request.target_entry_id)
	if entry == null or entry.kind != kind or not session.discovered_entry_ids.has(entry.id):
		result.reason = "Selected entry is not visible through this SAN session."
		return null
	if request.hacking_power + request.authority_level < entry.security_level:
		result.reason = "Entry security rejected the action."
		return null
	return entry

func _public_view(san: SystemAccessNode) -> Dictionary:
	return {"san_id": san.id, "host_node_id": san.host_node_id, "deck_link_state": SystemAccessNode.DeckLinkState.keys()[san.deck_link_state], "integrity": san.integrity}

func _session(actor_id: StringName, san_id: StringName) -> SANAccessSession:
	var key := _key(actor_id, san_id)
	if not _sessions.has(key): _sessions[key] = SANAccessSession.new(actor_id, san_id)
	return _sessions[key]

func _key(actor_id: StringName, san_id: StringName) -> String:
	return "%s::%s" % [san_id, actor_id]

func _finish(result: SANInteractionResult) -> SANInteractionResult:
	interaction_resolved.emit(result)
	return result
