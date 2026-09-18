extends Node

signal session_started
signal pause_changed(is_paused: bool)
signal pause_policy_changed(previous_mode: int, current_mode: int)
signal debug_visibility_changed(is_visible: bool)
signal network_traversal_started(from_node_id: StringName, to_node_id: StringName, link_id: StringName)
signal network_time_advanced(time_units: int)
signal network_position_changed(from_node_id: StringName, to_node_id: StringName, link_id: StringName)
signal sphere_changed(player_id: StringName, previous_sphere_id: StringName, new_sphere_id: StringName, entry_node_id: StringName)
signal security_sleeve_changed(sleeve_id: StringName)
signal network_display_update_requested
signal network_node_focus_requested(node_id: StringName)
signal simulation_tick_advanced(previous_tick: int, current_tick: int, amount: int)
signal action_resolved(request: ActionRequest, result: ActionResult)
signal intrusion_lifecycle_changed(intrusion_id: StringName, previous_state: int, current_state: int)
signal game_domain_changed(previous_domain: int, current_domain: int)
signal meatspace_autosave_completed(reason: StringName, path: String, error: Error)
signal game_over_started(message: String, can_continue: bool)
signal game_over_recovered(from_autosave: bool, message: String)
signal doorstop_feedback(event: Dictionary)
signal san_relocated(san_id: StringName, previous_node_id: StringName, current_node_id: StringName)
signal tactical_status_alert(event: Dictionary)
signal monitor_presentation_changed(active: bool, expanded: bool)

func publish_tactical_status_alert(type: StringName, subject_id: StringName = &"", message: String = "", severity: StringName = &"WARNING", duration := 4.0, metadata: Dictionary = {}) -> void:
	var event := {"type": type, "subject_id": subject_id, "message": message, "severity": severity, "duration": maxf(0.5, duration), "metadata": metadata.duplicate(true), "player_visible": true}
	tactical_status_alert.emit(event)
