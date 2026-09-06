extends Node
const REQUIRED_IDS: Array[StringName] = [&"WINDOW", &"DESK", &"BED", &"POSTER_VIRUS", &"POSTER_PHREAKER", &"POSTER_WAREZ", &"STARTER_DECK_BOX", &"TOOLBOX", &"DISPLAY_TABLE", &"BOOKSHELF", &"JACK_IN_INTERFACE"]
var failures := 0
var assertions := 0

func _ready() -> void:
	var definition := load("res://data/authoring/story_prologue.tres") as MeatspacePrologueDefinition
	_expect(definition != null and definition.validate().is_empty(), "authoring validates")
	var state := PersistentGameState.new()
	var controller := MeatspacePrologueController.new()
	controller.configure(definition, state)
	var bedroom := _room(state)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		bedroom.viewport.get_texture().get_image().save_png("res://.godot/bedroom-preview.png")
	var ids := bedroom.get_object_ids()
	_expect(ids.size() == REQUIRED_IDS.size() and REQUIRED_IDS.all(func(id: StringName) -> bool: return id in ids), "all authored targets mapped")
	_expect(bedroom.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "true perspective camera")
	_expect(bedroom.viewport.own_world_3d, "room has isolated 3D world")
	var selections: Array[Dictionary] = []
	bedroom.object_selected.connect(func(data: Dictionary) -> void: selections.append(data))
	for id: StringName in ids:
		var target: MeatspaceTarget3D = bedroom.objects[id]
		var shape := target.get_child(0) as CollisionShape3D
		var screen := bedroom.camera.unproject_position(shape.global_position) * bedroom.size / Vector2(bedroom.viewport.size)
		_expect(bedroom.pick(screen) == target, "ray resolves visible target %s" % id)
		var click := InputEventMouseButton.new()
		click.position = screen
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		bedroom._gui_input(click)
		_expect(not selections.is_empty() and StringName(selections.back().id) == id, "mouse dispatches authored object %s" % id)
	_expect(bedroom.pick(Vector2(-10, -10)) == null, "outside viewport cannot select")
	var prior := selections.size()
	bedroom._on_prop_selected(&"UNKNOWN")
	_expect(selections.size() == prior, "unknown ID cannot dispatch")
	var physical := MeatspaceInteractionController.new()
	physical.configure(bedroom.location_definition, state)
	var box_lid: Node3D = bedroom.objects[&"STARTER_DECK_BOX"].get_node("Lid")
	var tool_lid: Node3D = bedroom.objects[&"TOOLBOX"].get_node("Lid")
	_expect(bedroom.display_anchors[0].get_child_count() == 0 and box_lid.rotation == Vector3.ZERO and tool_lid.rotation == Vector3.ZERO, "initial room is empty with closed containers")
	# Same phase link used by StoryPrologueScreen; no story action lives in the view.
	var terminal: Dictionary = bedroom.objects[&"JACK_IN_INTERFACE"].authored_data
	var interaction_id := StringName(terminal.phase_interactions[controller.phase])
	_expect(controller.select_interaction(interaction_id).success, "physical target resolves authored interaction")
	_expect(controller.choose(interaction_id, &"CLAN_GHOSTS").success, "authored interaction dispatch")
	_expect(controller.choose(&"DECK_CRATE", &"DECK_SCOUT").success, "deck story choice succeeds")
	_expect(physical.execute(&"STARTER_DECK_BOX", &"OPEN").success and box_lid.rotation.x < -1, "authored physical action opens box")
	_expect(physical.execute(&"TOOLBOX", &"OPEN").success and tool_lid.rotation.x < -1, "toolbox appearance follows authored action")
	const SAVE_PATH := "res://.godot/bedroom-state-test.json"
	_expect(state.save_to_file(SAVE_PATH) == OK, "room story state saves to disk")
	var connections_before := state.changed.get_connections().size()
	bedroom.queue_free()
	await get_tree().process_frame
	_expect(state.changed.get_connections().size() == connections_before - 1, "unloading disconnects room state listener")
	var loaded := PersistentGameState.load_from_file(SAVE_PATH)
	_expect(loaded.error == OK, "room story state loads from disk")
	var restored := loaded.state as PersistentGameState
	var restored_snapshot := restored.to_save_data()
	DirAccess.remove_absolute(SAVE_PATH)
	var returned := _room(restored)
	await get_tree().process_frame
	_expect(returned.display_anchors[0].get_child_count() == 0, "empty display restored on room reentry")
	_expect(returned.objects[&"STARTER_DECK_BOX"].get_node("Lid").rotation.x < -1 and returned.objects[&"TOOLBOX"].get_node("Lid").rotation.x < -1, "container state restored after save roundtrip")
	_expect(restored.to_save_data() == restored_snapshot, "room presentation never mutates saved story state")
	returned.bind_state(PersistentGameState.new())
	_expect(returned.objects[&"TOOLBOX"].get_node("Lid").rotation == Vector3.ZERO, "rebinding a new game clears prior visuals")
	returned.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("%s: %d PLAYER_BEDROOM assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _room(state: PersistentGameState) -> PlayerBedroom:
	var room := (load("res://ui/story_prologue/PlayerBedroom.tscn") as PackedScene).instantiate() as PlayerBedroom
	add_child(room)
	room.set_anchors_preset(Control.PRESET_TOP_LEFT)
	room.size = Vector2(960, 640)
	room.bind_state(state)
	return room

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)

