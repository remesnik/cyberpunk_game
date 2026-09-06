class_name PersistentGameSaveProvider
extends FrontendSaveProvider

var save_directory := "user://saves"
var _paths: Dictionary = {}
var _scanned := false

func _init(directory := "user://saves") -> void:
	save_directory = directory

func refresh() -> void:
	_paths.clear()
	_scanned = true
	var directory := DirAccess.open(save_directory)
	if directory == null:
		saves_changed.emit()
		return
	for filename in directory.get_files():
		if filename.get_extension().to_lower() != "json": continue
		var path := save_directory.path_join(filename)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null: continue
		var payload: Variant = JSON.parse_string(file.get_as_text())
		if not payload is Dictionary: continue
		var summary := FrontendSaveSummary.from_save_data(payload, StringName(filename.get_basename()))
		if summary.is_valid(): _paths[summary.save_id] = {"path": path, "summary": summary}
	saves_changed.emit()

func get_most_recent_resumable() -> FrontendSaveSummary:
	_ensure_scanned()
	var summaries := get_resumable_saves()
	if summaries.is_empty(): return null
	summaries.sort_custom(func(a: FrontendSaveSummary, b: FrontendSaveSummary): return a.display_timestamp > b.display_timestamp)
	return summaries[0]

func get_resumable_saves() -> Array[FrontendSaveSummary]:
	_ensure_scanned()
	var result: Array[FrontendSaveSummary] = []
	for record: Dictionary in _paths.values(): result.append(record.summary)
	return result

func has_load_browser() -> bool: return true

func continue_save(save_id: StringName) -> Error:
	_ensure_scanned()
	if not _paths.has(save_id): return ERR_FILE_NOT_FOUND
	var game: Node = Engine.get_main_loop().root.get_node_or_null("Game")
	return game.load_persistent_state(_paths[save_id].path) if game != null else ERR_UNAVAILABLE

func _ensure_scanned() -> void:
	if not _scanned: refresh()
