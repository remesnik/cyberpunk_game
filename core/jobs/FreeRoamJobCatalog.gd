class_name FreeRoamJobCatalog
extends Resource

@export var jobs: Array[FreeRoamJobDefinition] = []

func get_job(job_id: StringName) -> FreeRoamJobDefinition:
	for job in jobs:
		if job != null and job.id == job_id: return job
	return null

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for job in jobs:
		if job == null or not job.is_valid():
			errors.append("Invalid Free Roam job definition.")
			continue
		if ids.has(job.id): errors.append("Duplicate Free Roam job ID: %s" % job.id)
		ids[job.id] = true
	return errors
