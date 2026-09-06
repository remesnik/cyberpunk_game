extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var save_dir := "user://mode_save_tests"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	var story := PersistentGameState.new(); StoryModeNewGameInitializer.initialize(story)
	story.save_metadata.merge({"save_id": &"ADAM_01", "network_name": "FINANCE SPHERE", "location_name": "LOCAL RELAY", "playtime_seconds": 13338.0}, true)
	var free_roam := PersistentGameState.new(); FreeRoamNewGameInitializer.initialize(free_roam)
	free_roam.save_metadata.merge({"save_id": &"SANDBOX_02", "network_name": "PUBLIC MESH", "location_name": "SAFEHOUSE // DECK", "playtime_seconds": 26324.0}, true)
	# Simulate a save written after the initial pending route was consumed.
	free_roam.world_state["current_content_id"] = free_roam.world_state.pending_entry_content_id
	free_roam.world_state["pending_entry_content_id"] = &""
	_expect(story.save_to_file(save_dir.path_join("story.json")) == OK and free_roam.save_to_file(save_dir.path_join("free_roam.json")) == OK, "both explicit modes save successfully")
	var provider := PersistentGameSaveProvider.new(save_dir); provider.refresh()
	var summaries := provider.get_resumable_saves()
	var story_summary: FrontendSaveSummary
	var free_summary: FrontendSaveSummary
	for summary in summaries:
		if summary.save_id == &"ADAM_01": story_summary = summary
		elif summary.save_id == &"SANDBOX_02": free_summary = summary
	_expect(story_summary != null and story_summary.mode_label() == "STORY" and story_summary.playtime_display == "03:42:18", "Story summary exposes explicit mode and playtime")
	_expect(free_summary != null and free_summary.mode_label() == "FREE ROAM" and free_summary.playtime_display == "07:18:44", "Free Roam summary exposes explicit mode and playtime")
	var load_screen := (load("res://ui/frontend/load_screen.tscn") as PackedScene).instantiate() as FrontendLoadScreen
	add_child(load_screen); await get_tree().process_frame
	load_screen.set_saves(summaries); await get_tree().process_frame
	var rendered := ""
	for child in load_screen.session_list.get_children(): rendered += (child as Button).text + "\n"
	_expect("ADAM_01\nSTORY\nFINANCE SPHERE\n03:42:18" in rendered and "SANDBOX_02\nFREE ROAM\nPUBLIC MESH\n07:18:44" in rendered, "load browser renders compact mode labels without name inference")
	var game := get_node("/root/Game")
	_expect(provider.continue_save(&"SANDBOX_02") == OK and game.is_free_roam_mode() and game.persistent_game_state.campaign_state.is_empty(), "Continue restores Free Roam without Story initialization")
	game.start_session()
	_expect(game.network_graph.get_sphere(&"PUBLIC_MESH") != null and game.active_content_document == null, "loaded Free Roam current content resumes its sandbox runtime")
	game.end_session()
	_expect(provider.continue_save(&"ADAM_01") == OK and game.is_story_mode() and game.persistent_game_state.campaign_state.campaign_id == &"MAIN_CAMPAIGN", "Continue restores Story without Free Roam initialization")
	game.start_session()
	_expect(game.active_content_document != null and game.active_content_document.document_id == &"FIRST_CONTACT", "loaded Story state resumes authored Story content")
	game.end_session()
	load_screen.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir.path_join("story.json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir.path_join("free_roam.json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir))
	print("%s: %d save-mode metadata assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
