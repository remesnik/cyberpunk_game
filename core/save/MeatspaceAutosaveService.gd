class_name MeatspaceAutosaveService
extends RefCounted

enum Reason { NORMAL_JACK_OUT, DOORSTOP_EXIT, MISSION_COMPLETE, RETURN_TO_MEATSPACE }

var autosave_path := "user://saves/current_autosave.json"
var successful_save_count := 0
var request_count := 0
var last_reason: Reason = Reason.RETURN_TO_MEATSPACE
var last_error: Error = OK

func request(state: PersistentGameState, reason: Reason, metadata: Dictionary = {}) -> Error:
	request_count += 1
	last_reason = reason
	if state == null:
		last_error = ERR_INVALID_DATA
		return last_error
	var directory := autosave_path.get_base_dir()
	if not directory.is_empty():
		var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		if directory_error != OK:
			last_error = directory_error
			return last_error
	state.save_metadata["save_id"] = &"CURRENT_AUTOSAVE"
	state.save_metadata["autosave"] = true
	state.save_metadata["autosave_reason"] = reason_id(reason)
	state.save_metadata["autosave_metadata"] = metadata.duplicate(true)
	last_error = state.save_to_file(autosave_path)
	if last_error == OK: successful_save_count += 1
	return last_error

func load_latest() -> Dictionary:
	var loaded := PersistentGameState.load_from_file(autosave_path)
	if loaded.error != OK: return loaded
	var state := loaded.state as PersistentGameState
	if state == null or not bool(state.save_metadata.get("autosave", false)) or not bool(state.save_metadata.get("resumable", false)):
		return {"error": ERR_INVALID_DATA, "state": null}
	return {"error": OK, "state": state}

func has_valid_autosave() -> bool:
	return load_latest().error == OK

static func reason_id(reason: Reason) -> StringName:
	return StringName(Reason.keys()[reason])
