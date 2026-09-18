class_name PersistentGameState
extends Resource

const CURRENT_SCHEMA_VERSION := 5
const LEGACY_DEFAULT_MODE := GameMode.Value.STORY

@export var schema_version := CURRENT_SCHEMA_VERSION
@export_enum("STORY", "FREE_ROAM") var game_mode: int = GameMode.Value.STORY
@export var campaign_state: Dictionary = {}
@export var player_state: Dictionary = {}
@export var world_state: Dictionary = {}
@export var save_metadata: Dictionary = {}

func set_game_mode(mode: GameMode.Value) -> void:
	game_mode = mode if GameMode.is_valid(mode) else LEGACY_DEFAULT_MODE
	emit_changed()

func get_game_mode() -> GameMode.Value:
	return game_mode as GameMode.Value

func is_story_mode() -> bool:
	return game_mode == GameMode.Value.STORY

func is_free_roam_mode() -> bool:
	return game_mode == GameMode.Value.FREE_ROAM

func to_save_data() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"game_mode": String(GameMode.to_id(get_game_mode())),
		"campaign_state": campaign_state.duplicate(true),
		"player_state": player_state.duplicate(true),
		"world_state": world_state.duplicate(true),
		"save_metadata": save_metadata.duplicate(true),
	}

static func from_save_data(data: Dictionary) -> PersistentGameState:
	var state := PersistentGameState.new()
	var source_version := int(data.get("schema_version", 1))
	if source_version < 2 or not data.has("game_mode"):
		# Development saves predating explicit modes represent the authored
		# campaign prototype, so STORY is the least surprising safe migration.
		state.game_mode = LEGACY_DEFAULT_MODE
	else:
		var stored: Variant = data.get("game_mode", "STORY")
		if stored is int and GameMode.is_valid(stored): state.game_mode = int(stored)
		else: state.game_mode = GameMode.from_frontend_id(StringName(String(stored)))
	state.campaign_state = (data.get("campaign_state", {}) as Dictionary).duplicate(true)
	state.player_state = (data.get("player_state", {}) as Dictionary).duplicate(true)
	state.world_state = (data.get("world_state", {}) as Dictionary).duplicate(true)
	state.save_metadata = (data.get("save_metadata", {}) as Dictionary).duplicate(true)
	StoryState.ensure_defaults(state)
	state.schema_version = CURRENT_SCHEMA_VERSION
	return state

func save_to_file(path: String) -> Error:
	if StringName(save_metadata.get("save_id", &"")).is_empty(): save_metadata["save_id"] = StringName(path.get_file().get_basename())
	save_metadata["saved_at_unix"] = int(Time.get_unix_time_from_system())
	save_metadata["resumable"] = true
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_save_data(), "  "))
	return OK

static func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"error": ERR_FILE_NOT_FOUND, "state": null}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error": FileAccess.get_open_error(), "state": null}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary: return {"error": ERR_PARSE_ERROR, "state": null}
	return {"error": OK, "state": from_save_data(parsed)}
