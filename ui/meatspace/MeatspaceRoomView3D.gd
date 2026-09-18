class_name MeatspaceRoomView3D
extends Control
## Shared ray picking and read-only state adapter for any authored Meatspace room.
signal object_selected(object_data: Dictionary)
var objects: Dictionary = {}
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var hint: Label
var game_state: PersistentGameState
var pointer_position := Vector2.ZERO
var focused_id: StringName
var _focus_gesture_armed := true

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.current = true
	world.add_child(camera)
	hint = Label.new()
	hint.position = Vector2(18, 18)
	hint.custom_minimum_size = Vector2(340, 0)
	hint.size.x = 340
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.025, 0.035, 0.045, 0.94)
	tooltip_style.content_margin_left = 12
	tooltip_style.content_margin_right = 12
	tooltip_style.content_margin_top = 9
	tooltip_style.content_margin_bottom = 9
	hint.add_theme_stylebox_override("normal", tooltip_style)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 2)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	add_child(hint)
	mouse_exited.connect(_set_focus.bind(&""))
	resized.connect(_layout_objects)
	_build_room()
	_layout_objects()
	GameplayBindings.semantic_action_triggered.connect(_on_semantic_action)
	EventBus.game_domain_changed.connect(_on_domain_changed)
	if Game.game_domain == Game.GameDomain.MEATSPACE:
		GameplayBindings.set_context(GameplayBindings.Context.MEATSPACE)

func _build_room() -> void:
	pass

func _layout_objects() -> void:
	if camera == null: return
	var aspect := size.x / maxf(size.y, 1.0)
	camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(48.0) / 2.0) * maxf(1.0, 1.5 / aspect)))

func register_target(target: MeatspaceTarget3D) -> void:
	objects[target.object_id] = target
	target.selected.connect(_on_prop_selected)

func bind_state(state: PersistentGameState) -> void:
	if game_state != null and game_state.changed.is_connected(_refresh_state): game_state.changed.disconnect(_refresh_state)
	game_state = state
	if game_state != null: game_state.changed.connect(_refresh_state)
	_refresh_state()

func _exit_tree() -> void:
	if game_state != null and game_state.changed.is_connected(_refresh_state): game_state.changed.disconnect(_refresh_state)

func _refresh_state() -> void:
	for target: MeatspaceTarget3D in objects.values(): target.apply_state(game_state)
	_set_focus(focused_id if focused_id in get_object_ids() else &"")

func pick(screen_position: Vector2) -> MeatspaceTarget3D:
	if not Rect2(Vector2.ZERO, size).has_point(screen_position): return null
	var point := screen_position * Vector2(viewport.size) / size
	var origin := camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * 100.0, 1)
	query.collide_with_areas = true
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as MeatspaceTarget3D

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer_position = event.position
		var target := pick(event.position)
		_set_focus(target.object_id if target != null else &"")
		_place_hint(pointer_position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := pick(event.position)
		if target != null:
			grab_focus()
			_set_focus(target.object_id)
			target.activate()
		accept_event()
	elif event.is_action_pressed(&"ui_accept") and objects.has(focused_id):
		(objects[focused_id] as MeatspaceTarget3D).activate()
		accept_event()
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_left"):
		var ids := get_object_ids()
		if not ids.is_empty():
			var direction := 1 if event.is_action_pressed(&"ui_right") else -1
			_set_focus(ids[posmod(ids.find(focused_id) + direction, ids.size())])
		accept_event()

func _set_focus(id: StringName) -> void:
	focused_id = id
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if objects.has(id) else Control.CURSOR_ARROW
	hint.text = ""
	hint.hide()
	if objects.has(id):
		var data: Dictionary = objects[id].authored_data
		hint.text = "%s\n%s" % [String(data.get("display_name", id)), String(data.get("examine", data.get("description", "")))]
		if data.has("class_id") and game_state != null and bool(game_state.campaign_state.get("story_flags", {}).get("CLAN_SELECTED", false)):
			hint.text = "%s\n%s" % [data.display_name, "Your chosen clan." if game_state.player_state.get("player_class") == data.class_id else "Your clan choice is already committed."]
		if data.get("kind") == &"WINDOW" and game_state != null:
			var flags: Dictionary = game_state.campaign_state.get("story_flags", {})
			hint.text += " %s. Window %s." % [String(game_state.world_state.get("time_of_day", "NIGHT")).capitalize(), "open" if flags.get(data.visual_state.open, false) else "closed"]
		hint.visible = not hint.text.is_empty()
		_place_hint(pointer_position)

func _on_prop_selected(id: StringName) -> void:
	if objects.has(id): object_selected.emit(objects[id].authored_data.duplicate(true))

func get_object_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in objects:
		if objects[id].visible: ids.append(id)
	ids.sort()
	return ids

func focus_first() -> void:
	if not is_inside_tree() or not is_visible_in_tree(): return
	grab_focus()
	var ids := get_object_ids()
	if not ids.is_empty(): _set_focus(ids[0])

func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	var direction := GameplayBindings.focus_vector()
	if direction.length() < 0.3: _focus_gesture_armed = true
	elif _focus_gesture_armed:
		_focus_gesture_armed = false; focus_in_screen_direction(direction)

func focus_in_screen_direction(direction: Vector2) -> void:
	var candidates: Array[Dictionary] = []
	for id: StringName in get_object_ids():
		var target := objects[id] as MeatspaceTarget3D
		candidates.append({"id": id, "position": camera.unproject_position(target.global_position), "priority": float(target.authored_data.get("focus_priority", 0.0)), "enabled": target.visible})
	var next := DirectionalFocusSelector.choose(focused_id, direction, candidates)
	if next != &"":
		pointer_position = camera.unproject_position((objects[next] as MeatspaceTarget3D).global_position)
		_set_focus(next)

func _on_semantic_action(action_id: StringName) -> void:
	if not is_visible_in_tree(): return
	if action_id == &"primary_action" and objects.has(focused_id): (objects[focused_id] as MeatspaceTarget3D).activate()
	elif action_id == &"back_action": _set_focus(&"")

func _on_domain_changed(_previous: int, current: int) -> void:
	if current == Game.GameDomain.MEATSPACE and is_visible_in_tree():
		GameplayBindings.set_context(GameplayBindings.Context.MEATSPACE)

func _place_hint(cursor: Vector2) -> void:
	hint.custom_minimum_size.x = minf(340, maxf(1, size.x - 16))
	hint.size = Vector2(hint.custom_minimum_size.x, 0)
	var extent := hint.get_combined_minimum_size()
	extent.x = hint.size.x
	var pos := cursor + Vector2(16, 18)
	if pos.x + extent.x > size.x - 8: pos.x = cursor.x - extent.x - 16
	if pos.y + extent.y > size.y - 8: pos.y = cursor.y - extent.y - 18
	hint.position = pos.clamp(Vector2(8, 8), Vector2(maxf(8, size.x - extent.x - 8), maxf(8, size.y - extent.y - 8)))
