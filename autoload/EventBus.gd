extends Node

signal session_started
signal pause_changed(is_paused: bool)
signal pause_policy_changed(previous_mode: int, current_mode: int)
signal debug_visibility_changed(is_visible: bool)
signal network_traversal_started(from_node_id: StringName, to_node_id: StringName, link_id: StringName)
signal network_time_advanced(time_units: int)
signal network_position_changed(from_node_id: StringName, to_node_id: StringName, link_id: StringName)
signal network_display_update_requested
signal simulation_tick_advanced(previous_tick: int, current_tick: int, amount: int)
signal action_resolved(request: ActionRequest, result: ActionResult)
signal intrusion_lifecycle_changed(intrusion_id: StringName, previous_state: int, current_state: int)
signal game_domain_changed(previous_domain: int, current_domain: int)
signal doorstop_feedback(event: Dictionary)
