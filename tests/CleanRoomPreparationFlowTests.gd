extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	Game.create_new_game(GameMode.Value.STORY)
	Game.persistent_game_state.campaign_state["pending_entry_content_id"] = &"FIRST_CONTACT"
	Game.persistent_game_state.campaign_state["current_content_id"] = &"FIRST_CONTACT"
	Game.start_session()
	var room := (load("res://ui/clean_room/CleanRoom.tscn") as PackedScene).instantiate() as CleanRoom
	add_child(room); room.visible = true
	await get_tree().process_frame
	_expect("FIRST CONTACT" in room.get_node("ContentMargin/Columns/MissionPanel/MissionLabel").text and "Retrieve the file" in room.get_node("ContentMargin/Columns/MissionPanel/MissionLabel").text, "first run presents the concise First Contact target and objective")
	_expect(not room.go_button.disabled and room.get_node("ActionBar/Row/ReadinessLabel").text.contains("READY"), "tutorial can launch without opening Loadout")
	_expect(room.get_viewport().gui_get_focus_owner() == room.go_button, "first controller/keyboard focus favors GO")
	_expect(room.get_node("LoadoutPanel/Sheet/Rows/SoftwareScroll") is ScrollContainer, "long software details scroll inside Loadout")
	room.open_loadout()
	_expect(room.loadout_panel.visible and room.go_button.is_visible_in_tree() and not room.loadout_panel.get_global_rect().intersects(room.go_button.get_global_rect()), "Loadout is progressive disclosure and never obscures GO")
	room.close_loadout()
	for resolution in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768)]:
		room.size = Vector2(resolution); await get_tree().process_frame
		var go_rect: Rect2 = room.go_button.get_global_rect(); var action_rect: Rect2 = (room.get_node("ActionBar") as Control).get_global_rect()
		_expect(go_rect.position.x >= 0 and go_rect.position.y >= 0 and go_rect.end.x <= resolution.x and go_rect.end.y <= resolution.y, "GO remains visible at %s" % resolution)
		_expect(action_rect.encloses(go_rect), "GO remains inside the anchored action bar at %s" % resolution)
	var original_memory := Game.program_loadout.memory_capacity
	Game.program_loadout.memory_capacity = maxi(0, Game.program_loadout.memory_used(Game.program_inventory) - 1)
	var blocked: Dictionary = Game.clean_room_controller.launch_readiness()
	_expect(not blocked.ready and "memory" in String(blocked.reason).to_lower(), "GO validation exposes the exact blocking Memory reason")
	Game.program_loadout.memory_capacity = original_memory
	room.free(); Game.end_session()
	print("%s: %d Clean-Room preparation-flow assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
