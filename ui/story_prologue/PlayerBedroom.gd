class_name PlayerBedroom
extends MeatspaceRoomView3D
const FirstMeatspaceTutorial = preload("res://core/story/FirstMeatspaceTutorial.gd")
## Geometry only: authored definitions and the controller own all story behavior.
@export var definition: MeatspacePrologueDefinition = preload("res://data/authoring/story_prologue.tres")
var location_definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/meatspace/bedroom.json"))
var exterior: MeatspaceEnvironment3D
var display_anchors: Array[MeatspaceDisplayAnchor3D] = []
var dressing: Dictionary = {}
var onboarding_prompt: Label
var onboarding_emphasis: Node3D
var tutorial_step := FirstMeatspaceTutorial.Step.COMPLETE
const WOOD := Color("655043")
const METAL := Color("303e46")
const POSTERS := {
	&"POSTER_VIRUS": preload("res://assets/meatspace/posters/poster_virus.png"),
	&"POSTER_PHREAKER": preload("res://assets/meatspace/posters/poster_phreaker.png"),
	&"POSTER_WAREZ": preload("res://assets/meatspace/posters/poster_warez.png"),
}

func _build_room() -> void:
	camera.position = Vector3(-1.2, 3.9, 7.8)
	camera.look_at(Vector3(0, 1.2, -0.5))
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("111922")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("9cafc8")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	world.add_child(environment)
	var light := OmniLight3D.new()
	light.position = Vector3(-1, 3.8, 1.5)
	light.light_color = Color("ffe0af")
	light.light_energy = 2.0
	light.omni_range = 12
	light.shadow_enabled = true
	world.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(2, 2.5, -1)
	fill.light_color = Color("83c6dc")
	fill.light_energy = 0.7
	fill.omni_range = 6
	world.add_child(fill)
	_block(world, Vector3(7.2, 0.18, 12), Vector3(0, -0.09, 3), Color("403c39"))
	# Continue the enclosure beyond the camera frustum: the city is seen through
	# the window, rather than around the edges of a floating room model.
	_block(world, Vector3(7.2, 4, 0.16), Vector3(0, 5.3, -3), Color("62665f"))
	# Four solid segments leave a genuine aperture for the exterior set.
	_block(world, Vector3(5.1, 3.3, 0.16), Vector3(-1.05, 1.65, -3), Color("62665f"))
	_block(world, Vector3(0.4, 3.3, 0.16), Vector3(3.4, 1.65, -3), Color("62665f"))
	_block(world, Vector3(1.7, 1.1, 0.16), Vector3(2.35, 0.55, -3), Color("62665f"))
	_block(world, Vector3(1.7, 0.2, 0.16), Vector3(2.35, 3.2, -3), Color("62665f"))
	for x in [-3.6, 3.6]:
		if x < 0:
			_block(world, Vector3(0.16, 7.3, 12), Vector3(x, 3.65, 3), Color("505d60"))
		else:
			for segment in [Vector3(-1.5, 3.0, 3.0), Vector3(5.8, 6.4, 3.0)]:
				_block(world, Vector3(0.16, 7.3, segment.y), Vector3(x, 3.65, segment.x), Color("505d60"))
			_block(world, Vector3(0.16, 1.1, 2.6), Vector3(x, 0.55, 1.3), Color("505d60"))
			_block(world, Vector3(0.16, 4.2, 2.6), Vector3(x, 5.2, 1.3), Color("505d60"))
		_block(world, Vector3(0.05, 0.14, 12), Vector3(x * 0.97, 0.07, 3), WOOD)
	for z in range(-5, 6):
		_block(world, Vector3(7, 0.006, 0.012), Vector3(0, 0.005, z * 0.5), Color("272c2c"))
	_block(world, Vector3(2.6, 0.02, 2.2), Vector3(0, 0.02, 0.6), Color("3b5356"))
	if definition == null: return
	for source: Dictionary in definition.room_objects:
		var data := source.duplicate(true)
		data.merge(location_definition.objects.get(String(data.id), {}), true)
		_build_prop(data)
	var window_data: Dictionary = location_definition.objects.WINDOW.duplicate(true)
	window_data.merge({"id": &"WINDOW", "kind": &"WINDOW", "display_name": "WINDOW", "interaction_text": "[ EXAMINE ]"})
	_build_prop(window_data)
	_build_prop(location_definition.objects.WINDOW_TABLE)
	var door_data: Dictionary = location_definition.objects.DOOR.duplicate(true)
	door_data["id"] = &"DOOR"
	_build_prop(door_data)
	_build_chair()
	_build_dressing()
	_build_onboarding_cue()
	exterior = MeatspaceEnvironment3D.new()
	world.add_child(exterior)
	exterior.configure(location_definition.environment, settings)
	visibility_changed.connect(_sync_environment)
	_refresh_state()
	_sync_environment()

func _sync_environment() -> void:
	if exterior != null: exterior.set_active(is_visible_in_tree() and game_state != null)

func bind_state(state: PersistentGameState) -> void:
	if exterior != null and state != game_state: exterior.set_active(false)
	super.bind_state(state)
	_refresh_onboarding()
	_sync_environment()

func _refresh_state() -> void:
	super._refresh_state()
	if exterior != null: exterior.apply_state(game_state)
	for anchor: MeatspaceDisplayAnchor3D in display_anchors: anchor.apply_state(game_state)
	_refresh_dressing()
	_refresh_onboarding()

func _build_dressing() -> void:
	for entry: Dictionary in location_definition.get("dressing", []):
		var holder := Node3D.new()
		holder.name = String(entry.id)
		var p: Array = entry.position
		holder.position = Vector3(p[0], p[1], p[2])
		world.add_child(holder)
		MeatspaceDisplayAnchor3D.build_item(holder, entry.get("item", {}))
		dressing[StringName(entry.id)] = {"node": holder, "definition": entry}

func _refresh_dressing() -> void:
	var flags: Dictionary = game_state.campaign_state.get("story_flags", {}) if game_state != null else {}
	var inventory: Array = game_state.player_state.get("inventory", []) if game_state != null else []
	var hardware: Dictionary = game_state.player_state.get("hardware", {}) if game_state != null else {}
	for record: Dictionary in dressing.values():
		var entry: Dictionary = record.definition
		var shown := game_state != null and StoryBindingEvaluator.visible(entry, game_state)
		if entry.has("when_flag"): shown = shown and bool(flags.get(entry.when_flag, false)) == bool(entry.get("equals", true))
		if entry.has("inventory_id"):
			shown = shown and inventory.any(func(value: Variant) -> bool: return (value is Dictionary and String(value.get("id", "")) == String(entry.inventory_id)) or String(value) == String(entry.inventory_id))
		if entry.has("hardware_id"): shown = shown and int(hardware.get(entry.hardware_id, 0)) >= int(entry.get("minimum_level", 2))
		if entry.get("requires_unread", false): shown = shown and not game_state.world_state.get("social_inbox", {}).get("messages", []).filter(func(message: Dictionary) -> bool: return not bool(message.get("read", false))).is_empty()
		(record.node as Node3D).visible = shown

func _build_prop(data: Dictionary) -> void:
	var target := MeatspaceTarget3D.new()
	var kind := StringName(data.get("kind", &""))
	var pos := Vector3.ZERO
	var bounds := Vector3.ONE
	match kind:
		&"WINDOW":
			pos = Vector3(3.48, 1.1, 1.3) if data.id == "WINDOW_TABLE" else Vector3(2.35, 1.1, -2.87)
			bounds = Vector3(1.7, 1.4, 0.12)
		&"DESK": pos = Vector3(0, 0, -2.35); bounds = Vector3(3.5, 1.0, 1.0)
		&"BED": pos = Vector3(-2.5, 0, -0.3); bounds = Vector3(1.65, 0.9, 2.9)
		&"BOX": pos = Vector3(-0.65, 0.99, -2.25); bounds = Vector3(0.8, 0.6, 0.65)
		&"TOOLBOX": pos = Vector3(0.5, 0.99, -2.25); bounds = Vector3(0.7, 0.45, 0.5)
		&"TABLE": pos = Vector3(2.55, 0, 1.25); bounds = Vector3(1.35, 1.25, 1.65)
		&"SHELF": pos = Vector3(3.1, 0, -0.65); bounds = Vector3(0.65, 2.4, 1.4)
		&"JACK": pos = Vector3(1.25, 0.99, -2.25); bounds = Vector3(0.6, 0.7, 0.55)
		&"DOOR": pos = Vector3(-3.48, 0, 2.55); bounds = Vector3(1.15, 2.35, 0.16)
		&"POSTER":
			var index := [&"POSTER_VIRUS", &"POSTER_PHREAKER", &"POSTER_WAREZ"].find(StringName(data.id))
			pos = Vector3(-2.65 + index * 1.3, 1.95, -2.89)
			bounds = Vector3(1.05, 1.15, 0.035)
		_: target.free(); return
	target.configure(data, bounds)
	target.position = pos
	world.add_child(target)
	register_target(target)
	if kind == &"WINDOW":
		target.scale.y = 2.0 / 1.4
		if data.id == "WINDOW_TABLE":
			target.rotation_degrees.y = -90
			target.scale.x = 2.6 / 1.7
	match kind:
		&"WINDOW":
			for x in [-0.85, 0.85]: _block(target, Vector3(0.08, 1.5, 0.18), Vector3(x, 0.7, 0), WOOD)
			for y in [0, 1.4]: _block(target, Vector3(1.8, 0.08, 0.22), Vector3(0, y, 0), WOOD)
			var sash := Node3D.new()
			sash.name = "Sash"
			target.add_child(sash)
			for x in [-0.77, 0.77]: _block(sash, Vector3(0.035, 1.32, 0.05), Vector3(x, 0.7, 0), METAL)
			for y in [0.06, 1.34]: _block(sash, Vector3(1.55, 0.035, 0.05), Vector3(0, y, 0), METAL)
			var glass := _block(sash, Vector3(1.5, 1.26, 0.015), Vector3(0, 0.7, 0), Color(0.5, 0.7, 0.8, 0.12))
			(glass.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			target.bind_visual(sash, &"rotation_degrees", &"open", Vector3.ZERO, Vector3(-22, 0, 0))
			for i in range(9):
				var slat := _block(target, Vector3(1.55, 0.025, 0.10), Vector3(0, 0.18 + i * 0.14, 0.12), Color("b5b39b"))
				slat.rotation_degrees.x = -15
				target.bind_visual(slat, &"rotation_degrees", &"blinds", Vector3(-15, 0, 0), Vector3(70, 0, 0))
			_block(target, Vector3(0.014, 1.35, 0.014), Vector3(0.6, 0.7, 0.17), Color("ded7b7"))
		&"DESK": _table(target, Vector3.ZERO, Vector3(3.5, 0.95, 1.0))
		&"BED":
			_block(target, Vector3(1.55, 0.35, 2.8), Vector3(0, 0.3, 0), WOOD)
			_block(target, Vector3(1.5, 0.24, 2.7), Vector3(0, 0.58, 0), Color("b7b5a1"))
			_block(target, Vector3(1.53, 0.1, 1.85), Vector3(0, 0.75, 0.36), Color("435967"))
			_block(target, Vector3(1.12, 0.17, 0.5), Vector3(0, 0.79, -0.92), Color("d8ccaf"))
			_block(target, Vector3(1.65, 1.0, 0.12), Vector3(0, 0.5, -1.4), WOOD)
		&"BOX", &"TOOLBOX":
			var color := Color("aa8051") if kind == &"BOX" else Color("813f35")
			target.set_meta("visual_profile", "kraft_cardboard_flaps_tape_corrugation" if kind == &"BOX" else "painted_toolbox_handle_latches_seams_wear")
			var w := bounds.x
			var d := bounds.z
			var h := bounds.y * 0.8
			_block(target, Vector3(w, 0.05, d), Vector3(0, 0.025, 0), color.darkened(0.4))
			for x in [-w / 2, w / 2]: _block(target, Vector3(0.04, h, d), Vector3(x, h / 2, 0), color)
			for z in [-d / 2, d / 2]: _block(target, Vector3(w, h, 0.04), Vector3(0, h / 2, z), color)
			var lid := Node3D.new()
			lid.name = "Lid"
			target.add_child(lid)
			lid.position = Vector3(0, h, -d / 2)
			_block(lid, Vector3(w + 0.04, 0.055, d), Vector3(0, 0, d / 2), color)
			if kind == &"TOOLBOX":
				var handle_root := Node3D.new(); handle_root.name = "CarryHandle"; lid.add_child(handle_root)
				_block(handle_root, Vector3(0.28, 0.045, 0.055), Vector3(0, 0.14, d / 2), METAL)
				for x in [-0.14, 0.14]: _block(handle_root, Vector3(0.045, 0.16, 0.055), Vector3(x, 0.07, d / 2), METAL)
				for x in [-0.2, 0.2]:
					var latch := _block(target, Vector3(0.1, 0.13, 0.035), Vector3(x, h * 0.63, d / 2 + 0.025), Color("b7aaa0")); latch.name = "Latch"
				var seam := _block(target, Vector3(w + 0.03, 0.025, 0.025), Vector3(0, h * 0.72, d / 2 + 0.026), Color("4c2522")); seam.name = "LidSeam"
				for x in [-w * 0.42, w * 0.42]: _block(target, Vector3(0.035, h * 0.7, 0.018), Vector3(x, h * 0.38, d / 2 + 0.027), Color("c37a64"))
			else:
				var tape := _block(lid, Vector3(0.14, 0.012, d + 0.02), Vector3(0, 0.035, d / 2), Color("d9bd7c")); tape.name = "TapeSeam"
				for x in [-w * 0.32, w * 0.32]:
					for y in range(4):
						var flute := _block(target, Vector3(0.012, 0.012, d + 0.01), Vector3(x + y * 0.018, h + 0.003, 0), Color("765334")); flute.name = "Corrugation"
			target.bind_visual(lid, &"rotation_degrees", &"open", Vector3.ZERO, Vector3(-110, 0, 0))
			if kind == &"BOX":
				var contents := Node3D.new()
				contents.name = "Contents"
				target.add_child(contents)
				var index := 0
				for item: Dictionary in data.get("contents", []):
					var model := MeatspaceDisplayAnchor3D.build_item(contents, item)
					model.position = Vector3(-0.18 + index * 0.32, 0.16, 0)
					index += 1
				target.bind_visual(contents, &"visible", &"empty", true, false)
		&"TABLE":
			_table(target, Vector3.ZERO, Vector3(1.35, 0.95, 1.65))
			for anchor_data: Dictionary in data.get("display_anchors", []):
				var anchor := MeatspaceDisplayAnchor3D.new()
				anchor.location_id = StringName(location_definition.id)
				anchor.anchor_id = StringName("%s/%s" % [data.id, anchor_data.id])
				anchor.name = String(anchor_data.id)
				var p: Array = anchor_data.position
				anchor.position = Vector3(p[0], p[1], p[2])
				anchor.authored_fallbacks = anchor_data.get("fallbacks", [])
				target.add_child(anchor)
				display_anchors.append(anchor)
		&"SHELF":
			for z in [-0.8, 0.8]: _block(target, Vector3(0.65, 2.4, 0.08), Vector3(0, 1.2, z), WOOD)
			_block(target, Vector3(0.06, 2.4, 1.6), Vector3(0.3, 1.2, 0), WOOD.darkened(0.2))
			for y in [0.12, 0.72, 1.32, 1.92, 2.4]:
				_block(target, Vector3(0.65, 0.07, 1.6), Vector3(0, y, 0), WOOD)
				if y > 2: continue
				for i in range(7):
					_block(target, Vector3(0.44, 0.32 + (i % 3) * 0.06, 0.12), Vector3(-0.06, y + 0.23, -0.62 + i * 0.2), Color("8f7354").darkened((i % 3) * 0.17))
		&"JACK":
			target.set_meta("state_model", "NOT_PRESENT/PARTIALLY_ASSEMBLED/ASSEMBLED")
			var partial := Node3D.new(); partial.name = "PartiallyAssembled"; target.add_child(partial)
			_block(partial, Vector3(0.6, 0.08, 0.5), Vector3(0, 0.04, 0), METAL)
			var board := _block(partial, Vector3(0.49, 0.035, 0.38), Vector3(0, 0.095, 0), Color("416d59")); board.name = "ExposedBoard"
			for x in [-0.16, 0.0, 0.16]: _block(partial, Vector3(0.08, 0.045, 0.12), Vector3(x, 0.13, -0.04), Color("242d31"))
			var loose := _block(partial, Vector3(0.42, 0.025, 0.035), Vector3(0.08, 0.16, 0.19), Color("d8a94a")); loose.name = "LooseCable"; loose.rotation_degrees.y = -18
			var removed_cover := _block(partial, Vector3(0.55, 0.025, 0.42), Vector3(-0.42, 0.06, 0), METAL.lightened(0.08)); removed_cover.name = "RemovedCover"; removed_cover.rotation_degrees.z = 72
			var assembled := Node3D.new(); assembled.name = "Assembled"; target.add_child(assembled)
			_block(assembled, Vector3(0.6, 0.14, 0.5), Vector3(0, 0.07, 0), METAL)
			_block(assembled, Vector3(0.12, 0.3, 0.12), Vector3(0, 0.27, -0.1), METAL)
			_block(assembled, Vector3(0.58, 0.42, 0.16), Vector3(0, 0.49, -0.1), METAL)
			var screen := _block(assembled, Vector3(0.48, 0.32, 0.01), Vector3(0, 0.49, -0.01), Color("70b8a0")); screen.name = "ActiveDisplay"
			target.bind_visual(partial, &"visible", &"assembled", true, false)
			target.bind_visual(assembled, &"visible", &"assembled", false, true)
		&"POSTER":
			var mesh := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(bounds.x, bounds.y)
			mesh.mesh = quad
			mesh.position.y = bounds.y / 2
			var material := StandardMaterial3D.new()
			material.albedo_texture = POSTERS.get(StringName(data.id))
			material.roughness = 1.0
			mesh.material_override = material
			target.add_child(mesh)
			var selected := Node3D.new()
			selected.name = "SelectedClass"
			target.add_child(selected)
			for x in [-0.55, 0.55]: _block(selected, Vector3(0.025, 1.2, 0.02), Vector3(x, 0.575, 0.02), Color("edc96d"))
			for y in [-0.025, 1.175]: _block(selected, Vector3(1.125, 0.025, 0.02), Vector3(0, y, 0.02), Color("edc96d"))
			var badge := Label3D.new()
			badge.text = "SELECTED"
			badge.font_size = 32
			badge.pixel_size = 0.004
			badge.position = Vector3(0, -0.11, 0.035)
			selected.add_child(badge)
			target.bind_visual(selected, &"visible", &"selected", false, true)
		&"DOOR":
			target.rotation_degrees.y = 90
			_block(target, Vector3(1.15, 2.3, 0.12), Vector3(0, 1.15, 0), Color("776b5e"))
			for x in [-0.62, 0.62]: _block(target, Vector3(0.08, 2.45, 0.18), Vector3(x, 1.22, 0), WOOD.darkened(0.18))
			_block(target, Vector3(1.32, 0.08, 0.18), Vector3(0, 2.43, 0), WOOD.darkened(0.18))
			var knob := MeshInstance3D.new()
			var knob_mesh := SphereMesh.new(); knob_mesh.radius = 0.055; knob_mesh.height = 0.11
			knob.mesh = knob_mesh; knob.position = Vector3(0.42, 1.08, 0.1)
			var knob_material := StandardMaterial3D.new(); knob_material.albedo_color = Color("b8a36b"); knob.material_override = knob_material
			target.add_child(knob)

func _build_onboarding_cue() -> void:
	onboarding_prompt = Label.new()
	onboarding_prompt.name = "BedroomOnboardingPrompt"
	onboarding_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	onboarding_prompt.position = Vector2(-270, -116)
	onboarding_prompt.custom_minimum_size = Vector2(540, 48)
	onboarding_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	onboarding_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	onboarding_prompt.add_theme_color_override("font_color", Color("eef8f5"))
	var style := StyleBoxFlat.new(); style.bg_color = Color(0.02, 0.035, 0.045, 0.86); style.corner_radius_top_left = 5; style.corner_radius_top_right = 5; style.corner_radius_bottom_left = 5; style.corner_radius_bottom_right = 5
	onboarding_prompt.add_theme_stylebox_override("normal", style)
	onboarding_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(onboarding_prompt)
	onboarding_emphasis = Node3D.new()
	onboarding_emphasis.name = "OnboardingEmphasis"
	var light := OmniLight3D.new(); light.name = "SoftPulse"; light.light_color = Color("e7c45b"); light.light_energy = 0.55; light.omni_range = 1.35; light.position = Vector3(0, 0.5, 0)
	onboarding_emphasis.add_child(light)
	(objects[&"STARTER_DECK_BOX"] as MeatspaceTarget3D).add_child(onboarding_emphasis)
	GameplayBindings.device_mode_changed.connect(_on_onboarding_device_changed)
	_on_onboarding_device_changed(GameplayBindings.device_mode)

func _refresh_onboarding() -> void:
	tutorial_step = FirstMeatspaceTutorial.reconcile(game_state)
	if onboarding_prompt == null or onboarding_emphasis == null: return
	onboarding_prompt.visible = tutorial_step < FirstMeatspaceTutorial.Step.ENTER_CLEAN_ROOM
	_on_onboarding_device_changed(GameplayBindings.device_mode)
	var target_id: StringName = &""
	if tutorial_step in [FirstMeatspaceTutorial.Step.LOOK_AROUND, FirstMeatspaceTutorial.Step.INSPECT_OBJECT, FirstMeatspaceTutorial.Step.OPEN_BOX, FirstMeatspaceTutorial.Step.CHOOSE_DECK]: target_id = &"STARTER_DECK_BOX"
	elif tutorial_step == FirstMeatspaceTutorial.Step.USE_TOOLBOX: target_id = &"TOOLBOX"
	elif tutorial_step == FirstMeatspaceTutorial.Step.USE_COMPUTER: target_id = &"JACK_IN_INTERFACE"
	set_tutorial_emphasis(target_id, target_id != &"")

func set_tutorial_emphasis(target_id: StringName, enabled: bool) -> void:
	if onboarding_emphasis == null: return
	onboarding_emphasis.visible = enabled and objects.has(target_id) and (objects[target_id] as MeatspaceTarget3D).visible
	if not onboarding_emphasis.visible: return
	var target := objects[target_id] as MeatspaceTarget3D
	if onboarding_emphasis.get_parent() != target: onboarding_emphasis.reparent(target, false)
	onboarding_emphasis.position = Vector3(0, 0.5, 0)
	onboarding_emphasis.set_meta("target_id", target_id)

func _advance_tutorial(step: FirstMeatspaceTutorial.Step) -> void:
	tutorial_step = FirstMeatspaceTutorial.advance_to(game_state, step)
	_refresh_onboarding()

func _on_onboarding_device_changed(mode: int) -> void:
	if onboarding_prompt == null: return
	var gamepad := mode == GameplayBindings.DeviceMode.GAMEPAD
	match tutorial_step:
		FirstMeatspaceTutorial.Step.LOOK_AROUND: onboarding_prompt.text = "Use the Right Stick or D-pad to select an object." if gamepad else "Move the cursor over an object to examine it."
		FirstMeatspaceTutorial.Step.INSPECT_OBJECT, FirstMeatspaceTutorial.Step.OPEN_BOX: onboarding_prompt.text = "Press A / Cross to interact." if gamepad else "Click to interact."
		FirstMeatspaceTutorial.Step.CHOOSE_DECK: onboarding_prompt.text = "Choose your starter deck direction."
		FirstMeatspaceTutorial.Step.USE_TOOLBOX: onboarding_prompt.text = "Finish assembling the deck."
		FirstMeatspaceTutorial.Step.USE_COMPUTER: onboarding_prompt.text = "Connect to your deck."
		_: onboarding_prompt.text = ""

func _gui_input(event: InputEvent) -> void:
	if tutorial_step == FirstMeatspaceTutorial.Step.LOOK_AROUND and event is InputEventMouseMotion and pick(event.position) != null: _advance_tutorial(FirstMeatspaceTutorial.Step.INSPECT_OBJECT)
	super._gui_input(event)

func focus_in_screen_direction(direction: Vector2) -> void:
	var previous := focused_id
	super.focus_in_screen_direction(direction)
	if tutorial_step == FirstMeatspaceTutorial.Step.LOOK_AROUND and focused_id != &"" and focused_id != previous: _advance_tutorial(FirstMeatspaceTutorial.Step.INSPECT_OBJECT)

func _on_prop_selected(id: StringName) -> void:
	if id == &"STARTER_DECK_BOX" and tutorial_step <= FirstMeatspaceTutorial.Step.INSPECT_OBJECT: _advance_tutorial(FirstMeatspaceTutorial.Step.OPEN_BOX)
	elif id == &"JACK_IN_INTERFACE" and tutorial_step == FirstMeatspaceTutorial.Step.USE_COMPUTER: _advance_tutorial(FirstMeatspaceTutorial.Step.ENTER_CLEAN_ROOM)
	super._on_prop_selected(id)

func _process(delta: float) -> void:
	super._process(delta)
	if tutorial_step < FirstMeatspaceTutorial.Step.ENTER_CLEAN_ROOM and onboarding_emphasis != null and onboarding_emphasis.visible:
		var light := onboarding_emphasis.get_node_or_null("SoftPulse") as OmniLight3D
		if light != null: light.light_energy = 0.48 + sin(Time.get_ticks_msec() * 0.003) * 0.12

func _table(parent: Node3D, pos: Vector3, dimensions: Vector3) -> void:
	_block(parent, Vector3(dimensions.x, 0.1, dimensions.z), pos + Vector3(0, dimensions.y, 0), WOOD)
	for x in [-1, 1]:
		for z in [-1, 1]:
			_block(parent, Vector3(0.09, dimensions.y, 0.09), pos + Vector3(x * (dimensions.x / 2 - 0.12), dimensions.y / 2, z * (dimensions.z / 2 - 0.12)), METAL)

func _block(parent: Node3D, dimensions: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance

func _build_chair() -> void:
	var chair := Node3D.new()
	chair.name = "MustardWingChair"
	world.add_child(chair)
	chair.position = Vector3(2.6, 0, 3.1)
	chair.rotation_degrees.y = -90
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("bd942f")
	cloth.roughness = 0.96
	var noise := FastNoiseLite.new()
	noise.frequency = 0.075
	var fabric := NoiseTexture2D.new()
	fabric.width = 128
	fabric.height = 128
	fabric.noise = noise
	var gradient := Gradient.new()
	gradient.set_color(0, Color("a89368"))
	gradient.set_color(1, Color("eee1ba"))
	fabric.color_ramp = gradient
	cloth.albedo_texture = fabric
	_cushion(chair, Vector3(1.08, 0.3, 0.95), Vector3(0, 0.48, 0), cloth)
	var seat := _cushion(chair, Vector3(0.86, 0.23, 0.82), Vector3(-0.025, 0.65, 0.065), cloth)
	seat.rotation_degrees.z = -1.5
	var back := _cushion(chair, Vector3(0.97, 1.2, 0.35), Vector3(0, 1.13, -0.36), cloth)
	back.rotation_degrees.x = -8
	_cushion(chair, Vector3(0.78, 0.9, 0.22), Vector3(0, 1.13, -0.15), cloth)
	for x in [-0.51, 0.51]:
		_cushion(chair, Vector3(0.22, 0.5, 0.78), Vector3(x, 0.72, 0.03), cloth)
		_cushion(chair, Vector3(0.29, 0.23, 0.9), Vector3(x, 0.94, 0.05), cloth)
		var wing := _cushion(chair, Vector3(0.25, 0.79, 0.55), Vector3(x * 0.88, 1.37, -0.18), cloth)
		wing.rotation_degrees.z = -signf(x) * 9
		for z in [-0.32, 0.32]:
			var leg := MeshInstance3D.new()
			var shape := CylinderMesh.new()
			shape.top_radius = 0.055
			shape.bottom_radius = 0.035
			shape.height = 0.36
			shape.radial_segments = 8
			leg.mesh = shape
			var wood := StandardMaterial3D.new()
			wood.albedo_color = WOOD.darkened(0.35)
			leg.material_override = wood
			leg.position = Vector3(x * 0.78, 0.19, z)
			leg.rotation_degrees.z = -signf(x) * 6
			chair.add_child(leg)
	# Recessed fabric buttons and worn cushion piping, no collision targets.
	var seam := cloth.duplicate() as StandardMaterial3D
	seam.albedo_color = Color("997a35")
	for x in [-0.22, 0.22]:
		for y in [1.02, 1.36]: _cushion(chair, Vector3(0.045, 0.045, 0.018), Vector3(x, y, -0.037), seam)
	_cushion(chair, Vector3(0.73, 0.022, 0.025), Vector3(-0.025, 0.645, 0.465), seam)

func _cushion(parent: Node3D, dimensions: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.scale = dimensions
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance
