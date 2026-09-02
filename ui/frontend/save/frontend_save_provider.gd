class_name FrontendSaveProvider
extends RefCounted

## Narrow adapter between the frontend and a future authoritative save service.
## The default implementation intentionally exposes no save capability.
signal saves_changed

func get_most_recent_resumable() -> FrontendSaveSummary:
	return null

func get_resumable_saves() -> Array[FrontendSaveSummary]:
	return []

func has_load_browser() -> bool:
	return false

func continue_save(_save_id: StringName) -> Error:
	return ERR_UNAVAILABLE

func create_load_browser() -> Control:
	return null
