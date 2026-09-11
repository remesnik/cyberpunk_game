extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	for choice_id: StringName in [&"DECK_SCOUT", &"DECK_BALANCED"]:
		await _verify_variant(choice_id)
	await get_tree().create_timer(0.15).timeout
	print("%s: %d bedroom prop/progression assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _verify_variant(choice_id: StringName) -> void:
	var state := PersistentGameState.new()
	StoryModeNewGameInitializer.initialize(state)
	var controller := MeatspacePrologueController.new()
	controller.configure(load("res://data/authoring/story_prologue.tres"), state)
	var room := (load("res://ui/story_prologue/PlayerBedroom.tscn") as PackedScene).instantiate() as PlayerBedroom
	add_child(room); room.bind_state(state)
	var deck := room.objects[&"JACK_IN_INTERFACE"] as MeatspaceTarget3D
	var box := room.objects[&"STARTER_DECK_BOX"] as MeatspaceTarget3D
	var toolbox := room.objects[&"TOOLBOX"] as MeatspaceTarget3D
	_expect(not deck.visible and controller.progression_view().computer_state == &"NOT_PRESENT", "%s starts without a computer" % choice_id)
	_expect(controller.choose(&"DECK_CRATE", choice_id).success, "%s deck choice succeeds" % choice_id)
	_expect(deck.visible and deck.get_node("PartiallyAssembled").visible and not deck.get_node("Assembled").visible, "%s produces the exposed partial assembly" % choice_id)
	_expect(not box.visible, "%s removes the cardboard carton" % choice_id)
	_expect(not controller.choice_available({"cost_ics": null, "actions": []}) and not state.campaign_state.story_flags.get("DECK_ASSEMBLED", false), "unavailable toolbox work cannot complete assembly")
	var credits_before: int = int(state.player_state.credits)
	_expect(controller.choose(&"TOOLBOX", &"ASSEMBLE_DECK").success and state.campaign_state.story_flags.DECK_ASSEMBLED and state.player_state.credits == credits_before, "free assembly toolbox action explicitly completes assembly")
	_expect(not deck.get_node("PartiallyAssembled").visible and deck.get_node("Assembled").visible, "assembled enclosure and active display replace exposed parts")
	_expect(toolbox.get_meta("visual_profile", "").contains("handle_latches_seams") and toolbox.get_node("Lid/CarryHandle") != null, "toolbox has readable painted shell, handle, seams, and latches")
	_expect(box.get_meta("visual_profile", "").contains("cardboard_flaps_tape_corrugation") and box.get_node("Lid/TapeSeam") != null, "box has kraft carton, fold, tape, and corrugation cues")
	var backpack := (room.dressing[&"CHAIR_JACKET"].node as Node3D).get_node("LowPolyBackpack")
	_expect(backpack.get_meta("visual_profile", "").contains("straps_pocket_and_seams") and backpack.has_node("FrontPocket") and backpack.has_node("ShoulderStrapLeft"), "chair prop has a readable backpack silhouette, pocket, straps, and seams")
	_expect(_all_mesh_materials_local(room), "prop materials are packaged procedural resources with no runtime dependency")
	var restored := PersistentGameState.from_save_data(state.to_save_data())
	var returned := (load("res://ui/story_prologue/PlayerBedroom.tscn") as PackedScene).instantiate() as PlayerBedroom
	add_child(returned); returned.bind_state(restored)
	_expect(returned.objects[&"JACK_IN_INTERFACE"].get_node("Assembled").visible and not returned.objects[&"STARTER_DECK_BOX"].visible, "assembled deck and removed box persist across room reload")
	room.queue_free(); returned.queue_free(); await get_tree().process_frame

func _all_mesh_materials_local(room: PlayerBedroom) -> bool:
	for root in [room.objects[&"STARTER_DECK_BOX"], room.objects[&"TOOLBOX"], room.dressing[&"CHAIR_JACKET"].node]:
		for child in root.find_children("*", "MeshInstance3D", true, false):
			if (child as MeshInstance3D).material_override == null: return false
	return true

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
