class_name DoorstopSuspensionPolicy
extends Resource

@export var preserve_trace := true
@export var trace_increase_per_second := 0.0
@export var alarms_remain_active := true
@export var ice_may_reposition := false
@export var ice_step_seconds := 10.0
@export var maximum_ice_steps_per_advance := 10
@export var replacement_ice_may_spawn := false
@export var replacement_ice_interval_seconds := 60.0
@export var maximum_replacement_ice_per_advance := 1
@export var security_may_escalate := false
@export var security_escalation_interval_seconds := 60.0
@export var maximum_security_level := 5
@export var temporary_effects_may_expire := true
@export var node_local_processes_continue := false


static func forgiving() -> DoorstopSuspensionPolicy:
	return DoorstopSuspensionPolicy.new()
