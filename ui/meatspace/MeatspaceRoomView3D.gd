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
var focused_id: StringName

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
	hint.position = Vector2(12, 12)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 2)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	add_child(hint)
	mouse_exited.connect(_set_focus.bind(&""))
	resized.connect(_layout_objects)
	_build_room()
	_layout_objects()

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
	var flags: Dictionary = game_state.campaign_state.get("story_flags", {}) if game_state != null else {}
	for target: MeatspaceTarget3D in objects.values(): target.apply_state(flags)

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
		var target := pick(event.position)
		_set_focus(target.object_id if target != null else &"")
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
	if objects.has(id):
		var data: Dictionary = objects[id].authored_data
		hint.text = "%s  %s" % [data.get("display_name", id), data.get("interaction_text", "")]

func _on_prop_selected(id: StringName) -> void:
	if objects.has(id): object_selected.emit(objects[id].authored_data.duplicate(true))

func get_object_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in objects: ids.append(id)
	ids.sort()
	return ids

func focus_first() -> void:
	grab_focus()
	var ids := get_object_ids()
	if not ids.is_empty(): _set_focus(ids[0])
