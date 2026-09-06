class_name FreeRoamJobBoard
extends RefCounted

signal job_accepted(job_id: StringName)
signal job_completed(job_id: StringName, reward_credits: int)

var catalog: FreeRoamJobCatalog
var game_state: PersistentGameState

func configure(source_catalog: FreeRoamJobCatalog, state: PersistentGameState) -> void:
	catalog = source_catalog
	game_state = state

func available_jobs() -> Array[FreeRoamJobDefinition]:
	var result: Array[FreeRoamJobDefinition] = []
	if catalog == null or game_state == null: return result
	var ids: Array = game_state.world_state.get("available_dynamic_job_ids", [])
	var active: Array = game_state.world_state.get("active_job_ids", [])
	var completed: Array = game_state.world_state.get("completed_dynamic_job_ids", [])
	for value in ids:
		var job := catalog.get_job(StringName(value))
		if job != null and job.id not in active and job.id not in completed and _prerequisites_met(job): result.append(job)
	return result

func accept_job(job_id: StringName) -> Dictionary:
	var job := catalog.get_job(job_id) if catalog != null else null
	if job == null or job not in available_jobs(): return _failure("Job is not available.")
	var active: Array = game_state.world_state.get("active_job_ids", []).duplicate()
	if job_id in active: return _failure("Job is already active.")
	active.append(job_id)
	game_state.world_state["active_job_ids"] = active
	job_accepted.emit(job_id)
	return {"success": true, "reason": "Job accepted.", "job": job}

func complete_job(job_id: StringName) -> Dictionary:
	var active: Array = game_state.world_state.get("active_job_ids", []).duplicate()
	if job_id not in active: return _failure("Job is not active.")
	var job := catalog.get_job(job_id)
	if job == null: return _failure("Job definition is missing.")
	active.erase(job_id)
	var completed: Array = game_state.world_state.get("completed_dynamic_job_ids", []).duplicate()
	if job_id not in completed: completed.append(job_id)
	game_state.world_state["active_job_ids"] = active
	game_state.world_state["completed_dynamic_job_ids"] = completed
	game_state.player_state["credits"] = int(game_state.player_state.get("credits", 0)) + job.reward_credits
	job_completed.emit(job_id, job.reward_credits)
	return {"success": true, "reason": "Job completed.", "reward_credits": job.reward_credits}

func _prerequisites_met(job: FreeRoamJobDefinition) -> bool:
	var flags: Dictionary = game_state.world_state.get("world_flags", {})
	for flag in job.prerequisite_flags:
		if not bool(flags.get(flag, false)): return false
	return true

func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
