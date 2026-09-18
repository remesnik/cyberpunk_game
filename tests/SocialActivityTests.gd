extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	_test_authored_inbox()
	await _test_clean_room_indicator()
	print("%s: %d social activity assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_authored_inbox() -> void:
	var state := PersistentGameState.new()
	StoryModeNewGameInitializer.initialize(state)
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/social_messages.json"))
	var inbox := SocialMessageInbox.new(); inbox.configure(state, definitions)
	_expect(inbox.evaluate(&"CLEAN_ROOM_ENTER").is_empty(), "story-gated messages stay unavailable before their milestone")
	state.campaign_state.story_flags.DECK_SELECTED = true
	var first := inbox.evaluate(&"CLEAN_ROOM_ENTER", {"progress": 1})
	_expect(first.size() == 1 and first[0].actor_id == &"LATCH" and inbox.unread_count() == 1, "eligible Latch ping is delivered unread")
	_expect(inbox.evaluate(&"CLEAN_ROOM_ENTER", {"progress": 2}).is_empty(), "one-time optional contacts do not repeat")
	_expect(inbox.mark_read(first[0].id) and inbox.unread_count() == 0, "read state persists in the shared inbox")
	state.campaign_state.story_flags.CLEAN_ROOM_LATCH_CONTACTED = true
	_expect(inbox.evaluate(&"RUN_RETURN", {"success": true, "progress": 2}).size() == 1, "repeatable acknowledgement responds to authored run state")
	_expect(inbox.evaluate(&"RUN_RETURN", {"success": true, "progress": 3}).is_empty(), "repeatable contact respects its authored progress cooldown")
	_expect(inbox.evaluate(&"RUN_RETURN", {"success": false, "progress": 4}).any(func(message: Dictionary) -> bool: return message.id == &"LATCH_MISSED_CHECKIN"), "failed or missed returns select their authored non-blocking contact")
	_expect(inbox.evaluate(&"RUN_RETURN", {"success": true, "trace": 15, "progress": 6}).any(func(message: Dictionary) -> bool: return int(message.priority) == SocialMessageInbox.Priority.CRITICAL), "trace state promotes an authored warning to critical priority")
	var restored := SocialMessageInbox.new(); restored.configure(PersistentGameState.from_save_data(state.to_save_data()), definitions)
	_expect(restored.unread_count() == inbox.unread_count(), "unread and delivery history survive save reconstruction")

func _test_clean_room_indicator() -> void:
	Game.create_new_game(GameMode.Value.FREE_ROAM)
	Game.start_session()
	Game.enter_free_roam_network()
	var room := (load("res://ui/clean_room/CleanRoom.tscn") as PackedScene).instantiate() as CleanRoom
	add_child(room)
	await get_tree().process_frame
	_expect(room.get_node("PrepPanel/Rows/InboxButton").disabled, "Clean-Room inbox stays visually quiet when empty")
	Game.social_inbox.add_authored(&"TEST_OPTIONAL", &"LATCH", "Still here.")
	await get_tree().process_frame
	_expect(not room.get_node("PrepPanel/Rows/InboxButton").disabled and "1 UNREAD" in room.get_node("PrepPanel/Rows/AllyStatus").text, "Clean-Room displays a sparse incoming-message indicator")
	var bedroom := (load("res://ui/story_prologue/PlayerBedroom.tscn") as PackedScene).instantiate() as PlayerBedroom
	add_child(bedroom); bedroom.bind_state(Game.persistent_game_state)
	_expect((bedroom.dressing[&"MESSAGE_WAITING"].node as Node3D).visible, "unread social state leaves a message-waiting indicator in Meatspace")
	bedroom.free()
	room.free(); Game.end_session()
	await get_tree().process_frame

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
