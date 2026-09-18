@tool
class_name AuthoringPreviewWorkspace
extends VBoxContainer


func _ready() -> void:
	var label := Label.new(); label.text = "SAFE PREVIEW // TRUE WORLD ≠ PLAYER KNOWLEDGE"; add_child(label)
	var note := Label.new(); note.text = "Use bottom preview controls to change editor-only profiles, realtime speed, and cyber ticks. Preview state is never saved into runtime content."; note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(note)
	var story := Label.new(); story.name = "StoryStatePreview"; story.text = _snapshot(); story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(story)
	var row := HBoxContainer.new(); add_child(row)
	var flag := LineEdit.new(); flag.name = "DevStoryFlag"; flag.placeholder_text = "DEV FLAG ID"; flag.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(flag)
	var toggle := Button.new(); toggle.text = "SET DEV FLAG"; toggle.pressed.connect(func() -> void:
		if not Engine.is_editor_hint() or flag.text.strip_edges().is_empty(): return
		Game.persistent_game_state.campaign_state.get_or_add("story_flags", {})[StringName(flag.text)] = true
		story.text = _snapshot()
	); row.add_child(toggle)

func _snapshot() -> String:
	if not Engine.is_editor_hint() or Game == null or Game.persistent_game_state == null: return "STORY PREVIEW UNAVAILABLE"
	var state := StoryState.new(Game.persistent_game_state); var active := StringName(Game.persistent_game_state.campaign_state.get("active_mission_id", &"NONE"))
	var contacts: Array = []
	for id: Variant in Game.persistent_game_state.campaign_state.get("contacts", {}):
		if state.is_contact_unlocked(StringName(id)): contacts.append(id)
	return "FLAGS: %s\nMISSION: %s\nOBJECTIVES: %s\nSTORY TIME: %s\nCONTACTS: %s\nRECENT EVENTS: %s" % [Game.persistent_game_state.campaign_state.get("story_flags", {}), active, Game.persistent_game_state.campaign_state.get("active_mission_run", {}).get("objectives", {}), Game.persistent_game_state.world_state.get("time_of_day", "NIGHT"), contacts, Game.story_event_system.trigger_serial if Game.story_event_system != null else 0]
