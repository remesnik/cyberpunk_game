class_name FrontendSaveSummary
extends RefCounted

## Presentation-safe metadata supplied by the save system. These fields must not
## contain undiscovered objective, topology, actor, or security information.
var save_id: StringName
var network_name := ""
var location_name := ""
var display_timestamp := ""
var playtime_display := "00:00:00"
var game_mode: GameMode.Value = GameMode.Value.STORY
var resumable := false

func _init(p_save_id := &"", p_network_name := "", p_location_name := "", p_display_timestamp := "", p_resumable := false, p_game_mode: GameMode.Value = GameMode.Value.STORY, p_playtime_display := "00:00:00") -> void:
	save_id = p_save_id
	network_name = p_network_name
	location_name = p_location_name
	display_timestamp = p_display_timestamp
	resumable = p_resumable
	game_mode = p_game_mode
	playtime_display = p_playtime_display

func is_valid() -> bool:
	return not save_id.is_empty() and resumable

func mode_label() -> String:
	return "FREE ROAM" if game_mode == GameMode.Value.FREE_ROAM else "STORY"

static func from_save_data(data: Dictionary, fallback_save_id: StringName = &"") -> FrontendSaveSummary:
	var state := PersistentGameState.from_save_data(data)
	var metadata: Dictionary = state.save_metadata
	var saved_at := int(metadata.get("saved_at_unix", 0))
	var timestamp := String(metadata.get("display_timestamp", ""))
	if timestamp.is_empty() and saved_at > 0: timestamp = Time.get_datetime_string_from_unix_time(saved_at, true)
	return FrontendSaveSummary.new(
		StringName(metadata.get("save_id", fallback_save_id)), String(metadata.get("network_name", "")),
		String(metadata.get("location_name", "")), timestamp, bool(metadata.get("resumable", true)),
		state.get_game_mode(), _format_playtime(float(metadata.get("playtime_seconds", 0.0)))
	)

static func _format_playtime(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]
