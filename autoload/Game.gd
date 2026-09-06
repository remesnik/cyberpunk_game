extends Node

const CyberspaceClockScript := preload("res://core/CyberspaceClock.gd")
const RealtimeWorldClockScript := preload("res://core/RealtimeWorldClock.gd")
const RealtimeProcessScript := preload("res://core/RealtimeProcess.gd")
const RealtimeProcessManagerScript := preload("res://core/RealtimeProcessManager.gd")
const RealtimeEndpointScript := preload("res://core/RealtimeEndpointDefinition.gd")
const CommsParticipantScript := preload("res://core/comms/CommsParticipantDefinition.gd")
const CommsChannelScript := preload("res://core/comms/CommsChannelDefinition.gd")
const CommsSessionScript := preload("res://core/comms/CommsSession.gd")
const CommsManagerScript := preload("res://core/comms/CommsInterceptionManager.gd")
const OutboundManagerScript := preload("res://core/comms/OutboundCommsManager.gd")
const OutboundTargetScript := preload("res://core/comms/OutboundCommsTargetDefinition.gd")
const OutboundActionScript := preload("res://core/comms/OutboundCommsAction.gd")
const ConditionScript := preload("res://core/story/ConditionDefinition.gd")
const StoryHookScript := preload("res://core/story/StoryHook.gd")
const VideoFeedDefinitionScript := preload("res://core/video/VideoFeedDefinition.gd")
const VideoFeedManagerScript := preload("res://core/video/VideoFeedManager.gd")
const PhysicalAlarmDefinitionScript := preload("res://core/alarms/PhysicalAlarmDefinition.gd")
const PhysicalAlarmManagerScript := preload("res://core/alarms/PhysicalAlarmManager.gd")
const LocationGraphScript := preload("res://core/teams/MeatspaceLocationGraph.gd")
const TeamDefinitionScript := preload("res://core/teams/PhysicalTeamDefinition.gd")
const TeamMemberScript := preload("res://core/teams/PhysicalTeamMemberDefinition.gd")
const TeamInstanceScript := preload("res://core/teams/PhysicalTeamInstance.gd")
const TeamKnowledgeScript := preload("res://core/teams/PhysicalTeamKnowledge.gd")
const TeamManagerScript := preload("res://core/teams/PhysicalTeamManager.gd")
const AccessPointDefinitionScript := preload("res://core/support/PhysicalAccessPointDefinition.gd")
const AccessPointInstanceScript := preload("res://core/support/PhysicalAccessPointInstance.gd")
const TeamSupportEncounterScript := preload("res://core/support/TeamSupportEncounter.gd")
const EquipmentDefinitionScript := preload("res://core/equipment/EquipmentDefinition.gd")
const VendorDefinitionScript := preload("res://core/equipment/VendorDefinition.gd")
const EquipmentOrderManagerScript := preload("res://core/equipment/EquipmentOrderManager.gd")
const RealtimeEventDefinitionScript := preload("res://core/realtime_events/RealtimeEventDefinition.gd")
const RealtimeEventSchedulerScript := preload("res://core/realtime_events/RealtimeEventScheduler.gd")
const OperationPressureManagerScript := preload("res://core/operations/OperationPressureManager.gd")
const OperationPressureDefinitionScript := preload("res://core/operations/OperationPressureDefinition.gd")
const EvidenceArchiveScript := preload("res://core/evidence/EvidenceArchive.gd")
const RealtimeStoryRouterScript := preload("res://core/story/RealtimeStoryRouter.gd")
const ProgramInventoryScript := preload("res://programs/ProgramInventory.gd")
const ProgramLoadoutScript := preload("res://programs/ProgramLoadout.gd")
const ProgramInstanceScript := preload("res://programs/ProgramInstance.gd")
const ProgramDefinitionScript := preload("res://programs/ProgramDefinition.gd")
const DoorstopDefinitionScript := preload("res://programs/doorstop/DoorstopDefinition.gd")
const DoorstopControllerScript := preload("res://programs/doorstop/DoorstopController.gd")
const IntrusionSessionScript := preload("res://core/intrusion/IntrusionSession.gd")
const MeatspaceManagementScript := preload("res://core/meatspace/MeatspaceManagement.gd")
const DoorstopSuspensionPolicyScript := preload("res://programs/doorstop/DoorstopSuspensionPolicy.gd")
const SuspendedIntrusionAdvancerScript := preload("res://programs/doorstop/SuspendedIntrusionAdvancer.gd")
const SystemAccessNodeControllerScript := preload("res://core/san/SystemAccessNodeController.gd")
const CurrentSphereTrackerScript := preload("res://cyberspace/spheres/CurrentSphereTracker.gd")
const HackerTrailSystemScript := preload("res://cyberspace/trails/HackerTrailSystem.gd")
const PersistentGameStateScript := preload("res://core/game_state/PersistentGameState.gd")
const StoryModeNewGameInitializerScript := preload("res://core/game_state/StoryModeNewGameInitializer.gd")
const AuthoredNetworkRuntimeBuilderScript := preload("res://core/game_state/AuthoredNetworkRuntimeBuilder.gd")
const FreeRoamNewGameInitializerScript := preload("res://core/game_state/FreeRoamNewGameInitializer.gd")
const FreeRoamWorldFactoryScript := preload("res://core/game_state/FreeRoamWorldFactory.gd")
const ContentAvailabilityScript := preload("res://core/content/ContentAvailability.gd")
const FreeRoamJobBoardScript := preload("res://core/jobs/FreeRoamJobBoard.gd")
const MeatspaceAutosaveServiceScript := preload("res://core/save/MeatspaceAutosaveService.gd")
const MeatspacePrologueControllerScript := preload("res://core/story/MeatspacePrologueController.gd")
const SensorTopologyControllerScript := preload("res://cyberspace/SensorTopologyController.gd")

enum GameDomain { CYBERSPACE, MEATSPACE, CLEAN_ROOM }

var persistent_game_state: PersistentGameState = PersistentGameStateScript.new()
var active_content_document: CyberspaceContentDocument
var active_content_profile: Dictionary = {}
var content_availability: ContentAvailability = ContentAvailabilityScript.new()
var free_roam_job_board: FreeRoamJobBoard
var prologue_controller: MeatspacePrologueController
var autosave_service: RefCounted = MeatspaceAutosaveServiceScript.new()
var game_over_active := false
var game_over_message := ""
var _game_over_mode: GameMode.Value = GameMode.Value.STORY
var session_active := false
var network_graph: NetworkGraph
var player_network_position: PlayerNetworkPosition
var player_knowledge: PlayerKnowledge
var sensor_topology: SensorTopologyController
var sphere_tracker: CurrentSphereTracker
var trail_system: HackerTrailSystem
var action_clock: ActionClock
var cyberspace_clock: ActionClock
var realtime_world_clock: Variant
var realtime_process_manager: Variant
var comms_manager: Variant
var outbound_comms_manager: Variant
var video_feed_manager: Variant
var physical_alarm_manager: Variant
var physical_team_manager: Variant
var physical_team_knowledge: Variant
var team_support_encounter: Variant
var equipment_order_manager: Variant
var realtime_event_scheduler: Variant
var operation_pressure_manager: Variant
var evidence_archive: Variant
var realtime_story_router: Variant
var story_action_log: Array[Dictionary] = []
var story_messages: Array[Dictionary] = []
var story_graffiti: Array[Dictionary] = []
var realtime_event_log: Array[Dictionary] = []
var last_video_action_result: VideoFeedActionResult
var ice_controller: IceController
var hacker_npc_manager: HackerNPCManager
var scan_system: ScanSystem
var last_scan_result: ScanResult
var progression_controller: GraphProgressionController
var trace_level := 0
var pending_action_trace := 0
var resource_state: PlayerResourceState
var anchor_controller: AnchorController
var shortcut_controller: ShortcutController
var failure_controller: FailureRecoveryController
var deep_exploration: DeepExplorationController
var confrontation_controller: ConfrontationController
var last_confrontation_result: ConfrontationResult
var entry_guidance: AuthoredEntryGuidance
var mission: Variant
var facility_scenario: FacilityOperationScenario
var program_inventory: ProgramInventory
var program_loadout: ProgramLoadout
var doorstop_controller: DoorstopController
var san_controller: RefCounted
var intrusion_run_id: StringName = &""
var unresolved_modal_action_selection := false
var jack_out_prohibited := false
var _intrusion_sequence := 0
var intrusion_session: IntrusionSession
var game_domain: GameDomain = GameDomain.CYBERSPACE
var meatspace_management: MeatspaceManagement
var clean_room_controller: CleanRoomController
var connection_trace_progress := 0.0
var doorstop_programming_definition: DoorstopDefinition
var doorstop_suspension_policy: DoorstopSuspensionPolicy
var suspended_intrusion_advancer: SuspendedIntrusionAdvancer
var suspended_security_level := 0
var temporary_cyberspace_effects: Array[Dictionary] = []
var suspended_intrusion_events: Array[Dictionary] = []
var suspended_replacement_ice_factory: Callable
var suspended_node_process_advancer: Callable
var doorstop_acquisition_help_shown := false
var doorstop_deployment_help_shown := false


func create_new_game(mode: Variant = GameMode.Value.STORY, options: Dictionary = {}) -> void:
	var resolved := GameMode.from_frontend_id(mode) if mode is String or mode is StringName else int(mode)
	persistent_game_state = PersistentGameStateScript.new()
	persistent_game_state.set_game_mode(resolved as GameMode.Value)
	if persistent_game_state.is_story_mode():
		StoryModeNewGameInitializerScript.initialize(persistent_game_state)
	else:
		FreeRoamNewGameInitializerScript.initialize(persistent_game_state, bool(options.get("run_introduction", false)))
	_configure_content_availability()

func get_game_mode() -> GameMode.Value:
	return persistent_game_state.get_game_mode()

func is_story_mode() -> bool:
	return persistent_game_state.is_story_mode()

func is_free_roam_mode() -> bool:
	return persistent_game_state.is_free_roam_mode()

func get_campaign_state() -> Dictionary:
	return persistent_game_state.campaign_state.duplicate(true)

func get_player_persistent_state() -> Dictionary:
	return persistent_game_state.player_state.duplicate(true)

func get_world_state() -> Dictionary:
	return persistent_game_state.world_state.duplicate(true)

func is_content_available(content_id: StringName) -> bool:
	return content_availability.is_content_available(content_id, persistent_game_state)

func is_runtime_bundle_active(content_id: StringName) -> bool:
	if not is_content_available(content_id): return false
	return content_id in active_content_profile.get("runtime_bundles", [])

func _is_active_authored_entry_available(content_id: StringName) -> bool:
	if bool(active_content_profile.get("reuse_authored_content", false)): return true
	return is_content_available(content_id)

func resolve_content_id(content_id: StringName) -> StringName:
	return content_availability.resolve_content_id(content_id, persistent_game_state)

func complete_optional_tutorial() -> Dictionary:
	if active_content_profile.get("tutorial_profile", &"") != &"FREE_ROAM_OPTIONAL":
		return {"success": false, "reason": "No optional Free Roam introduction is active."}
	var tutorial_state: Dictionary = persistent_game_state.world_state.get("tutorial_state", {}).duplicate(true)
	tutorial_state["introduction_completed"] = true
	persistent_game_state.world_state["tutorial_state"] = tutorial_state
	persistent_game_state.world_state["entry_state"] = &"HOME_DECK_MANAGEMENT"
	persistent_game_state.world_state["pending_entry_content_id"] = StringName(active_content_profile.get("return_content_id", &"FREE_ROAM_HOME"))
	persistent_game_state.world_state["current_content_id"] = &""
	return {"success": true, "reason": "Optional introduction completed.", "next_content_id": persistent_game_state.world_state.pending_entry_content_id}

func _configure_content_availability() -> void:
	content_availability.clear()
	content_availability.register_content(&"SHARED_SIMULATION", &"AVAILABLE_IN_ALL_MODES")
	content_availability.register_content(&"SHARED_ECONOMY", &"AVAILABLE_IN_ALL_MODES")
	content_availability.register_content(&"FACILITY_OPERATION_PROTOTYPE", &"STORY_ONLY")
	content_availability.register_content(&"STORY_PROLOGUE", &"STORY_ONLY", {}, {&"kind": &"MEATSPACE_PROLOGUE", &"runtime_definition_path": "res://data/authoring/story_prologue.tres"})
	content_availability.register_content(&"FREE_ROAM_HOME", &"FREE_ROAM_ONLY", {}, {&"kind": &"FREE_ROAM_WORLD"})
	var first_contact := load("res://data/authoring/first_contact.tres") as CyberspaceContentDocument
	content_availability.register_document(first_contact)
	content_availability.register_content(&"FIRST_CONTACT_FREE_ROAM_TUTORIAL", &"FREE_ROAM_ONLY", {}, {
		&"kind": &"AUTHORED_NETWORK",
		&"runtime_document_path": first_contact.resource_path,
		&"tutorial_profile": &"FREE_ROAM_OPTIONAL",
		&"campaign_progression_enabled": false,
		&"reuse_authored_content": true,
		&"return_content_id": &"FREE_ROAM_HOME",
	})
	var free_roam_jobs := load("res://data/free_roam/free_roam_jobs.tres") as FreeRoamJobCatalog
	if free_roam_jobs != null:
		for job in free_roam_jobs.jobs:
			if job != null: content_availability.register_content(job.id, &"FREE_ROAM_ONLY", {}, {&"kind": &"FREE_ROAM_JOB"})

func enter_free_roam_network() -> Dictionary:
	if not is_content_available(&"FREE_ROAM_HOME"): return {"success": false, "reason": "Free Roam network entry is unavailable."}
	if game_domain != GameDomain.MEATSPACE: return {"success": false, "reason": "Already connected to cyberspace."}
	var previous := game_domain
	game_domain = GameDomain.CLEAN_ROOM
	persistent_game_state.world_state["entry_state"] = &"CLEAN_ROOM"
	EventBus.game_domain_changed.emit(previous, game_domain)
	if clean_room_controller != null: clean_room_controller.enter()
	return {"success": true, "reason": "Entered the Clean-Room."}

func enter_netspace_from_clean_room() -> Dictionary:
	if game_domain != GameDomain.CLEAN_ROOM: return {"success": false, "reason": "The Clean-Room is not active."}
	var previous := game_domain
	game_domain = GameDomain.CYBERSPACE
	if intrusion_session != null and intrusion_session.lifecycle in [IntrusionSession.Lifecycle.ABORTED, IntrusionSession.Lifecycle.COMPLETED]: intrusion_session.lifecycle = IntrusionSession.Lifecycle.ACTIVE
	persistent_game_state.world_state["entry_state"] = &"ACTIVE_NETWORK"
	EventBus.game_domain_changed.emit(previous, game_domain)
	EventBus.network_display_update_requested.emit()
	return {"success": true, "reason": "Entering Netspace."}

func return_home_from_clean_room() -> Dictionary:
	if game_domain != GameDomain.CLEAN_ROOM: return {"success": false, "reason": "The Clean-Room is not active."}
	var previous := game_domain
	game_domain = GameDomain.MEATSPACE
	persistent_game_state.world_state["entry_state"] = &"MEATSPACE"
	EventBus.game_domain_changed.emit(previous, game_domain)
	var save_error := request_meatspace_autosave(MeatspaceAutosaveServiceScript.Reason.RETURN_TO_MEATSPACE, {&"source": &"CLEAN_ROOM"})
	return {"success": true, "reason": "Returned home." if save_error == OK else "Returned home, but autosave failed.", "save_error": save_error}

func return_to_clean_room(reason := "Run connection closed.") -> Dictionary:
	if game_domain != GameDomain.CYBERSPACE: return {"success": false, "reason": "No Netspace run is active."}
	var previous := game_domain
	game_domain = GameDomain.CLEAN_ROOM
	persistent_game_state.world_state["entry_state"] = &"CLEAN_ROOM"
	EventBus.game_domain_changed.emit(previous, game_domain)
	if clean_room_controller != null: clean_room_controller.enter()
	return {"success": true, "reason": reason}

func enter_meatspace(reason: int = MeatspaceAutosaveServiceScript.Reason.RETURN_TO_MEATSPACE, metadata: Dictionary = {}) -> Dictionary:
	if game_domain != GameDomain.CYBERSPACE: return {"success": false, "reason": "Player is already in meat space."}
	var previous := game_domain
	game_domain = GameDomain.MEATSPACE
	persistent_game_state.world_state["entry_state"] = &"MEATSPACE"
	EventBus.game_domain_changed.emit(previous, game_domain)
	var error := request_meatspace_autosave(reason, metadata)
	return {"success": error == OK, "reason": "Entered meat space." if error == OK else "Entered meat space, but autosave failed.", "save_error": error}

func jack_out_normally() -> Dictionary:
	if not session_active or intrusion_session == null or intrusion_session.lifecycle != IntrusionSession.Lifecycle.ACTIVE:
		return {"success": false, "reason": "No active intrusion can be disconnected."}
	intrusion_session.lifecycle = IntrusionSession.Lifecycle.ABORTED
	return return_to_clean_room("Disconnected to the Clean-Room.")

func complete_intrusion_and_return_to_meatspace(completion_data: Dictionary = {}) -> Dictionary:
	if intrusion_session == null: return {"success": false, "reason": "No intrusion is active."}
	var completed := intrusion_session.complete_normally(completion_data)
	if not completed.success: return completed
	if persistent_game_state.game_mode == GameMode.Value.STORY and active_content_document != null and active_content_document.document_id == &"FIRST_CONTACT":
		persistent_game_state.campaign_state.get_or_add("story_flags", {})["FIRST_CONTACT_COMPLETE"] = true
		var completed_ids: Array = persistent_game_state.campaign_state.get("completed_mission_ids", [])
		if "FIRST_CONTACT" not in completed_ids: completed_ids.append("FIRST_CONTACT")
		persistent_game_state.campaign_state["completed_mission_ids"] = completed_ids
	return return_to_clean_room("Run complete. Returned to the Clean-Room.")

func serialize_persistent_state() -> Dictionary:
	return persistent_game_state.to_save_data()

func restore_persistent_state(data: Dictionary) -> void:
	persistent_game_state = PersistentGameStateScript.from_save_data(data)
	_configure_content_availability()

func save_persistent_state(path: String) -> Error:
	if game_domain != GameDomain.MEATSPACE: return ERR_UNAUTHORIZED
	_synchronize_persistent_state_from_runtime()
	return persistent_game_state.save_to_file(path)

func request_meatspace_autosave(reason: int, metadata: Dictionary = {}) -> Error:
	if game_domain != GameDomain.MEATSPACE: return ERR_UNAUTHORIZED
	_synchronize_persistent_state_from_runtime()
	var error: Error = autosave_service.request(persistent_game_state, reason, metadata)
	EventBus.meatspace_autosave_completed.emit(MeatspaceAutosaveServiceScript.reason_id(reason), autosave_service.autosave_path, error)
	return error

func trigger_game_over(message := "CONNECTION TERMINATED") -> Dictionary:
	if game_over_active: return {"success": false, "reason": "Game Over is already active."}
	_game_over_mode = get_game_mode()
	game_over_message = message
	if intrusion_session != null and intrusion_session.lifecycle == IntrusionSession.Lifecycle.ACTIVE:
		intrusion_session.lifecycle = IntrusionSession.Lifecycle.FAILED
	end_session()
	game_over_active = true
	var can_continue: bool = autosave_service.has_valid_autosave()
	EventBus.game_over_started.emit(game_over_message, can_continue)
	return {"success": true, "reason": game_over_message, "can_continue": can_continue}

func continue_from_game_over() -> Dictionary:
	if not game_over_active: return {"success": false, "reason": "Game Over is not active."}
	var loaded: Dictionary = autosave_service.load_latest()
	var from_autosave: bool = loaded.error == OK
	var message := "LAST MEAT-SPACE AUTOSAVE RESTORED"
	if from_autosave:
		persistent_game_state = loaded.state
		_configure_content_availability()
	else:
		create_new_game(_game_over_mode)
		message = "NO VALID MEAT-SPACE AUTOSAVE. RETURNING TO THE START OF THIS MODE."
	start_session()
	game_over_active = false
	game_over_message = ""
	EventBus.game_over_recovered.emit(from_autosave, message)
	return {"success": true, "reason": message, "from_autosave": from_autosave}

func _synchronize_persistent_state_from_runtime() -> void:
	var player := persistent_game_state.player_state.duplicate(true)
	if program_inventory != null:
		var owned: Array[Dictionary] = []
		for instance: ProgramInstance in program_inventory.all_instances():
			owned.append({
				&"instance_id": instance.instance_id,
				&"definition_id": instance.definition_id(),
				&"version": instance.definition.version if instance.definition != null else "",
				&"metadata": instance.metadata.duplicate(true),
			})
		player["owned_programs"] = owned
	if program_loadout != null: player["installed_program_instance_ids"] = program_loadout.installed_instance_ids.duplicate()
	if meatspace_management != null:
		player["hardware"] = meatspace_management.hardware_levels.duplicate(true)
		if meatspace_management.software_programming != null:
			player["resources"] = meatspace_management.software_programming.resources.duplicate(true)
	if equipment_order_manager != null: player["credits"] = equipment_order_manager.credits
	# Hardware damage, reputation, inventory and progression fields not owned by
	# a live manager remain intact in the copied player dictionary.
	persistent_game_state.player_state = player

	var world := persistent_game_state.world_state.duplicate(true)
	world["entry_state"] = &"MEATSPACE"
	if meatspace_management != null and meatspace_management.software_programming != null:
		var tasks: Array[Dictionary] = []
		var now := float(realtime_world_clock.elapsed_seconds) if realtime_world_clock != null else 0.0
		for task: SoftwareProgrammingTask in meatspace_management.programming_tasks.values():
			tasks.append({
				&"id": task.id,
				&"definition_id": task.program_definition.id,
				&"definition_version": task.program_definition.version,
				&"output_instance_id": task.output_instance_id,
				&"duration": task.duration,
				&"remaining_seconds": maxf(0.0, task.duration - task.elapsed(now)),
				&"state": task.state,
			})
		world["programming_tasks"] = tasks
	if player_knowledge != null:
		world["network_knowledge"] = {
			&"nodes": player_knowledge.node_records.duplicate(true),
			&"links": player_knowledge.link_records.duplicate(true),
			&"spheres": player_knowledge.sphere_records.duplicate(true),
			&"services": player_knowledge.service_records.duplicate(true),
			&"ice": player_knowledge.ice_records.duplicate(true),
			&"hackers": player_knowledge.hacker_records.duplicate(true),
			&"observation_tick": player_knowledge.current_observation_tick,
		}
	if intrusion_session != null:
		var anchor := intrusion_session.suspended_anchor
		var san: Variant = san_controller.get_san(intrusion_run_id) if san_controller != null else null
		world["intrusion_snapshot"] = {
			&"id": intrusion_session.id,
			&"lifecycle": intrusion_session.lifecycle,
			&"suspended_at_realtime": intrusion_session.suspended_at_realtime,
			&"suspension_advanced_through": intrusion_session.suspension_advanced_through,
			&"resume_state": intrusion_session.resume_state.duplicate(true),
			&"trace": trace_level,
			&"san": {} if san == null else {
				&"host_node_id": san.host_node_id,
				&"integrity": san.integrity,
				&"deck_link_state": san.deck_link_state,
			},
			&"anchor": {} if anchor == null else {
				&"source_program_instance_id": anchor.source_program_instance_id,
				&"intrusion_run_id": anchor.intrusion_run_id,
				&"cyberspace_node_id": anchor.cyberspace_node_id,
				&"deployment_marker": anchor.deployment_marker,
				&"resume_data": anchor.resume_data.duplicate(true),
			},
		}
	persistent_game_state.world_state = world
	persistent_game_state.save_metadata["location_name"] = String(world.get("current_meatspace_location_id", "MEATSPACE"))

func _restore_saved_meatspace_runtime() -> void:
	var world: Dictionary = persistent_game_state.world_state
	if StringName(world.get("entry_state", &"")) != &"MEATSPACE": return
	_restore_saved_programming_tasks(world.get("programming_tasks", []))
	var snapshot: Dictionary = world.get("intrusion_snapshot", {})
	if snapshot.is_empty(): return
	var resume: Dictionary = snapshot.get("resume_state", {})
	var knowledge: Dictionary = resume.get("player_knowledge", world.get("network_knowledge", {}))
	if player_knowledge != null and not knowledge.is_empty():
		player_knowledge.node_records = _string_name_keyed(knowledge.get("nodes", {}))
		player_knowledge.link_records = _string_name_keyed(knowledge.get("links", {}))
		player_knowledge.sphere_records = _string_name_keyed(knowledge.get("spheres", {}))
		player_knowledge.service_records = _string_name_keyed(knowledge.get("services", {}))
		player_knowledge.ice_records = _string_name_keyed(knowledge.get("ice", {}))
		player_knowledge.hacker_records = _string_name_keyed(knowledge.get("hackers", {}))
		player_knowledge.current_observation_tick = int(knowledge.get("observation_tick", 0))
	for value: Variant in resume.get("network_links", {}):
		var link := network_graph.get_link(StringName(value))
		if link == null: continue
		var state: Dictionary = resume.network_links[value]
		link.locked = bool(state.get("locked", link.locked)); link.disabled = bool(state.get("disabled", link.disabled)); link.hidden = bool(state.get("hidden", link.hidden)); link.discovered = bool(state.get("discovered", link.discovered)); link.traversal_cost = int(state.get("traversal_cost", link.traversal_cost))
	trace_level = int(snapshot.get("trace", resume.get("trace", 0)))
	action_clock.current_tick = int(resume.get("cyber_tick", action_clock.current_tick))
	resource_state.volatile_resources = _string_name_keyed(resume.get("volatile_resources", {}))
	resource_state.stored_resources = _string_name_keyed(resume.get("stored_resources", {}))
	for value: Variant in resume.get("ice", {}):
		var ice := ice_controller.get_ice(StringName(value))
		if ice == null: continue
		var state: Dictionary = resume.ice[value]
		ice.current_node_id = StringName(state.get("current_node_id", ice.current_node_id)); ice.target_node_id = StringName(state.get("target_node_id", ice.target_node_id)); ice.state = int(state.get("state", ice.state)); ice.alert_level = int(state.get("alert_level", ice.alert_level)); ice.known_player_position = StringName(state.get("known_player_position", &"")); ice.last_known_player_position = StringName(state.get("last_known_player_position", &""))
	var saved_id := StringName(snapshot.get("id", intrusion_run_id))
	var lifecycle := int(snapshot.get("lifecycle", IntrusionSession.Lifecycle.ACTIVE))
	intrusion_run_id = saved_id
	intrusion_session = IntrusionSessionScript.new(saved_id)
	intrusion_session.lifecycle = lifecycle
	intrusion_session.resume_state = resume.duplicate(true)
	intrusion_session.suspended_at_realtime = float(snapshot.get("suspended_at_realtime", -1.0))
	intrusion_session.suspension_advanced_through = float(snapshot.get("suspension_advanced_through", intrusion_session.suspended_at_realtime))
	var anchor_data: Dictionary = snapshot.get("anchor", {})
	var san_data: Dictionary = snapshot.get("san", {})
	var host_id := StringName(san_data.get("host_node_id", anchor_data.get("cyberspace_node_id", player_network_position.current_node_id)))
	var old_san: Variant = san_controller.get_san(san_controller.sans_by_intrusion.keys()[0]) if san_controller != null and not san_controller.sans_by_intrusion.is_empty() else null
	if old_san != null: player_knowledge.set_local_system_access_node(old_san.host_node_id, old_san.id, false)
	san_controller = SystemAccessNodeControllerScript.new(network_graph, player_knowledge, &"PLAYER")
	san_controller.configure_ice_controller(ice_controller)
	var san_result: Dictionary = san_controller.create_san(&"PLAYER", saved_id, StringName(persistent_game_state.player_state.get("deck_id", &"ACTIVE_DECK")), host_id, float(snapshot.get("suspended_at_realtime", 0.0)))
	if san_result.success:
		san_result.san.integrity = int(san_data.get("integrity", san_result.san.integrity))
		san_result.san.deck_link_state = int(san_data.get("deck_link_state", san_result.san.deck_link_state))
	san_controller.san_relocated.connect(_on_san_relocated)
	doorstop_controller.configure_san_controller(san_controller)
	if not anchor_data.is_empty():
		var anchor := DoorstopAnchor.new(StringName(anchor_data.get("source_program_instance_id", &"")), saved_id, StringName(anchor_data.get("cyberspace_node_id", host_id)), float(anchor_data.get("deployment_marker", 0.0)), anchor_data.get("resume_data", {}))
		doorstop_controller.anchors_by_run[saved_id] = anchor
		intrusion_session.suspended_anchor = anchor
		player_network_position.relocate(anchor.cyberspace_node_id)
	game_domain = GameDomain.MEATSPACE

func _restore_saved_programming_tasks(records: Variant) -> void:
	if not records is Array or meatspace_management == null: return
	var manager := meatspace_management.software_programming
	var now := float(realtime_world_clock.elapsed_seconds) if realtime_world_clock != null else 0.0
	for record: Dictionary in records:
		var definition_id := StringName(record.get("definition_id", &""))
		var definition: ProgramDefinition = doorstop_programming_definition if definition_id == &"DOORSTOP_STANDARD" else ProgramDefinitionScript.new(definition_id, String(definition_id).replace("_", " ").capitalize(), String(record.get("definition_version", "1.0")))
		var task := SoftwareProgrammingTask.new(StringName(record.get("id", &"")), definition, StringName(record.get("output_instance_id", &"")), now, float(record.get("remaining_seconds", 0.0)))
		task.state = int(record.get("state", SoftwareProgrammingTask.State.PROGRAMMING))
		manager.tasks[task.id] = task

func _string_name_keyed(source: Variant) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for key: Variant in source: result[StringName(key)] = source[key]
	return result

func load_persistent_state(path: String) -> Error:
	var result := PersistentGameStateScript.load_from_file(path)
	if result.error != OK: return result.error
	persistent_game_state = result.state
	_configure_content_availability()
	return OK


func start_session() -> void:
	_ensure_realtime_world_clock()
	_clear_content_runtime_state()
	evidence_archive.reset()
	active_content_document = null
	active_content_profile = {}
	_configure_content_availability()
	var entry_content_id := StringName(persistent_game_state.campaign_state.get("pending_entry_content_id", &""))
	if entry_content_id.is_empty(): entry_content_id = StringName(persistent_game_state.campaign_state.get("current_content_id", &""))
	if entry_content_id.is_empty(): entry_content_id = StringName(persistent_game_state.world_state.get("pending_entry_content_id", &""))
	if entry_content_id.is_empty(): entry_content_id = StringName(persistent_game_state.world_state.get("current_content_id", &""))
	active_content_profile = content_availability.get_metadata(entry_content_id) if is_content_available(entry_content_id) else {}
	if active_content_profile.get("kind", &"") == &"AUTHORED_NETWORK":
		active_content_document = load(String(active_content_profile.get("runtime_document_path", ""))) as CyberspaceContentDocument
		var entry_filter := Callable(self, "_is_active_authored_entry_available")
		network_graph = AuthoredNetworkRuntimeBuilderScript.build_graph(active_content_document, entry_filter)
		player_network_position = AuthoredNetworkRuntimeBuilderScript.build_player(active_content_document, network_graph)
		player_knowledge = AuthoredNetworkRuntimeBuilderScript.build_knowledge(active_content_document, network_graph)
	elif active_content_profile.get("kind", &"") == &"FREE_ROAM_WORLD":
		network_graph = FreeRoamWorldFactoryScript.create_graph()
		player_network_position = FreeRoamWorldFactoryScript.create_player()
		player_knowledge = FreeRoamWorldFactoryScript.create_knowledge(network_graph)
	elif active_content_profile.get("kind", &"") == &"MEATSPACE_PROLOGUE":
		network_graph = NetworkGraph.new()
		var local_node := NetworkNodeDefinition.new(&"PROLOGUE_LOCAL", "Local Deck Interface", NetworkNodeDefinition.NodeType.GATEWAY, 0, true, &"PLAYER")
		network_graph.add_node(local_node)
		player_network_position = PlayerNetworkPosition.new(&"PROLOGUE_LOCAL", 0)
		player_knowledge = PlayerKnowledge.new()
		player_knowledge.reveal_node(local_node, KnowledgeLevel.Value.SCANNED)
		player_knowledge.mark_node_visited(local_node, &"PROLOGUE_LOCAL")
	else:
		active_content_profile = {&"kind": &"LEGACY_FACILITY", &"runtime_bundles": [&"FACILITY_OPERATION_PROTOTYPE"]}
		network_graph = FacilityOperationFactory.create_graph()
		player_network_position = FacilityOperationFactory.create_player()
		player_knowledge = FacilityOperationFactory.create_knowledge(network_graph)
	sphere_tracker = CurrentSphereTrackerScript.new(network_graph)
	sphere_tracker.register_player(&"PLAYER", player_network_position)
	sphere_tracker.sphere_changed.connect(EventBus.sphere_changed.emit)
	cyberspace_clock = CyberspaceClockScript.new()
	action_clock = cyberspace_clock
	realtime_world_clock.start(true)
	realtime_process_manager.bind_clock(realtime_world_clock)
	if is_runtime_bundle_active(&"FACILITY_OPERATION_PROTOTYPE"):
		_create_debug_realtime_processes()
		_create_debug_comms()
		_create_debug_outbound_comms()
		_create_debug_video_feeds()
		_create_debug_physical_alarms()
		_create_debug_physical_teams()
		_create_team_support_encounter()
		_create_debug_realtime_timeline()
		_create_debug_operation_pressure()
		_create_debug_realtime_story()
	_create_shared_equipment_economy()
	_create_free_roam_job_board()
	_create_program_loadout(active_content_profile.get("kind", &"") != &"MEATSPACE_PROLOGUE")
	var hardware: Dictionary = persistent_game_state.player_state.get("hardware", {})
	if hardware.has(&"DECK_DETECTION") and not hardware.has(&"DECK_SENSORS"): hardware[&"DECK_SENSORS"] = int(hardware[&"DECK_DETECTION"])
	hardware[&"DECK_SENSORS"] = int(hardware.get(&"DECK_SENSORS", 1))
	persistent_game_state.player_state["hardware"] = hardware
	sensor_topology = SensorTopologyControllerScript.new()
	sensor_topology.configure(network_graph, player_network_position, player_knowledge, int(hardware[&"DECK_SENSORS"]))
	sensor_topology.sensor_view_changed.connect(EventBus.network_display_update_requested.emit)
	if meatspace_management != null:
		meatspace_management.hardware_changed.connect(_on_hardware_changed)
	ice_controller = IceController.new(network_graph, player_network_position, player_knowledge)
	if active_content_document != null:
		AuthoredNetworkRuntimeBuilderScript.populate_ice(active_content_document, ice_controller, Callable(self, "_is_active_authored_entry_available"))
	elif active_content_profile.get("kind", &"") == &"FREE_ROAM_WORLD":
		FreeRoamWorldFactoryScript.populate_ice(ice_controller)
	else:
		FacilityOperationFactory.populate_ice(ice_controller)
		player_knowledge.detect_ice(&"FACILITY_SENTINEL_01")
	hacker_npc_manager = HackerNPCManager.new()
	hacker_npc_manager.name = "HackerNPCManager"
	add_child(hacker_npc_manager)
	hacker_npc_manager.configure(network_graph, player_network_position, player_knowledge)
	if active_content_document != null:
		AuthoredNetworkRuntimeBuilderScript.populate_hackers(active_content_document, hacker_npc_manager, Callable(self, "_is_active_authored_entry_available"))
	hacker_npc_manager.display_update_requested.connect(EventBus.network_display_update_requested.emit)
	if active_content_profile.get("kind", &"") == &"MEATSPACE_PROLOGUE":
		prologue_controller = MeatspacePrologueControllerScript.new()
		prologue_controller.configure(load(String(active_content_profile.runtime_definition_path)) as MeatspacePrologueDefinition, persistent_game_state)
		prologue_controller.prologue_completed.connect(_on_story_prologue_completed)
	scan_system = ScanSystem.new(network_graph, player_network_position, player_knowledge, ice_controller, realtime_process_manager.endpoints, realtime_process_manager.processes)
	progression_controller = GraphProgressionController.new(network_graph, player_network_position, player_knowledge)
	resource_state = PlayerResourceState.new()
	anchor_controller = AnchorController.new(network_graph)
	var entry_node_id := player_network_position.current_node_id
	anchor_controller.register_anchor(AnchorDefinition.new(entry_node_id, "Network Entry Anchor"))
	anchor_controller.activate_anchor(entry_node_id)
	shortcut_controller = ShortcutController.new(network_graph)
	failure_controller = FailureRecoveryController.new(anchor_controller, resource_state, player_network_position)
	deep_exploration = DeepExplorationController.new(network_graph, anchor_controller, player_network_position)
	confrontation_controller = ConfrontationController.new(network_graph, player_network_position, player_knowledge, ice_controller)
	mission = FacilityOperationMission.new(network_graph, player_network_position, player_knowledge, resource_state, shortcut_controller) if is_runtime_bundle_active(&"FACILITY_OPERATION_PROTOTYPE") else null
	action_clock.register_ice_updater(_update_ice)
	action_clock.register_trace_updater(_update_trace)
	action_clock.register_network_updater(_update_network_systems)
	_bind_network_events()
	if is_runtime_bundle_active(&"FACILITY_OPERATION_PROTOTYPE"): _create_facility_scenario()
	else:
		facility_scenario = null
		if persistent_game_state.campaign_state.get("pending_entry_content_id", &"") == entry_content_id:
			persistent_game_state.campaign_state["pending_entry_content_id"] = &""
		elif persistent_game_state.world_state.get("pending_entry_content_id", &"") == entry_content_id:
			persistent_game_state.world_state["current_content_id"] = entry_content_id
			persistent_game_state.world_state["pending_entry_content_id"] = &""
	if active_content_profile.get("kind", &"") in [&"FREE_ROAM_WORLD", &"MEATSPACE_PROLOGUE"]:
		game_domain = GameDomain.MEATSPACE
	elif active_content_profile.get("kind", &"") == &"AUTHORED_NETWORK":
		game_domain = GameDomain.CLEAN_ROOM
	_restore_saved_meatspace_runtime()
	session_active = true
	EventBus.session_started.emit()
	if game_domain == GameDomain.CLEAN_ROOM and clean_room_controller != null: clean_room_controller.enter()
	if active_content_document != null:
		entry_guidance = AuthoredEntryGuidance.new()
		add_child(entry_guidance)
		entry_guidance.configure(active_content_document, persistent_game_state, player_network_position.current_node_id)


func _create_program_loadout(create_connection := true) -> void:
	_intrusion_sequence += 1
	intrusion_run_id = StringName("INTRUSION_%06d" % _intrusion_sequence)
	intrusion_session = IntrusionSessionScript.new(intrusion_run_id)
	trail_system = HackerTrailSystemScript.new()
	trail_system.track_actor(player_network_position, &"PLAYER", intrusion_run_id, func() -> int: return action_clock.current_tick if action_clock != null else 0)
	game_domain = GameDomain.CYBERSPACE
	program_inventory = ProgramInventoryScript.new()
	program_inventory.instance_added.connect(_on_program_instance_added)
	program_loadout = ProgramLoadoutScript.new(5)
	var standard = DoorstopDefinitionScript.new(&"DOORSTOP_STANDARD", "Doorstop", "1.0")
	doorstop_programming_definition = standard
	standard.rarity = &"UNCOMMON"
	standard.programming_recipe = {&"MEMORY_SHARD": 2, &"ROUTING_KERNEL": 1}
	standard.programming_requirements = {&"capability": &"ROOTKIT"}
	standard.programming_duration = 4.0
	var reserve = DoorstopDefinitionScript.new(&"DOORSTOP_GHOST", "Doorstop Ghost", "2.0")
	reserve.rarity = &"RARE"
	reserve.programming_recipe = {&"MEMORY_SHARD": 3, &"ROUTING_KERNEL": 1, &"GHOST_SIGNATURE": 1}
	reserve.programming_requirements = {&"capability": &"GHOST"}
	reserve.programming_duration = 8.0
	reserve.trace_modifiers = {&"deployment_trace": -1}
	reserve.security_modifiers = {&"suspicion": 0}
	if not persistent_game_state.player_state.is_empty():
		_create_persistent_starter_programs()
	else:
		program_inventory.add_instance(ProgramInstanceScript.new(&"DOORSTOP_INSTANCE_001", standard))
		program_inventory.add_instance(ProgramInstanceScript.new(&"DOORSTOP_INSTANCE_002", standard))
		program_inventory.add_instance(ProgramInstanceScript.new(&"DOORSTOP_GHOST_INSTANCE_001", reserve))
		program_loadout.install(&"DOORSTOP_INSTANCE_001", program_inventory)
	doorstop_controller = DoorstopControllerScript.new(program_inventory, program_loadout)
	san_controller = SystemAccessNodeControllerScript.new(network_graph, player_knowledge, &"PLAYER")
	san_controller.configure_ice_controller(ice_controller)
	if create_connection:
		san_controller.create_san(&"PLAYER", intrusion_run_id, &"ACTIVE_DECK", player_network_position.current_node_id, float(action_clock.current_tick))
	san_controller.san_relocated.connect(_on_san_relocated)
	doorstop_controller.configure_san_controller(san_controller)
	doorstop_suspension_policy = DoorstopSuspensionPolicyScript.forgiving()
	suspended_intrusion_advancer = SuspendedIntrusionAdvancerScript.new()
	suspended_security_level = 0
	temporary_cyberspace_effects.clear()
	suspended_intrusion_events.clear()
	suspended_replacement_ice_factory = Callable()
	suspended_node_process_advancer = Callable()
	meatspace_management = MeatspaceManagementScript.new()
	meatspace_management.configure(program_inventory, program_loadout, equipment_order_manager, realtime_world_clock)
	clean_room_controller = CleanRoomController.new()
	clean_room_controller.configure(persistent_game_state, meatspace_management)
	if not persistent_game_state.player_state.is_empty():
		meatspace_management.hardware_levels = (persistent_game_state.player_state.get("hardware", {}) as Dictionary).duplicate(true)
		equipment_order_manager.credits = int(persistent_game_state.player_state.get("credits", 0))
		var starter_resources: Dictionary = persistent_game_state.player_state.get("resources", {})
		for resource_id: Variant in starter_resources:
			meatspace_management.software_programming.add_resource(StringName(resource_id), int(starter_resources[resource_id]))
	else:
		meatspace_management.software_programming.add_resource(&"MEMORY_SHARD", 12)
		meatspace_management.software_programming.add_resource(&"ROUTING_KERNEL", 6)
		meatspace_management.software_programming.add_resource(&"GHOST_SIGNATURE", 2)

func _create_persistent_starter_programs() -> void:
	var definitions := {}
	for program_data: Dictionary in persistent_game_state.player_state.get("owned_programs", []):
		var definition_id := StringName(program_data.get("definition_id", &""))
		var definition: ProgramDefinition = definitions.get(definition_id)
		if definition == null:
			definition = doorstop_programming_definition if definition_id == &"DOORSTOP_STANDARD" else ProgramDefinitionScript.new(definition_id, String(definition_id).replace("_", " ").capitalize(), "1.0")
			definitions[definition_id] = definition
		program_inventory.add_instance(ProgramInstanceScript.new(StringName(program_data.get("instance_id", &"")), definition, {&"source": &"NEW_GAME_STARTER"}))
	for instance_id: Variant in persistent_game_state.player_state.get("installed_program_instance_ids", []):
		program_loadout.install(StringName(instance_id), program_inventory)

func _on_hardware_changed(component_id: StringName, level: int) -> void:
	if component_id != &"DECK_SENSORS" or sensor_topology == null: return
	var hardware: Dictionary = persistent_game_state.player_state.get("hardware", {}).duplicate(true)
	hardware[component_id] = level
	persistent_game_state.player_state["hardware"] = hardware
	persistent_game_state.emit_changed()
	sensor_topology.set_sensors_rating(level)

func _create_free_roam_job_board() -> void:
	free_roam_job_board = null
	if not is_free_roam_mode(): return
	var catalog := load("res://data/free_roam/free_roam_jobs.tres") as FreeRoamJobCatalog
	if catalog == null or not catalog.validate().is_empty(): return
	free_roam_job_board = FreeRoamJobBoardScript.new()
	free_roam_job_board.configure(catalog, persistent_game_state)


func end_session() -> void:
	if entry_guidance != null:
		entry_guidance.active = false
		entry_guidance.queue_free()
		entry_guidance = null
	session_active = false
	if realtime_world_clock != null:
		realtime_world_clock.stop()
	if trail_system != null and player_network_position != null: trail_system.untrack_actor(player_network_position)
	trail_system = null
	network_graph = null
	player_network_position = null
	player_knowledge = null
	sensor_topology = null
	sphere_tracker = null
	san_controller = null
	action_clock = null
	cyberspace_clock = null
	ice_controller = null
	if hacker_npc_manager != null:
		hacker_npc_manager.queue_free()
	hacker_npc_manager = null
	scan_system = null
	last_scan_result = null
	progression_controller = null
	trace_level = 0
	pending_action_trace = 0
	connection_trace_progress = 0.0
	resource_state = null
	anchor_controller = null
	shortcut_controller = null
	failure_controller = null
	deep_exploration = null
	confrontation_controller = null
	last_confrontation_result = null

	mission = null
	free_roam_job_board = null
	prologue_controller = null
	program_inventory = null
	program_loadout = null
	doorstop_controller = null
	intrusion_run_id = &""
	intrusion_session = null
	game_domain = GameDomain.CYBERSPACE
	meatspace_management = null
	doorstop_programming_definition = null
	doorstop_suspension_policy = null
	suspended_intrusion_advancer = null
	suspended_security_level = 0
	temporary_cyberspace_effects.clear()
	suspended_intrusion_events.clear()
	suspended_replacement_ice_factory = Callable()
	suspended_node_process_advancer = Callable()
	unresolved_modal_action_selection = false
	jack_out_prohibited = false
	if facility_scenario != null:
		facility_scenario.queue_free()
		facility_scenario = null

func _on_story_prologue_completed(_next_content_id: StringName) -> void:
	if active_content_profile.get("kind", &"") != &"MEATSPACE_PROLOGUE": return
	end_session()
	start_session()

func get_current_sphere(player_id: StringName = &"PLAYER") -> SphereDefinition:
	return sphere_tracker.get_current_sphere(player_id) if sphere_tracker != null else null

func get_sphere_for_node(node_id: StringName) -> SphereDefinition:
	return network_graph.get_sphere_for_node(node_id) if network_graph != null else null

func get_nodes_in_sphere(sphere_id: StringName) -> Array[StringName]:
	return network_graph.get_nodes_in_sphere(sphere_id) if network_graph != null else []


func _ensure_realtime_world_clock() -> void:
	if realtime_world_clock != null:
		return
	realtime_world_clock = RealtimeWorldClockScript.new()
	realtime_world_clock.name = "RealtimeWorldClock"
	add_child(realtime_world_clock)
	realtime_process_manager = RealtimeProcessManagerScript.new()
	realtime_process_manager.name = "RealtimeProcessManager"
	add_child(realtime_process_manager)
	realtime_process_manager.bind_clock(realtime_world_clock)
	comms_manager = CommsManagerScript.new()
	comms_manager.name = "CommsInterceptionManager"
	add_child(comms_manager)
	outbound_comms_manager = OutboundManagerScript.new()
	outbound_comms_manager.name = "OutboundCommsManager"
	add_child(outbound_comms_manager)
	video_feed_manager = VideoFeedManagerScript.new()
	video_feed_manager.name = "VideoFeedManager"
	add_child(video_feed_manager)
	physical_alarm_manager = PhysicalAlarmManagerScript.new()
	physical_alarm_manager.name = "PhysicalAlarmManager"
	add_child(physical_alarm_manager)
	physical_team_manager = TeamManagerScript.new()
	physical_team_manager.name = "PhysicalTeamManager"
	add_child(physical_team_manager)
	team_support_encounter = TeamSupportEncounterScript.new()
	team_support_encounter.name = "TeamSupportEncounter"
	add_child(team_support_encounter)
	equipment_order_manager = EquipmentOrderManagerScript.new()
	equipment_order_manager.name = "EquipmentOrderManager"
	add_child(equipment_order_manager)
	realtime_event_scheduler = RealtimeEventSchedulerScript.new()
	realtime_event_scheduler.name = "RealtimeEventScheduler"
	add_child(realtime_event_scheduler)
	operation_pressure_manager = OperationPressureManagerScript.new()
	operation_pressure_manager.name = "OperationPressureManager"
	add_child(operation_pressure_manager)
	evidence_archive = EvidenceArchiveScript.new()
	evidence_archive.name = "EvidenceArchive"
	add_child(evidence_archive)
	evidence_archive.configure(realtime_world_clock)
	comms_manager.bind_evidence_archive(evidence_archive)
	video_feed_manager.bind_evidence_archive(evidence_archive)
	realtime_story_router = RealtimeStoryRouterScript.new()
	realtime_story_router.name = "RealtimeStoryRouter"
	add_child(realtime_story_router)
	realtime_story_router.configure(realtime_world_clock)
	realtime_story_router.bind_sources(comms_manager, video_feed_manager, physical_alarm_manager, physical_team_manager, equipment_order_manager, realtime_event_scheduler)

func _clear_content_runtime_state() -> void:
	# Managers persist across screen/session changes; authored scenario content must not.
	if realtime_process_manager != null:
		realtime_process_manager.processes.clear()
		realtime_process_manager.endpoints.clear()
	if comms_manager != null:
		comms_manager.channels.clear(); comms_manager.participants.clear(); comms_manager.sessions.clear()
		comms_manager.active_session_id = &""
	if outbound_comms_manager != null:
		outbound_comms_manager.targets.clear(); outbound_comms_manager.story_hooks.clear(); outbound_comms_manager.flags.clear()
	if video_feed_manager != null:
		video_feed_manager.definitions.clear(); video_feed_manager.sessions.clear(); video_feed_manager.open_feed_id = &""
		video_feed_manager.total_security_suspicion = 0
	if physical_alarm_manager != null:
		physical_alarm_manager.definitions.clear(); physical_alarm_manager.instances.clear(); physical_alarm_manager.monitored_alarm_ids.clear()
	if physical_team_manager != null:
		physical_team_manager.definitions.clear(); physical_team_manager.instances.clear(); physical_team_manager.location_graph = null
	if realtime_event_scheduler != null:
		realtime_event_scheduler.definitions.clear(); realtime_event_scheduler.instances.clear(); realtime_event_scheduler.operation_start_times.clear(); realtime_event_scheduler.action_handlers.clear()
	if operation_pressure_manager != null: operation_pressure_manager.operations.clear()
	if realtime_story_router != null: realtime_story_router.reset()
	story_action_log.clear(); story_messages.clear(); story_graffiti.clear(); realtime_event_log.clear()


func _create_debug_realtime_processes() -> void:
	realtime_process_manager.processes.clear()
	realtime_process_manager.endpoints.clear()
	var definitions: Array[Dictionary] = [
		{"id": &"CAM_LOADING_DOCK", "type": RealtimeProcessScript.ProcessType.VIDEO_FEED, "name": "Loading Dock Camera", "source": &"CAMERA_SERVER"},
		{"id": &"CAM_SERVICE_HALL", "type": RealtimeProcessScript.ProcessType.VIDEO_FEED, "name": "Service Hall Camera", "source": &"CAMERA_SERVER"},
		{"id": &"SECURITY_RADIO", "type": RealtimeProcessScript.ProcessType.RADIO_NET, "name": "Security Radio", "source": &"PBX_SERVER"},
		{"id": &"GUARD_PHONE_CALL", "type": RealtimeProcessScript.ProcessType.VOICE_CALL, "name": "Guard Phone Call", "source": &"PBX_SERVER", "duration": 120.0},
		{"id": &"ALARM_ZONE_SERVER", "type": RealtimeProcessScript.ProcessType.ALARM, "name": "Server Room Alarm Zone", "source": &"ALARM_CONTROLLER"},
		{"id": &"TEAM_ALPHA_PROCESS", "type": RealtimeProcessScript.ProcessType.PENETRATION_TEAM, "name": "Team Alpha", "source": &"FIELD_OPERATIONS", "duration": 180.0},
	]
	for definition: Dictionary in definitions:
		var process = RealtimeProcessScript.new(
			definition["id"], definition["type"], definition["name"],
			definition["source"], definition.get("duration", -1.0)
		)
		process.discovered = false
		process.accessible = false
		process.metadata = {"debug_fixture": true}
		process.tags.assign([&"DEBUG", &"MEATSPACE"])
		realtime_process_manager.add_process(process, true)

	var security_endpoint = RealtimeEndpointScript.new(
		&"CAMERA_INTERFACE", RealtimeEndpointScript.EndpointType.VIDEO,
		FacilityOperationFactory.CAMERA_SERVER, &"CAMERA_CONTROL",
		[&"CAM_LOADING_DOCK", &"CAM_SERVICE_HALL"] as Array[StringName]
	)
	security_endpoint.description = "Physical security telemetry and response coordination interface."
	security_endpoint.authority_requirement = 0
	security_endpoint.tags.assign([&"SECURITY", &"PHYSICAL"])
	realtime_process_manager.add_endpoint(security_endpoint)

	var alarm_endpoint = RealtimeEndpointScript.new(
		&"SERVER_ALARM_INTERFACE", RealtimeEndpointScript.EndpointType.ALARM,
		FacilityOperationFactory.ALARM_CONTROLLER, &"ALARM_ZONE_CONTROL",
		[&"ALARM_ZONE_SERVER"] as Array[StringName]
	)
	alarm_endpoint.description = "Building alarm panels, sensor zones, and facilities alerts."
	alarm_endpoint.authority_requirement = 0
	alarm_endpoint.tags.assign([&"ALARM", &"PHYSICAL_SECURITY"])
	realtime_process_manager.add_endpoint(alarm_endpoint)

	var team_endpoint = RealtimeEndpointScript.new(
		&"PHYSICAL_TEAM_TRACKING", RealtimeEndpointScript.EndpointType.TEAM_TRACKING,
		FacilityOperationFactory.SECURITY_NET, &"SECURITY_DIRECTORY",
		[&"TEAM_ALPHA_PROCESS"] as Array[StringName]
	)
	team_endpoint.description = "Badge, telemetry, and facility tracking aggregation."
	team_endpoint.authority_requirement = 0
	team_endpoint.tags.assign([&"TEAM_TRACKING", &"PHYSICAL_SECURITY"])
	realtime_process_manager.add_endpoint(team_endpoint)

	var call_endpoint = RealtimeEndpointScript.new(
		&"PBX_COMMS_INTERFACE", RealtimeEndpointScript.EndpointType.COMMS,
		FacilityOperationFactory.PBX_SERVER, &"PBX_SWITCH",
		[&"SECURITY_RADIO", &"GUARD_PHONE_CALL"] as Array[StringName]
	)
	call_endpoint.description = "Workstation bridge into the building voice system."
	call_endpoint.access_requirement = &""
	call_endpoint.tags.assign([&"COMMS", &"VOICE"])
	realtime_process_manager.add_endpoint(call_endpoint)


func _create_debug_comms() -> void:
	comms_manager.channels.clear()
	comms_manager.participants.clear()
	comms_manager.sessions.clear()
	comms_manager.configure(realtime_process_manager, player_knowledge, player_network_position)
	comms_manager.add_participant(CommsParticipantScript.new(&"GUARD_1", "Loading Dock Guard", "GUARD 1", &"HALCYON_SECURITY"))
	comms_manager.add_participant(CommsParticipantScript.new(&"DISPATCH", "Security Dispatch", "DISPATCH", &"HALCYON_SECURITY"))
	comms_manager.add_participant(CommsParticipantScript.new(&"PLAYER", "Unknown Caller", "CALLER", &"PLAYER"))
	comms_manager.add_participant(CommsParticipantScript.new(&"FRONT_DESK_AGENT", "Front Desk", "FRONT DESK", &"HALCYON_PAYROLL"))
	comms_manager.add_participant(CommsParticipantScript.new(&"MAINTENANCE_DISPATCH", "Maintenance Dispatch", "MAINTENANCE", &"HALCYON_PAYROLL"))
	comms_manager.add_participant(CommsParticipantScript.new(&"WAREHOUSE_FOREMAN", "Warehouse Foreman", "WAREHOUSE", &"HALCYON_PAYROLL"))
	var channel = CommsChannelScript.new(&"GUARD_PHONE_CHANNEL", "Guard Phone Call", CommsChannelScript.ChannelType.PHONE_CALL, &"PBX_COMMS_INTERFACE")
	channel.participant_ids.assign([&"GUARD_1", &"DISPATCH"])
	channel.encryption_level = 1
	channel.intercept_requirement = &"DECRYPT_VOICE"
	channel.recording_allowed = true
	channel.story_tags.assign([&"SECURITY", &"EAST_STAIRWELL"])
	channel.set_access_policy(CommsAccessResult.Operation.MONITOR)
	channel.set_access_policy(CommsAccessResult.Operation.INTERCEPT, 0, &"DECRYPT_VOICE", &"", 2, false, 0.0)
	channel.set_access_policy(CommsAccessResult.Operation.RECORD)
	channel.set_access_policy(CommsAccessResult.Operation.INJECT, 0, &"PBX_ADMIN", &"VOICE_INJECTOR", 5, true, 0.65)
	comms_manager.add_channel(channel)
	var session = CommsSessionScript.new(&"GUARD_PHONE_CALL", channel.id, &"GUARD_PHONE_CALL")
	session.participants.assign(channel.participant_ids)
	session.duration = 95.0
	session.encryption_level = channel.encryption_level
	session.intercept_requirement = &""
	session.recording_allowed = channel.recording_allowed
	session.story_tags.assign(channel.story_tags)
	session.add_transcript_line(18.0, &"DISPATCH", "Report to the loading dock.", &"MENTION_LOADING_DOCK")
	session.add_transcript_line(26.0, &"GUARD_1", "Copy. I'm heading toward the loading dock now.", &"GUARD_HEADING_TO_LOADING_DOCK")
	session.add_transcript_line(38.0, &"DISPATCH", "Camera coverage is still live. Check every vehicle.")
	session.add_transcript_line(52.0, &"GUARD_1", "Approaching the dock entrance.")
	comms_manager.add_session(session)
	var radio = CommsChannelScript.new(&"SECURITY_RADIO_CHANNEL", "Security Radio", CommsChannelScript.ChannelType.SECURITY_RADIO, &"PBX_COMMS_INTERFACE")
	radio.participant_ids.assign([&"GUARD_1", &"DISPATCH"])
	radio.intercept_requirement = &"DECRYPT_VOICE"
	radio.story_tags.assign([&"SECURITY", &"RADIO"])
	radio.set_access_policy(CommsAccessResult.Operation.MONITOR)
	radio.set_access_policy(CommsAccessResult.Operation.INTERCEPT, 0, &"DECRYPT_VOICE")
	radio.set_access_policy(CommsAccessResult.Operation.RECORD)
	comms_manager.add_channel(radio)
	var radio_session = CommsSessionScript.new(&"SECURITY_RADIO", radio.id, &"SECURITY_RADIO")
	radio_session.participants.assign(radio.participant_ids)
	radio_session.duration = 180.0
	radio_session.add_transcript_line(35.0, &"DISPATCH", "Unit three, hold near service hall.", &"SERVICE_HALL_PATROL")
	comms_manager.add_session(radio_session)


func _create_debug_outbound_comms() -> void:
	outbound_comms_manager.targets.clear()
	outbound_comms_manager.story_hooks.clear()
	outbound_comms_manager.flags.clear()
	outbound_comms_manager.configure(realtime_process_manager, comms_manager, player_knowledge, player_network_position, realtime_world_clock)
	var target_specs: Array[Dictionary] = [
		{"id": &"FRONT_DESK", "type": OutboundActionScript.TargetType.CONTACT, "name": "Front Desk", "participant": &"FRONT_DESK_AGENT", "choices": [{"id": &"ASK_HOURS", "text": "What time does the office close?"}]},
		{"id": &"SECURITY", "type": OutboundActionScript.TargetType.SECURITY_DESK, "name": "Security Desk", "participant": &"DISPATCH", "choices": [{"id": &"SMOKE_REPORT", "text": "There's smoke on the third floor."}, {"id": &"SUPERVISOR_ORDER", "text": "Your supervisor wants you at the loading dock."}, {"id": &"NEVER_MIND", "text": "Never mind."}]},
		{"id": &"MAINTENANCE", "type": OutboundActionScript.TargetType.CONTACT, "name": "Maintenance", "participant": &"MAINTENANCE_DISPATCH", "choices": [{"id": &"REPORT_LEAK", "text": "There's a leak near the east stairwell."}]},
		{"id": &"WAREHOUSE", "type": OutboundActionScript.TargetType.INTERCOM, "name": "Warehouse", "participant": &"WAREHOUSE_FOREMAN", "choices": [{"id": &"CHECK_DELIVERY", "text": "Confirm the loading dock delivery."}]},
	]
	for spec: Dictionary in target_specs:
		var target = OutboundTargetScript.new(spec.id, spec.type, spec.name, &"PBX_COMMS_INTERFACE")
		target.participant_id = spec.participant
		target.conditions.append(ConditionScript.new(StringName("KNOW_%s" % spec.id), ConditionScript.ConditionType.KNOWS_ENDPOINT, &"PBX_COMMS_INTERFACE"))
		for choice: Dictionary in spec.choices:
			target.add_choice(choice.id, choice.text)
		outbound_comms_manager.add_target(target)
		for choice: Dictionary in spec.choices:
			_add_outbound_story_hook(target, choice)


func _add_outbound_story_hook(target: OutboundCommsTargetDefinition, choice: Dictionary) -> void:
	var hook = StoryHookScript.new(StringName("CALL_%s_%s" % [target.id, choice.id]), &"OUTBOUND_COMMS")
	hook.conditions.append(ConditionScript.new(&"ACTION_CALL", ConditionScript.ConditionType.ACTION_EQUALS, &"", OutboundActionScript.ActionType.CALL))
	hook.conditions.append(ConditionScript.new(&"TARGET", ConditionScript.ConditionType.TARGET_EQUALS, target.id))
	hook.conditions.append(ConditionScript.new(&"CHOICE", ConditionScript.ConditionType.CHOICE_EQUALS, choice.id))
	hook.add_response_line(0.5, target.participant_id, "This is %s." % target.display_name)
	match StringName(choice.id):
		&"SMOKE_REPORT":
			hook.add_response_line(3.0, &"DISPATCH", "Understood. Redirecting the third-floor patrol now.")
			hook.effects.append({"type": &"SET_FLAG", "key": &"SECURITY_DISTRACTED", "value": true})
		&"SUPERVISOR_ORDER":
			hook.add_response_line(3.0, &"DISPATCH", "Copy. Sending the nearest unit to the loading dock.")
			hook.effects.append({"type": &"SET_FLAG", "key": &"SECURITY_AT_LOADING_DOCK", "value": true})
		&"NEVER_MIND":
			hook.add_response_line(2.0, &"DISPATCH", "Then keep this line clear.")
		_:
			hook.add_response_line(3.0, target.participant_id, "Acknowledged. We'll check it now.")
	hook.story_tags.assign([&"OUTBOUND_COMMS", target.id])
	outbound_comms_manager.add_story_hook(hook)


func _create_debug_video_feeds() -> void:
	video_feed_manager.definitions.clear()
	video_feed_manager.sessions.clear()
	video_feed_manager.configure(realtime_process_manager, player_knowledge, player_network_position)
	var lobby = VideoFeedDefinitionScript.new(&"CAM_SERVICE_HALL", "Service Hall Camera", &"SERVICE_HALL", &"CAMERA_INTERFACE")
	lobby.camera_type = VideoFeedDefinitionScript.CameraType.FIXED
	lobby.recording = true
	lobby.player_access = true
	lobby.can_record = true
	lobby.can_replay = true
	lobby.story_tags.assign([&"LOBBY", &"SECURITY"])
	lobby.add_event(0.0, &"STATE", {"description": "LOBBY QUIET"})
	lobby.add_event(18.0, &"ENTER", {"entity_id": &"EMPLOYEE_07", "kind": &"PERSON", "position": Vector2(0.12, 0.58), "velocity": Vector2(0.012, 0.0), "description": "EMPLOYEE ENTERS LOBBY"})
	lobby.add_event(34.0, &"LEAVE", {"entity_id": &"EMPLOYEE_07", "description": "EMPLOYEE EXITS FRAME"})
	video_feed_manager.add_feed(lobby, &"CAM_SERVICE_HALL")

	var dock = VideoFeedDefinitionScript.new(&"CAM_LOADING_DOCK", "Loading Dock", &"LOADING_DOCK", &"CAMERA_INTERFACE")
	dock.camera_type = VideoFeedDefinitionScript.CameraType.LOW_LIGHT
	dock.recording = true
	dock.player_access = true
	dock.loop_or_script = VideoFeedDefinitionScript.PlaybackMode.SCRIPT
	dock.can_disable = true
	dock.can_record = true
	dock.can_replay = true
	dock.author_notes = "Vertical-slice loading dock feed; replace mock geometry only when an authored camera scene exists."
	dock.story_tags.assign([&"LOADING_DOCK", &"DELIVERY", &"PENETRATION_TEAM"])
	dock.spoof_profiles[&"ALL_CLEAR"] = {"available": true, "time": 0.0, "state": "ALL CLEAR // AUTHORED FALSE FEED", "entities": []}
	dock.add_event(0.0, &"STATE", {"description": "EMPTY DOCK"})
	dock.add_event(12.0, &"ENTER", {"entity_id": &"GUARD_1", "kind": &"PERSON", "position": Vector2(0.12, 0.58), "velocity": Vector2(0.008, 0.0), "description": "GUARD ENTERS"})
	dock.add_event(23.0, &"ENTER", {"entity_id": &"DELIVERY_TRUCK", "kind": &"VEHICLE", "position": Vector2(0.9, 0.61), "velocity": Vector2(-0.006, 0.0), "description": "DELIVERY TRUCK ARRIVES"})
	dock.add_event(41.0, &"LEAVE", {"entity_id": &"GUARD_1", "description": "GUARD LEAVES"})
	dock.add_event(54.0, &"ENTER", {"entity_id": &"ENTRY_TEAM_ALPHA", "kind": &"PERSON", "position": Vector2(0.08, 0.62), "velocity": Vector2(0.01, 0.0), "description": "PENETRATION TEAM ENTERS"})
	video_feed_manager.add_feed(dock, &"CAM_LOADING_DOCK")


func _create_debug_physical_alarms() -> void:
	physical_alarm_manager.definitions.clear()
	physical_alarm_manager.instances.clear()
	physical_alarm_manager.monitored_alarm_ids.clear()
	physical_alarm_manager.configure(realtime_process_manager, player_knowledge, player_network_position)
	var zone = PhysicalAlarmDefinitionScript.new(&"ALARM_ZONE_SERVER", "Server Room Alarm Zone", PhysicalAlarmDefinitionScript.AlarmType.MOTION_SENSOR, &"SERVER_ROOM", &"SERVER_ALARM_INTERFACE", &"ALARM_ZONE_SERVER")
	for command: PhysicalAlarmDefinition.Command in PhysicalAlarmDefinition.Command.values():
		zone.set_action_policy(command, 3 if command == PhysicalAlarmDefinitionScript.Command.BYPASS else 0)
	zone.story_tags.assign([&"SERVER_ROOM", &"PENETRATION_TEAM", &"SECURITY"])
	physical_alarm_manager.add_alarm(zone)


func _create_debug_physical_teams() -> void:
	var graph = LocationGraphScript.new()
	for location_id: StringName in [&"STREET", &"LOADING_DOCK", &"SERVICE_HALL", &"SECURITY_OFFICE", &"SERVER_ROOM", &"LAB"]:
		graph.add_location(location_id)
	graph.add_connection(&"STREET", &"LOADING_DOCK", 45.0)
	graph.add_connection(&"LOADING_DOCK", &"SERVICE_HALL", 15.0, true, &"DOOR_12")
	graph.add_connection(&"SERVICE_HALL", &"SECURITY_OFFICE", 10.0)
	graph.add_connection(&"LOADING_DOCK", &"SECURITY_OFFICE", 25.0)
	graph.add_connection(&"SERVICE_HALL", &"SERVER_ROOM", 12.0)
	graph.add_connection(&"SERVER_ROOM", &"LAB", 18.0)
	physical_team_knowledge = TeamKnowledgeScript.new()
	physical_team_manager.definitions.clear()
	physical_team_manager.instances.clear()
	physical_team_manager.configure(graph, realtime_process_manager, player_knowledge, physical_team_knowledge)

	var alpha_definition = TeamDefinitionScript.new(&"CONTRACT_TEAM", "Contracted Penetration Team", TeamDefinitionScript.TeamType.PLAYER_CONTRACTED, &"PLAYER_ALLY")
	alpha_definition.default_equipment.assign([&"BODY_CAMERA", &"TEAM_RADIO", &"BREACH_KIT"])
	alpha_definition.members.append(TeamMemberScript.new(&"ALPHA_LEAD", "Morgan Vale", &"TEAM_LEAD"))
	alpha_definition.members.append(TeamMemberScript.new(&"ALPHA_TECH", "Iris Chen", &"TECHNICIAN"))
	var alpha = TeamInstanceScript.new(&"TEAM_ALPHA", alpha_definition, &"STREET", &"TEAM_ALPHA_PROCESS")
	alpha.comms_channel = &"TEAM_ALPHA_RADIO"
	alpha.start_time = realtime_world_clock.elapsed_seconds
	physical_team_manager.add_team(alpha)
	physical_team_manager.assign_route(alpha.id, [&"STREET", &"LOADING_DOCK", &"SERVICE_HALL", &"SERVER_ROOM"] as Array[StringName], &"REACH_SERVER_ROOM")
	physical_team_manager.observe_team(alpha.id, PhysicalTeamKnowledge.Source.VERBAL_REPORT, realtime_world_clock.elapsed_seconds)



func _create_team_support_encounter() -> void:
	var door_definition = AccessPointDefinitionScript.new(&"DOOR_12", "Service Hall Door 12", &"LOADING_DOCK", FacilityOperationFactory.ACCESS_CONTROL, &"DOOR_CONTROL_DAEMON")
	door_definition.initially_locked = true
	door_definition.force_entry_seconds = 8.0
	door_definition.force_entry_suspicion = 35
	door_definition.story_tags.assign([&"TEAM_SUPPORT", &"SERVICE_HALL"])
	team_support_encounter.configure(&"TEAM_ALPHA", AccessPointInstanceScript.new(door_definition), physical_team_manager)


func _create_shared_equipment_economy() -> void:
	equipment_order_manager.equipment_catalog.clear()
	equipment_order_manager.vendors.clear()
	equipment_order_manager.orders.clear()
	equipment_order_manager.story_hooks.clear()
	equipment_order_manager.available_equipment.clear()
	equipment_order_manager.messages.clear()
	equipment_order_manager.credits = 1000
	equipment_order_manager.configure(realtime_process_manager, realtime_world_clock)
	var specs: Array[Dictionary] = [
		{"id": &"SIGNAL_COPROCESSOR", "name": "Signal Coprocessor", "type": EquipmentDefinitionScript.EquipmentType.CYBERDECK_MODULE, "cost": 180},
		{"id": &"FOLDED_ANTENNA", "name": "Folded Spectrum Antenna", "type": EquipmentDefinitionScript.EquipmentType.ANTENNA, "cost": 90},
		{"id": &"FIELD_RADIO", "name": "Encrypted Field Radio", "type": EquipmentDefinitionScript.EquipmentType.RADIO, "cost": 120},
		{"id": &"CAMERA_TAP", "name": "Optical Camera Tap", "type": EquipmentDefinitionScript.EquipmentType.CAMERA_TAP, "cost": 140},
		{"id": &"PROTOCOL_ADAPTER", "name": "Legacy Network Adapter", "type": EquipmentDefinitionScript.EquipmentType.NETWORK_ADAPTER, "cost": 110},
		{"id": &"COLD_STORAGE", "name": "Cold Storage Module", "type": EquipmentDefinitionScript.EquipmentType.STORAGE_MODULE, "cost": 160},
		{"id": &"COMPUTE_BRICK", "name": "Portable Compute Module", "type": EquipmentDefinitionScript.EquipmentType.COMPUTE_MODULE, "cost": 220},
		{"id": &"ACCESS_SHIM", "name": "Physical Access Shim", "type": EquipmentDefinitionScript.EquipmentType.PHYSICAL_ACCESS_DEVICE, "cost": 200},
	]
	for spec: Dictionary in specs:
		var equipment = EquipmentDefinitionScript.new(spec.id, spec.name, spec.type, spec.cost)
		equipment.story_tags.assign([&"FICTIONAL_EQUIPMENT", spec.id])
		if spec.id == &"CAMERA_TAP":
			equipment.delivery_story_hook_id = &"CAMERA_TAP_DELIVERED"
		equipment_order_manager.add_equipment(equipment)
	var rapid = VendorDefinitionScript.new(&"VECTOR_RAPID", "Vector Rapid Supply", 30.0)
	rapid.inventory.assign([&"FIELD_RADIO", &"CAMERA_TAP", &"ACCESS_SHIM"])
	rapid.price_multiplier = 1.2
	rapid.delivery_destinations.assign([&"SAFEHOUSE_DROP", &"PUBLIC_LOCKER"])
	rapid.story_tags.assign([&"FAST_DELIVERY"])
	equipment_order_manager.add_vendor(rapid)
	var standard = VendorDefinitionScript.new(&"GRAYLINE_LOGISTICS", "Grayline Logistics", 120.0)
	standard.inventory.assign(equipment_order_manager.equipment_catalog.keys())
	standard.delivery_destinations.assign([&"SAFEHOUSE_DROP", &"PUBLIC_LOCKER"])
	standard.story_tags.assign([&"STANDARD_DELIVERY"])
	equipment_order_manager.add_vendor(standard)
	var covert = VendorDefinitionScript.new(&"NIGHT_MARKET_RELAY", "Night Market Relay", 300.0)
	covert.inventory.assign([&"SIGNAL_COPROCESSOR", &"FOLDED_ANTENNA", &"PROTOCOL_ADAPTER", &"COMPUTE_BRICK"])
	covert.price_multiplier = 0.85
	covert.delivery_destinations.assign([&"DEAD_DROP_7"])
	covert.story_tags.assign([&"COVERT_DELIVERY"])
	equipment_order_manager.add_vendor(covert)
	var delivery_hook = StoryHookScript.new(&"CAMERA_TAP_DELIVERED", &"EQUIPMENT_DELIVERED")
	delivery_hook.story_tags.assign([&"EQUIPMENT", &"CAMERA_SUPPORT"])
	delivery_hook.effects.append({"type": &"UNLOCK_INTERACTION", "interaction_id": &"INSTALL_CAMERA_TAP"})
	equipment_order_manager.add_story_hook(delivery_hook)


func _create_debug_realtime_timeline() -> void:
	realtime_event_scheduler.definitions.clear()
	realtime_event_scheduler.instances.clear()
	realtime_event_scheduler.operation_start_times.clear()
	realtime_event_scheduler.action_handlers.clear()
	realtime_event_log.clear()
	realtime_event_scheduler.configure(realtime_world_clock, realtime_process_manager)
	for action_type: RealtimeEventDefinition.ActionType in RealtimeEventDefinition.ActionType.values():
		realtime_event_scheduler.register_action_handler(action_type, _handle_realtime_timeline_action.bind(action_type))
	var specs: Array[Dictionary] = [
		{"id": &"GUARD_CALLS_DISPATCH", "name": "Guard calls dispatch", "delay": 10.0, "action": RealtimeEventDefinitionScript.ActionType.START_COMMS, "payload": {"session_id": &"SECURITY_CALL_SESSION_01"}},
		{"id": &"TEAM_REACHES_LOADING", "name": "Team reaches loading dock", "delay": 25.0, "action": RealtimeEventDefinitionScript.ActionType.SET_STORY_FLAG, "payload": {"flag": &"TEAM_LOADING_DOCK_MILESTONE", "value": true}},
		{"id": &"DELIVERY_WINDOW", "name": "Delivery arrives", "delay": 40.0, "action": RealtimeEventDefinitionScript.ActionType.SET_STORY_FLAG, "payload": {"flag": &"DELIVERY_WINDOW_OPEN", "value": true}},
		{"id": &"ALARM_ESCALATION", "name": "Alarm escalates", "delay": 55.0, "action": RealtimeEventDefinitionScript.ActionType.CHANGE_ALARM, "payload": {"alarm_id": &"BUILDING_FIRE_ALARM", "command": PhysicalAlarmDefinition.Command.TRIGGER}},
		{"id": &"SECURITY_ENTERS", "name": "Security team enters facility", "delay": 70.0, "action": RealtimeEventDefinitionScript.ActionType.MOVE_TEAM, "payload": {"team_id": &"SECURITY_TEAM_BRAVO", "state": PhysicalTeamInstance.State.SEARCHING, "status": "ENTERED FACILITY"}},
	]
	for spec: Dictionary in specs:
		var definition = RealtimeEventDefinitionScript.new(spec.id, spec.name, RealtimeEventDefinitionScript.TriggerType.AFTER_SECONDS, spec.delay)
		definition.add_action(spec.action, spec.payload)
		definition.story_tags.assign([&"DEBUG_TIMELINE", spec.id])
		realtime_event_scheduler.add_definition(definition)
		realtime_event_scheduler.schedule(definition.id)
	var operation_event = RealtimeEventDefinitionScript.new(&"OPERATION_CHECKIN", "Operation-relative check-in", RealtimeEventDefinitionScript.TriggerType.RELATIVE_OPERATION_TIME, 15.0)
	operation_event.operation_id = &"TEAM_ALPHA_OPERATION"
	operation_event.add_action(RealtimeEventDefinitionScript.ActionType.SET_STORY_FLAG, {"flag": &"ALPHA_CHECKIN_DUE", "value": true})
	realtime_event_scheduler.add_definition(operation_event)
	realtime_event_scheduler.schedule(operation_event.id)
	realtime_event_scheduler.register_operation_start(&"TEAM_ALPHA_OPERATION", realtime_world_clock.elapsed_seconds)
	var process_event = RealtimeEventDefinitionScript.new(&"ALPHA_PROCESS_COMPLETE", "Team process completed", RealtimeEventDefinitionScript.TriggerType.PROCESS_STATE_CHANGED)
	process_event.process_id = &"ENTRY_TEAM_ALPHA"
	process_event.expected_process_state = RealtimeProcess.State.COMPLETED
	process_event.add_action(RealtimeEventDefinitionScript.ActionType.ACTIVATE_HOOK, {"hook_id": &"TEAM_OPERATION_TIMEOUT"})
	realtime_event_scheduler.add_definition(process_event)
	realtime_event_scheduler.schedule(process_event.id)


func _handle_realtime_timeline_action(payload: Dictionary, instance: RealtimeEventInstance, action_type: RealtimeEventDefinition.ActionType) -> void:
	realtime_event_log.append({"event_id": instance.definition.id, "action_type": action_type, "payload": payload.duplicate(true), "realtime": realtime_world_clock.elapsed_seconds})
	match action_type:
		RealtimeEventDefinition.ActionType.CHANGE_ALARM:
			var alarm: PhysicalAlarmInstance = physical_alarm_manager.instances.get(payload.get("alarm_id", &""))
			if alarm != null:
				alarm.apply_command(int(payload.get("command", PhysicalAlarmDefinition.Command.TRIGGER)))
		RealtimeEventDefinition.ActionType.MOVE_TEAM:
			var team: PhysicalTeamInstance = physical_team_manager.instances.get(payload.get("team_id", &""))
			if team != null and payload.has("state"):
				team.set_operational_state(int(payload.state), String(payload.get("status", "TIMELINE UPDATE")))
		RealtimeEventDefinition.ActionType.SET_STORY_FLAG:
			outbound_comms_manager.flags[payload.get("flag", &"")] = payload.get("value", true)
		RealtimeEventDefinition.ActionType.CHANGE_PHYSICAL_STATE:
			if payload.get("access_point_id", &"") == &"DOOR_12" and payload.get("state", &"") == &"UNLOCKED":
				team_support_encounter.access_point.unlock(&"REALTIME_EVENT")


func _create_debug_operation_pressure() -> void:
	operation_pressure_manager.operations.clear()
	operation_pressure_manager.configure(action_clock, realtime_world_clock)
	var operation = OperationPressureDefinitionScript.new(&"SUPPORT_TEAM_ALPHA", "PREPARE LOADING DOCK BEFORE TEAM ARRIVAL")
	operation.realtime_threat_label = "TEAM_ALPHA REACHES LOADING_DOCK"
	operation.realtime_deadline_seconds = 45.0
	operation.story_tags.assign([&"DEBUG", &"DUAL_PRESSURE", &"SERVER_ROOM"])
	operation.add_cyber_step("REACH CAMERA_SERVER", ActionRequest.ActionType.MOVE, &"CAMERA_SERVER", 2)
	operation.add_cyber_step("SCAN CAMERA CONTROL", ActionRequest.ActionType.SCAN, &"CAMERA_SERVER", 2)
	operation.add_cyber_step("COMPROMISE CAMERA CONTROL", ActionRequest.ActionType.EXPLOIT, &"CAMERA_CONTROL", 3)
	operation.add_cyber_step("LOOP LOADING DOCK CAMERA", ActionRequest.ActionType.USE_PROGRAM, &"CAM_LOADING_DOCK", 3)
	operation_pressure_manager.begin(operation)


func _create_debug_realtime_story() -> void:
	realtime_story_router.reset()
	story_action_log.clear()
	story_messages.clear()
	story_graffiti.clear()
	for action_type: StringName in [&"REVEAL_NODE", &"ADD_GRAFFITI", &"SEND_MESSAGE"]:
		realtime_story_router.register_action_handler(action_type, _handle_realtime_story_action)
	var hook = StoryHookScript.new(&"THE_INSIDE_MAN", &"HEARD_COMMS_EVENT")
	hook.conditions.append(ConditionScript.new(&"CALL_INTERCEPTED", ConditionScript.ConditionType.STORY_EVENT_OCCURRED, &"COMMS_INTERCEPTED", {"source_id": &"GUARD_PHONE_CALL"}))
	hook.conditions.append(ConditionScript.new(&"LOADING_DOCK_HEARD", ConditionScript.ConditionType.STORY_EVENT_OCCURRED, &"HEARD_COMMS_EVENT", {"source_id": &"GUARD_PHONE_CALL", "payload": {"comms_event_id": &"MENTION_LOADING_DOCK"}}))
	hook.effects.append({"type": &"REVEAL_NODE", "node_id": &"CONTRACTOR_VPN"})
	hook.effects.append({"type": &"ADD_GRAFFITI", "location_id": &"PUBLIC_GATEWAY", "text": "THE INSIDE MAN LEFT A ROUTE"})
	hook.effects.append({"type": &"SEND_MESSAGE", "sender_id": &"INSIDE_MAN", "text": "Contractor access exposed. Check the loading dock traffic."})
	hook.story_tags.assign([&"INSIDE_MAN", &"LOADING_DOCK", &"SECURITY_COMMS"])
	realtime_story_router.add_hook(hook)


func _handle_realtime_story_action(action: Dictionary, _hook: StoryHook, _event: StoryEvent) -> void:
	story_action_log.append(action.duplicate(true))
	match StringName(action.get("type", &"")):
		&"REVEAL_NODE":
			var node := network_graph.get_node(action.get("node_id", &""))
			if node != null:
				player_knowledge.reveal_node(node, KnowledgeLevel.Value.IDENTIFIED)
		&"ADD_GRAFFITI":
			story_graffiti.append(action.duplicate(true))
		&"SEND_MESSAGE":
			story_messages.append(action.duplicate(true))


func _create_facility_scenario() -> void:
	facility_scenario = FacilityOperationScenario.new()
	facility_scenario.name = "FacilityOperationScenario"
	add_child(facility_scenario)
	facility_scenario.configure(physical_team_manager, video_feed_manager, physical_alarm_manager, team_support_encounter, realtime_story_router, realtime_world_clock, action_clock)

func request_traversal(destination_node_id: StringName) -> ActionResult:
	if not session_active or network_graph == null or player_network_position == null:
		return ActionResult.new(false, 0, "No active network session.")
	var link := network_graph.find_link(player_network_position.current_node_id, destination_node_id)
	var cost := link.traversal_cost if link != null else 0
	return request_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.MOVE, destination_node_id, cost))

func request_action(request: ActionRequest) -> ActionResult:
	if not session_active or action_clock == null:
		return ActionResult.new(false, 0, "No active simulation clock.")
	if intrusion_session == null or intrusion_session.lifecycle != IntrusionSession.Lifecycle.ACTIVE or game_domain != GameDomain.CYBERSPACE:
		return ActionResult.new(false, 0, "Cyberspace intrusion is not active.")
	if not PausePolicy.allows_cyberspace_actions():
		return ActionResult.new(false, 0, "Cyberspace actions are frozen during %s." % PausePolicy.mode_label())
	var result := action_clock.resolve_action(request, _validate_action, _apply_action)
	if operation_pressure_manager != null:
		operation_pressure_manager.record_cyber_action(request, result)
	return result


func record_alarm_log(alarm_id: StringName) -> EvidenceRecord:
	if evidence_archive == null or physical_alarm_manager == null:
		return null
	var instance: PhysicalAlarmInstance = physical_alarm_manager.instances.get(alarm_id)
	if instance == null or not player_knowledge.knows_realtime_process(instance.definition.realtime_process_id):
		return null
	return evidence_archive.begin_recording(EvidenceRecord.SourceType.ALARM_LOG, alarm_id, {"alarm_type": instance.definition.alarm_type, "physical_location_id": instance.definition.physical_location_id}, instance.definition.story_tags, func() -> Array[Dictionary]: return instance.event_history)


func record_team_telemetry(team_id: StringName) -> EvidenceRecord:
	if evidence_archive == null or physical_team_manager == null:
		return null
	var team: PhysicalTeamInstance = physical_team_manager.instances.get(team_id)
	if team == null or not player_knowledge.knows_realtime_process(team.realtime_process_id):
		return null
	var tags: Array[StringName] = team.team_definition.story_tags if team.team_definition != null else []
	return evidence_archive.begin_recording(EvidenceRecord.SourceType.TEAM_TELEMETRY, team_id, {"team_definition_id": team.team_definition.id if team.team_definition != null else &"", "objective": team.objective}, tags, func() -> Array[Dictionary]: return team.telemetry_history)


func analyze_evidence(record_id: StringName) -> Dictionary:
	if evidence_archive == null:
		return {"success": false, "reason": "Evidence archive unavailable.", "matches": []}
	var rules: Array[Dictionary] = [
		{"phrase": "east stairwell", "story_hook_id": &"EAST_STAIRWELL_INTEL", "story_tags": [&"SECURITY_ROUTE", &"GUARD_PATROL"]},
		{"phrase": "loading dock", "story_hook_id": &"LOADING_DOCK_INTEL", "story_tags": [&"PHYSICAL_ROUTE"]},
	]
	return evidence_archive.analyze(record_id, rules)

func request_scan(target: Dictionary, scanner_power := 1) -> ActionResult:
	if scan_system == null:
		return ActionResult.new(false, 0, "No active scan system.")
	var cost := scan_system.get_action_cost(target)
	return request_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.SCAN, target.duplicate(true), cost, {"scanner_program": &"BASIC_SCANNER", "scanner_power": scanner_power}))

func request_confrontation(action_type: ActionRequest.ActionType, target: Dictionary) -> ActionResult:
	if confrontation_controller == null or not confrontation_controller.has_action(action_type):
		return ActionResult.new(false, 0, "Unknown confrontation action.")
	var cost := confrontation_controller.get_action_cost(action_type, target)
	return request_action(ActionRequest.new(&"PLAYER", action_type, target.duplicate(true), cost, {"system": &"CONFRONTATION"}))

func request_video_feed_action(feed_id: StringName, command: VideoFeedActionDefinition.Command) -> ActionResult:
	if video_feed_manager == null:
		return ActionResult.new(false, 0, "Video feed system is unavailable.")
	var definition: VideoFeedActionDefinition = video_feed_manager.get_action_definition(command)
	if definition == null:
		return ActionResult.new(false, 0, "Unknown video feed command.")
	return request_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.USE_PROGRAM, {"feed_id": feed_id, "command": command}, definition.cyber_cost, {"system": &"VIDEO_FEED"}))


func set_modal_action_selection_unresolved(unresolved: bool) -> void:
	unresolved_modal_action_selection = unresolved


func set_jack_out_prohibited(prohibited: bool) -> void:
	jack_out_prohibited = prohibited


func request_doorstop_deployment(program_instance_id: StringName) -> ActionResult:
	var result := request_action(ActionRequest.new(
		&"PLAYER",
		ActionRequest.ActionType.USE_PROGRAM,
		{"program_instance_id": program_instance_id},
		1,
		{"system": &"DOORSTOP"}
	))
	if not result.success:
		notify_doorstop_invalid(result.reason)
	return result


func notify_doorstop_invalid(reason: String) -> void:
	_emit_doorstop_feedback(&"INVALID", "DOORSTOP UNAVAILABLE", reason)


func _on_program_instance_added(instance: ProgramInstance) -> void:
	if instance == null or not instance.definition is DoorstopDefinition:
		return
	var help := ""
	if not doorstop_acquisition_help_shown:
		doorstop_acquisition_help_shown = true
		help = "DOORSTOP is a disposable emergency backdoor. Install a specific copy in your deck, deploy it at a network node, then burn that copy to hold one temporary return route. Existing trace and network consequences remain."
	_emit_doorstop_feedback(&"ACQUIRED", "DOORSTOP ACQUIRED", "%s %s // Disposable Backdoor Utility" % [instance.definition.display_name, instance.definition.version], help)


func _emit_doorstop_feedback(kind: StringName, title: String, message: String, help_text: String = "") -> void:
	EventBus.doorstop_feedback.emit({"kind": kind, "title": title, "message": message, "help_text": help_text})


func installed_doorstop_instance_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if program_loadout == null or program_inventory == null:
		return result
	for instance_id: StringName in program_loadout.installed_instance_ids:
		var instance := program_inventory.get_instance(instance_id)
		if instance != null and instance.definition is DoorstopDefinition:
			result.append(instance_id)
	return result


func _doorstop_deployment_context() -> Dictionary:
	var node_id := player_network_position.current_node_id if player_network_position != null else &""
	return {
		"node_id": node_id,
		"node_is_valid": network_graph != null and network_graph.get_node(node_id) != null,
		"node_transition_unresolved": player_network_position == null or player_network_position.is_transitioning,
		"modal_action_unresolved": unresolved_modal_action_selection,
		"jack_out_prohibited": jack_out_prohibited,
	}


func jack_out_through_doorstop() -> Dictionary:
	if not session_active or intrusion_session == null:
		return {"success": false, "reason": "No active intrusion."}
	if intrusion_session.lifecycle != IntrusionSession.Lifecycle.ACTIVE:
		return {"success": false, "reason": "Intrusion is not active."}
	if player_network_position == null or player_network_position.is_transitioning:
		return {"success": false, "reason": "Cannot Jack Out during a node transition."}
	if unresolved_modal_action_selection:
		return {"success": false, "reason": "Resolve the current modal or action selection first."}
	if jack_out_prohibited:
		return {"success": false, "reason": "This encounter prohibits Jack Out."}
	var anchor := doorstop_controller.get_anchor(intrusion_run_id) if doorstop_controller != null else null
	if anchor == null or not anchor.active:
		return {"success": false, "reason": "No active Doorstop return point exists."}
	var previous_lifecycle: int = intrusion_session.lifecycle
	var state := _capture_intrusion_resume_state(anchor)
	var realtime_marker: float = float(realtime_world_clock.elapsed_seconds) if realtime_world_clock != null else 0.0
	var suspension: Dictionary = intrusion_session.suspend_at_doorstop(anchor, realtime_marker, state)
	if not suspension.success:
		return suspension
	EventBus.intrusion_lifecycle_changed.emit(intrusion_run_id, previous_lifecycle, intrusion_session.lifecycle)
	var meatspace_result := enter_meatspace(MeatspaceAutosaveServiceScript.Reason.DOORSTOP_EXIT, {&"intrusion_id": intrusion_run_id, &"return_node_id": anchor.cyberspace_node_id})
	_emit_doorstop_feedback(&"SUSPENDED", "CONNECTION SUSPENDED", "Backdoor remains open.\nReturn node: %s" % anchor.cyberspace_node_id)
	return {
		"success": true,
		"reason": "Intrusion suspended. Doorstop return route remains active." if meatspace_result.save_error == OK else "Intrusion suspended, but autosave failed.",
		"lifecycle": intrusion_session.lifecycle,
		"domain": game_domain,
		"anchor": anchor,
		"save_error": meatspace_result.save_error,
	}


func advance_suspended_security_time(seconds: float) -> bool:
	return advance_suspended_intrusion(seconds).get("success", false)


func configure_doorstop_suspension_policy(policy: DoorstopSuspensionPolicy, replacement_ice_factory: Callable = Callable(), node_process_advancer: Callable = Callable()) -> bool:
	if policy == null:
		return false
	doorstop_suspension_policy = policy
	suspended_replacement_ice_factory = replacement_ice_factory
	suspended_node_process_advancer = node_process_advancer
	return true


func advance_suspended_intrusion(elapsed_seconds: float = -1.0) -> Dictionary:
	if intrusion_session == null or suspended_intrusion_advancer == null:
		return {"success": false, "reason": "No suspended intrusion service is available."}
	var elapsed := elapsed_seconds
	if elapsed < 0.0:
		var now: float = float(realtime_world_clock.elapsed_seconds) if realtime_world_clock != null else intrusion_session.suspension_advanced_through
		elapsed = maxf(0.0, now - intrusion_session.suspension_advanced_through)
	var result := suspended_intrusion_advancer.advance_suspended_intrusion(intrusion_session, doorstop_suspension_policy, elapsed, {
		"trace": trace_level,
		"alarm_manager": physical_alarm_manager,
		"ice_controller": ice_controller,
		"security_level": suspended_security_level,
		"temporary_effects": temporary_cyberspace_effects,
		"spawn_replacement_ice": suspended_replacement_ice_factory,
		"advance_node_processes": Callable(self, "_advance_suspended_node_processes"),
	})
	if result.success:
		trace_level = int(result.trace)
		suspended_security_level = int(result.security_level)
		temporary_cyberspace_effects.assign(result.temporary_effects)
		suspended_intrusion_events.append_array(result.events)
		intrusion_session.suspension_advanced_through += elapsed
	return result


func _spawn_suspended_replacement_ice(_index: int) -> void:
	if suspended_replacement_ice_factory.is_valid():
		suspended_replacement_ice_factory.call(_index)


func _advance_suspended_node_processes(seconds: float, node_id: StringName) -> void:
	if suspended_node_process_advancer.is_valid():
		suspended_node_process_advancer.call(seconds, node_id)
	suspended_intrusion_events.append({"type": &"NODE_LOCAL_PROCESS_TIME", "seconds": seconds, "node_id": node_id})


func suspended_doorstop_view() -> Dictionary:
	if intrusion_session == null or not intrusion_session.can_resume_through_doorstop():
		return {}
	var anchor := intrusion_session.suspended_anchor
	return {
		"intrusion_run_id": intrusion_run_id,
		"target_name": "HERMES INTERNAL NETWORK",
		"return_node_id": anchor.cyberspace_node_id,
		"deployed_at": anchor.deployment_marker,
		"suspended_at": intrusion_session.suspended_at_realtime,
	}


func jack_back_in_through_doorstop() -> Dictionary:
	if intrusion_session == null or game_domain != GameDomain.MEATSPACE:
		return {"success": false, "reason": "No suspended Doorstop intrusion is available."}
	if intrusion_session.lifecycle != IntrusionSession.Lifecycle.SUSPENDED_AT_DOORSTOP:
		return {"success": false, "reason": "Intrusion is not suspended at Doorstop."}
	var session_anchor := intrusion_session.suspended_anchor
	var controller_anchor := doorstop_controller.get_anchor(intrusion_run_id) if doorstop_controller != null else null
	if session_anchor == null or not session_anchor.active or controller_anchor != session_anchor:
		return {"success": false, "reason": "Doorstop return route is missing or no longer belongs to this intrusion."}
	if session_anchor.intrusion_run_id != intrusion_run_id:
		return {"success": false, "reason": "Doorstop belongs to a different intrusion."}
	if session_anchor.cyberspace_node_id != intrusion_session.resume_state.get("doorstop_node_id", &""):
		return {"success": false, "reason": "Doorstop return node does not match the suspended intrusion."}
	var consequence_result := advance_suspended_intrusion()
	if not consequence_result.success:
		return consequence_result
	var previous_lifecycle: int = intrusion_session.lifecycle
	var current_loadout: Array[StringName] = program_loadout.installed_instance_ids.duplicate()
	var resume: Dictionary = intrusion_session.resume_through_doorstop(session_anchor, current_loadout)
	if not resume.success:
		return resume
	var return_node_id: StringName = resume.node_id
	if network_graph == null or network_graph.get_node(return_node_id) == null:
		intrusion_session.lifecycle = previous_lifecycle
		return {"success": false, "reason": "Doorstop return node is no longer valid."}
	# The anchor is authoritative; callers cannot supply or select a destination.
	player_network_position.relocate(return_node_id)
	if not doorstop_controller.complete_return(intrusion_run_id, true):
		intrusion_session.lifecycle = previous_lifecycle
		return {"success": false, "reason": "Doorstop return route could not be consumed."}
	intrusion_session.clear_consumed_return_route()
	var previous_domain: int = game_domain
	game_domain = GameDomain.CYBERSPACE
	EventBus.intrusion_lifecycle_changed.emit(intrusion_run_id, previous_lifecycle, intrusion_session.lifecycle)
	EventBus.game_domain_changed.emit(previous_domain, game_domain)
	EventBus.network_display_update_requested.emit()
	_emit_doorstop_feedback(&"REENTRY", "BACKDOOR RE-ENTRY", "Intrusion restored at %s." % return_node_id)
	_emit_doorstop_feedback(&"CLOSED", "DOORSTOP CLOSED", "Temporary route destroyed. Deploy another Doorstop to create a new emergency exit.")
	return {"success": true, "reason": "Intrusion resumed at Doorstop.", "node_id": return_node_id}


func _capture_intrusion_resume_state(anchor: DoorstopAnchor) -> Dictionary:
	var ice_state: Dictionary = {}
	if ice_controller != null:
		for ice_id in ice_controller.instances:
			var ice: IceInstance = ice_controller.instances[ice_id]
			ice_state[ice_id] = {
				"current_node_id": ice.current_node_id,
				"target_node_id": ice.target_node_id,
				"state": ice.state,
				"alert_level": ice.alert_level,
				"known_player_position": ice.known_player_position,
				"last_known_player_position": ice.last_known_player_position,
			}
	var link_state: Dictionary = {}
	for link_id in network_graph.links:
		var link: NetworkLinkDefinition = network_graph.links[link_id]
		link_state[link_id] = {"locked": link.locked, "disabled": link.disabled, "hidden": link.hidden, "discovered": link.discovered, "traversal_cost": link.traversal_cost}
	var alarm_state: Dictionary = {}
	if physical_alarm_manager != null:
		for alarm_id in physical_alarm_manager.instances:
			var alarm: PhysicalAlarmInstance = physical_alarm_manager.instances[alarm_id]
			alarm_state[alarm_id] = {
				"state": alarm.state,
				"detection_enabled": alarm.detection_enabled,
				"alert_presenting": alarm.alert_presenting,
				"underlying_condition_active": alarm.underlying_condition_active,
			}
	return {
		"intrusion_run_id": intrusion_run_id,
		"doorstop_node_id": anchor.cyberspace_node_id,
		"current_node_id": player_network_position.current_node_id,
		"previous_node_id": player_network_position.previous_node_id,
		"cyber_tick": action_clock.current_tick,
		"trace": trace_level,
		"player_knowledge": {
			"nodes": player_knowledge.node_records.duplicate(true),
			"links": player_knowledge.link_records.duplicate(true),
			"spheres": player_knowledge.sphere_records.duplicate(true),
			"dynamic_nodes": player_knowledge.dynamic_node_observations.duplicate(true),
			"dynamic_links": player_knowledge.dynamic_link_observations.duplicate(true),
			"observation_tick": player_knowledge.current_observation_tick,
			"services": player_knowledge.service_records.duplicate(true),
			"ice": player_knowledge.ice_records.duplicate(true),
			"hackers": player_knowledge.hacker_records.duplicate(true),
			"realtime_endpoints": player_knowledge.realtime_endpoint_records.duplicate(true),
			"realtime_processes": player_knowledge.realtime_process_records.duplicate(true),
		},
		"network_links": link_state,
		"story_flags": outbound_comms_manager.flags.duplicate(true) if outbound_comms_manager != null else {},
		"story_router_flags": realtime_story_router.flags.duplicate(true) if realtime_story_router != null else {},
		"volatile_resources": resource_state.volatile_resources.duplicate(true),
		"stored_resources": resource_state.stored_resources.duplicate(true),
		"mission_complete": mission.mission_complete if mission != null else false,
		"exploited_services": mission.exploited_services.duplicate() if mission != null else [],
		"ice": ice_state,
		"alarms": alarm_state,
	}

func _bind_network_events() -> void:
	network_graph.traversal_started.connect(EventBus.network_traversal_started.emit)
	network_graph.traversal_completed.connect(EventBus.network_position_changed.emit)
	network_graph.display_update_requested.connect(EventBus.network_display_update_requested.emit)
	network_graph.security_sleeve_changed.connect(EventBus.security_sleeve_changed.emit)
	action_clock.tick_advanced.connect(EventBus.simulation_tick_advanced.emit)
	action_clock.tick_advanced.connect(_on_knowledge_tick_advanced)
	action_clock.tick_advanced.connect(_on_trail_tick_advanced)
	action_clock.tick_advanced.connect(func(_previous: int, _current: int, amount: int) -> void: EventBus.network_time_advanced.emit(amount))
	action_clock.action_resolved.connect(EventBus.action_resolved.emit)
	action_clock.action_resolved.connect(_on_action_resolved_team_support)
	action_clock.action_resolved.connect(hacker_npc_manager.handle_player_action)

func _on_san_relocated(san: RefCounted, previous_node_id: StringName, current_node_id: StringName) -> void:
	EventBus.network_display_update_requested.emit()
	EventBus.san_relocated.emit(san.id, previous_node_id, current_node_id)

func _on_trail_tick_advanced(_previous_tick: int, current_tick: int, _amount: int) -> void:
	if trail_system != null: trail_system.decay_trails(current_tick)

func _on_knowledge_tick_advanced(_previous_tick: int, current_tick: int, _amount: int) -> void:
	if player_knowledge != null: player_knowledge.advance_knowledge_time(current_tick)


func _on_action_resolved_team_support(_request: ActionRequest, result: ActionResult) -> void:
	if not result.success or team_support_encounter == null:
		return
	for event: Dictionary in result.events_produced:
		if event.get("type", &"") == &"SERVICE_COMPROMISED":
			team_support_encounter.unlock_from_cyberspace(event.get("service_id", &""))

func _validate_action(request: ActionRequest) -> Dictionary:
	if confrontation_controller != null and confrontation_controller.has_action(request.action_type):
		if not request.target is Dictionary:
			return {"success": false, "reason": "Confrontation target is malformed.", "events": []}
		var confrontation_validation := confrontation_controller.validate(request.action_type, request.target)
		if not confrontation_validation.success:
			return {"success": false, "reason": confrontation_validation.reason, "events": []}
		if request.cost != confrontation_controller.get_action_cost(request.action_type, request.target):
			return {"success": false, "reason": "Confrontation cost mismatch.", "events": []}
		return {"success": true, "reason": "", "events": []}
	match request.action_type:
		ActionRequest.ActionType.USE_PROGRAM:
			if not request.target is Dictionary:
				return {"success": false, "reason": "Program action is malformed.", "events": []}
			if request.metadata.get("system", &"") == &"DOORSTOP":
				if doorstop_controller == null or request.cost != 1:
					return {"success": false, "reason": "Doorstop deployment is unavailable.", "events": []}
				var doorstop_validation: Dictionary = doorstop_controller.validate_deployment(
					request.target.get("program_instance_id", &""), intrusion_run_id,
					player_network_position.current_node_id if player_network_position != null else &"",
					_doorstop_deployment_context()
				)
				return {"success": doorstop_validation.success, "reason": doorstop_validation.reason, "events": []}
			if request.metadata.get("system", &"") != &"VIDEO_FEED":
				return {"success": false, "reason": "Unknown program action.", "events": []}
			var command: VideoFeedActionDefinition.Command = int(request.target.get("command", -1))
			var video_validation: VideoFeedActionResult = video_feed_manager.validate_action(request.target.get("feed_id", &""), command)
			if not video_validation.success:
				return {"success": false, "reason": video_validation.reason, "events": []}
			if request.cost != video_validation.cyber_cost:
				return {"success": false, "reason": "Video command cost mismatch.", "events": []}
			return {"success": true, "reason": "", "events": []}
		ActionRequest.ActionType.MOVE:
			var validation := network_graph.validate_traversal(player_network_position, StringName(request.target), player_knowledge.link_records.keys())
			if validation.error != NetworkGraph.TraversalError.OK:
				return {"success": false, "reason": NetworkGraph.TraversalError.keys()[validation.error], "events": []}
			var link: NetworkLinkDefinition = validation.link
			if request.cost != link.traversal_cost:
				return {"success": false, "reason": "Traversal cost mismatch.", "events": []}
			return {"success": true, "reason": "", "events": []}
		ActionRequest.ActionType.WAIT:
			return {"success": true, "reason": "", "events": []}
		ActionRequest.ActionType.SCAN:
			if not request.target is Dictionary:
				return {"success": false, "reason": "Scan target is malformed.", "events": []}
			var scan_validation := scan_system.validate_target(request.target)
			if not scan_validation.success:
				return {"success": false, "reason": scan_validation.reason, "events": []}
			if request.cost != scan_system.get_action_cost(request.target):
				return {"success": false, "reason": "Scan cost mismatch.", "events": []}
			return {"success": true, "reason": "", "events": []}
		ActionRequest.ActionType.EXPLOIT:
			if not request.target is Dictionary:
				return {"success": false, "reason": "Exploit target is malformed.", "events": []}
			var exploit_validation: Dictionary = mission.validate_exploit(request.target)
			if not exploit_validation.success:
				return {"success": false, "reason": exploit_validation.reason, "events": []}
			if request.cost != mission.exploit_cost(request.target):
				return {"success": false, "reason": "Exploit cost mismatch.", "events": []}
			return {"success": true, "reason": "", "events": []}
		ActionRequest.ActionType.TRANSFER:
			if not request.target is Dictionary:
				return {"success": false, "reason": "Transfer target is malformed.", "events": []}
			var transfer_validation: Dictionary = mission.validate_transfer(request.target)
			var expected_transfer_cost := clean_room_controller.adjusted_transfer_cost(3) if clean_room_controller != null else 3
			if request.cost != expected_transfer_cost:
				return {"success": false, "reason": "Transfer cost mismatch.", "events": []}
			return {"success": transfer_validation.success, "reason": transfer_validation.reason, "events": []}
		_:
			return {"success": false, "reason": "%s is not implemented." % request.get_action_name(), "events": []}

func _apply_action(request: ActionRequest) -> Dictionary:
	if confrontation_controller != null and confrontation_controller.has_action(request.action_type):
		last_confrontation_result = confrontation_controller.execute(request.action_type, request.target)
		if last_confrontation_result.success:
			pending_action_trace += last_confrontation_result.trace_generated
			if request.action_type == ActionRequest.ActionType.TRACE_SCRAMBLE:
				var reduction := int(last_confrontation_result.events[0].get("reduction", 0))
				trace_level = maxi(0, trace_level - reduction)
		return {"success": last_confrontation_result.success, "reason": last_confrontation_result.reason, "events": last_confrontation_result.events}
	match request.action_type:
		ActionRequest.ActionType.USE_PROGRAM:
			if request.metadata.get("system", &"") == &"DOORSTOP":
				var deployment: Dictionary = doorstop_controller.deploy(
					request.target.get("program_instance_id", &""), intrusion_run_id,
					player_network_position.current_node_id, float(action_clock.current_tick),
					{"trace": trace_level, "previous_node_id": player_network_position.previous_node_id},
					_doorstop_deployment_context()
				)
				if not deployment.success:
					return {"success": false, "reason": deployment.reason, "events": []}
				var node := network_graph.get_node(player_network_position.current_node_id)
				var node_label := node.display_name if node != null else String(player_network_position.current_node_id)
				var help := ""
				if not doorstop_deployment_help_shown:
					doorstop_deployment_help_shown = true
					help = "This specific Doorstop copy has been destroyed. The open backdoor can suspend this intrusion once and return you to this exact node once. Returning closes the route."
				_emit_doorstop_feedback(&"DEPLOYED", "DOORSTOP DEPLOYED", "Backdoor anchored to:\n%s" % node_label, help)
				_emit_doorstop_feedback(&"BURNED", "DOORSTOP INSTANCE BURNED", "%s removed from deck and inventory." % deployment.burned_instance_id)
				return {"success": true, "reason": deployment.reason, "events": [{
					"type": &"DOORSTOP_DEPLOYED",
					"program_instance_id": deployment.burned_instance_id,
					"node_id": player_network_position.current_node_id,
					"intrusion_run_id": intrusion_run_id,
				}]}
			if request.metadata.get("system", &"") != &"VIDEO_FEED":
				return {"success": false, "reason": "Unsupported program action.", "events": []}
			last_video_action_result = video_feed_manager.execute_action(request.target.feed_id, int(request.target.command))
			pending_action_trace += last_video_action_result.trace_generated
			return {"success": last_video_action_result.success, "reason": last_video_action_result.reason, "events": last_video_action_result.to_events()}
		ActionRequest.ActionType.MOVE:
			var origin := player_network_position.current_node_id
			var result := network_graph.apply_traversal(player_network_position, StringName(request.target), player_knowledge.link_records.keys())
			var move_events: Array[Dictionary] = [{"type": &"PLAYER_MOVED", "target": request.target}]
			if result.error == NetworkGraph.TraversalError.OK:
				player_knowledge.observe_traversal(network_graph, origin, StringName(request.target))
				move_events.append_array(progression_controller.on_node_entered(StringName(request.target)))
				var recovered := failure_controller.recover_at(player_network_position.current_node_id)
				if not recovered.is_empty():
					move_events.append({"type": &"CRASH_CACHE_RECOVERED", "resources": recovered})
				move_events.append_array(mission.check_completion())
				if mission.mission_complete:
					var committed := anchor_controller.commit_resources(player_network_position.current_node_id, resource_state)
					if not committed.is_empty():
						move_events.append({"type": &"VOLATILE_DATA_COMMITTED", "resources": committed})
			return {"success": result.error == NetworkGraph.TraversalError.OK, "reason": "Traversal complete.", "events": move_events}
		ActionRequest.ActionType.WAIT:
			return {"success": true, "reason": "Wait complete.", "events": [{"type": &"PLAYER_WAITED"}]}
		ActionRequest.ActionType.SCAN:
			last_scan_result = scan_system.perform_scan(request.target, int(request.metadata.get("scanner_power", 1)))
			if not last_scan_result.success:
				return {"success": false, "reason": last_scan_result.reason, "events": last_scan_result.events_produced}
			player_knowledge.commit_scan(last_scan_result, network_graph, ice_controller)
			pending_action_trace += last_scan_result.trace_generated
			var scan_events := last_scan_result.events_produced.duplicate(true)
			scan_events.append(last_scan_result.to_event())
			return {"success": true, "reason": last_scan_result.reason, "events": scan_events}
		ActionRequest.ActionType.EXPLOIT:
			var exploit: Dictionary = mission.execute_exploit(request.target)
			pending_action_trace += int(exploit.trace)
			return {"success": exploit.success, "reason": exploit.reason, "events": exploit.events}
		ActionRequest.ActionType.TRANSFER:
			var transfer: Dictionary = mission.execute_transfer(request.target)
			pending_action_trace += int(transfer.trace)
			return {"success": transfer.success, "reason": transfer.reason, "events": transfer.events}
	return {"success": false, "reason": "Unsupported action.", "events": []}

func _update_ice(tick: int, _request: ActionRequest) -> Array[Dictionary]:
	var events := ice_controller.update(_request.cost, _request)
	events.push_front({"type": &"ICE_UPDATED", "tick": tick, "player_visible": false})
	return events

func _update_trace(tick: int, _request: ActionRequest) -> Array[Dictionary]:
	var increase := ice_controller.pending_trace_increase + pending_action_trace
	ice_controller.pending_trace_increase = 0
	pending_action_trace = 0
	if player_network_position.has_capability(CapabilityCatalog.TRACE_SCRAMBLER):
		increase = maxi(0, increase - 1)
	if clean_room_controller != null and increase > 0:
		connection_trace_progress += float(increase) / clean_room_controller.trace_resolution_multiplier()
		increase = int(floor(connection_trace_progress))
		connection_trace_progress -= float(increase)
	trace_level += increase
	var events: Array[Dictionary] = [{"type": &"TRACE_UPDATED", "tick": tick, "increase": increase, "trace": trace_level, "player_visible": increase != 0}]
	if trace_level >= PayrollMissionController.TRACE_FAILURE_THRESHOLD:
		var failure_node := player_network_position.current_node_id
		failure_controller.force_disconnect_at_current_node(tick)
		trace_level = 5
		events.append({"type": &"FORCED_DISCONNECT", "failure_node_id": failure_node, "reconnect_node_id": anchor_controller.last_anchor_node_id})
		events.append({"type": &"CRASH_CACHE_CREATED", "node_id": failure_node})
	return events

func request_exploit(target: Dictionary) -> ActionResult:
	return request_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.EXPLOIT, target.duplicate(true), mission.exploit_cost(target)))

func request_transfer(target: Dictionary) -> ActionResult:
	var cost := clean_room_controller.adjusted_transfer_cost(3) if clean_room_controller != null else 3
	return request_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.TRANSFER, target.duplicate(true), cost))

func _update_network_systems(tick: int, _request: ActionRequest) -> Array[Dictionary]:
	return [{"type": &"NETWORK_SYSTEMS_UPDATED", "tick": tick}, deep_exploration.update(trace_level)]

func commit_resources_at_anchor() -> Dictionary:
	return anchor_controller.commit_resources(player_network_position.current_node_id, resource_state)

func force_disconnect() -> bool:
	return failure_controller.force_disconnect_at_current_node(action_clock.current_tick)

func recover_crash_cache() -> Dictionary:
	return failure_controller.recover_at(player_network_position.current_node_id)
