class_name MissionResult
extends Resource

@export var mission_id: StringName
@export var success := false
@export var primary_objectives: Array[Dictionary] = []
@export var optional_objectives: Array[Dictionary] = []
@export var hidden_objectives: Array[Dictionary] = []
@export var trace_outcome := 0
@export var alarm_state := false
@export var files_extracted: Array[StringName] = []
@export var targets_scanned: Array[StringName] = []
@export var services_disabled: Array[StringName] = []
@export var stream_intercepts: Array[StringName] = []
@export var contacts_helped: Array[StringName] = []
@export var ic_earned := 0
@export var story_flags_generated: Array[StringName] = []
@export var consequences: Array[String] = []
@export var trace_result: StringName = &"CLEAR"
@export var warden_state: StringName = &"NOT_ENCOUNTERED"
@export var primary_objective_completed := false
@export var personnel_file_acquired := false
@export var unknown_ice_scanned := false
@export var executive_comms_intercepted := false

func to_dict() -> Dictionary:
	return {"mission_id": mission_id, "success": success, "primary_objectives": primary_objectives.duplicate(true), "optional_objectives": optional_objectives.duplicate(true), "hidden_objectives": hidden_objectives.duplicate(true), "trace_outcome": trace_outcome, "trace_result": trace_result, "alarm_state": alarm_state, "files_extracted": files_extracted.duplicate(), "targets_scanned": targets_scanned.duplicate(), "services_disabled": services_disabled.duplicate(), "stream_intercepts": stream_intercepts.duplicate(), "contacts_helped": contacts_helped.duplicate(), "ic_earned": ic_earned, "story_flags_generated": story_flags_generated.duplicate(), "consequences": consequences.duplicate(), "primary_objective_completed": primary_objective_completed, "personnel_file_acquired": personnel_file_acquired, "unknown_ice_scanned": unknown_ice_scanned, "executive_comms_intercepted": executive_comms_intercepted, "warden_state": warden_state}

static func from_dict(data: Dictionary) -> MissionResult:
	var result := MissionResult.new(); result.mission_id = StringName(data.get("mission_id", &"")); result.success = bool(data.get("success", false))
	result.primary_objectives.assign(data.get("primary_objectives", [])); result.optional_objectives.assign(data.get("optional_objectives", [])); result.hidden_objectives.assign(data.get("hidden_objectives", []))
	result.trace_outcome = int(data.get("trace_outcome", 0)); result.trace_result = StringName(data.get("trace_result", &"CLEAR")); result.alarm_state = bool(data.get("alarm_state", false)); result.files_extracted.assign(data.get("files_extracted", [])); result.targets_scanned.assign(data.get("targets_scanned", [])); result.services_disabled.assign(data.get("services_disabled", [])); result.stream_intercepts.assign(data.get("stream_intercepts", [])); result.contacts_helped.assign(data.get("contacts_helped", [])); result.ic_earned = int(data.get("ic_earned", 0)); result.story_flags_generated.assign(data.get("story_flags_generated", [])); result.consequences.assign(data.get("consequences", [])); result.primary_objective_completed = bool(data.get("primary_objective_completed", result.success)); result.personnel_file_acquired = bool(data.get("personnel_file_acquired", result.files_extracted.has(&"personnel.dat"))); result.unknown_ice_scanned = bool(data.get("unknown_ice_scanned", result.targets_scanned.has(&"UNKNOWN_ICE"))); result.executive_comms_intercepted = bool(data.get("executive_comms_intercepted", result.stream_intercepts.has(&"EXECUTIVE_COMMS"))); result.warden_state = StringName(data.get("warden_state", &"NOT_ENCOUNTERED")); return result

func debrief_view(title := "") -> Dictionary:
	return {"mission_id": mission_id, "title": title, "success": success, "primary_result": "Personnel.dat acquired" if personnel_file_acquired else "Personnel.dat not acquired", "optional_objectives": optional_objectives.duplicate(true), "trace_result": trace_result, "warden_state": warden_state, "important_consequences": consequences.duplicate(), "ic_reward": ic_earned, "story_flags": story_flags_generated.duplicate()}
