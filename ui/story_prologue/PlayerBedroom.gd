class_name PlayerBedroom
extends MeatspaceRoomView3D
## Geometry only: authored definitions and the controller own all story behavior.
@export var definition: MeatspacePrologueDefinition = preload("res://data/authoring/story_prologue.tres")
var location_definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/meatspace/bedroom.json"))
var exterior: MeatspaceEnvironment3D
var display_anchors: Array[MeatspaceDisplayAnchor3D] = []
const WOOD := Color("655043")
const METAL := Color("303e46")
const POSTERS := {
	&"POSTER_VIRUS": preload("res://assets/meatspace/posters/poster_virus.png"),
	&"POSTER_PHREAKER": preload("res://assets/meatspace/posters/poster_phreaker.png"),
	&"POSTER_WAREZ": preload("res://assets/meatspace/posters/poster_warez.png"),
}

func _build_room() -> void:
	camera.position = Vector3(0, 4.3, 8.8)
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
	_block(world, Vector3(1.7, 1.35, 0.16), Vector3(2.35, 0.675, -3), Color("62665f"))
	_block(world, Vector3(1.7, 0.55, 0.16), Vector3(2.35, 3.025, -3), Color("62665f"))
	for x in [-3.6, 3.6]:
		_block(world, Vector3(0.16, 7.3, 12), Vector3(x, 3.65, 3), Color("505d60"))
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
	_sync_environment()

func _refresh_state() -> void:
	super._refresh_state()
	if exterior != null: exterior.apply_state(game_state)
	for anchor: MeatspaceDisplayAnchor3D in display_anchors: anchor.apply_state(game_state)

func _build_prop(data: Dictionary) -> void:
	var target := MeatspaceTarget3D.new()
	var kind := StringName(data.get("kind", &""))
	var pos := Vector3.ZERO
	var bounds := Vector3.ONE
	match kind:
		&"WINDOW": pos = Vector3(2.35, 1.35, -2.87); bounds = Vector3(1.7, 1.4, 0.12)
		&"DESK": pos = Vector3(0, 0, -2.35); bounds = Vector3(3.5, 1.0, 1.0)
		&"BED": pos = Vector3(-2.5, 0, -0.3); bounds = Vector3(1.65, 0.9, 2.9)
		&"BOX": pos = Vector3(-0.65, 0.99, -2.25); bounds = Vector3(0.8, 0.6, 0.65)
		&"TOOLBOX": pos = Vector3(0.5, 0.99, -2.25); bounds = Vector3(0.7, 0.45, 0.5)
		&"TABLE": pos = Vector3(2.55, 0, 1.25); bounds = Vector3(1.35, 1.25, 1.65)
		&"SHELF": pos = Vector3(3.1, 0, -0.65); bounds = Vector3(0.65, 2.4, 1.4)
		&"JACK": pos = Vector3(1.25, 0.99, -2.25); bounds = Vector3(0.6, 0.7, 0.55)
		&"POSTER":
			var index := [&"POSTER_VIRUS", &"POSTER_PHREAKER", &"POSTER_WAREZ"].find(StringName(data.id))
			pos = Vector3(-2.65 + index * 1.3, 1.95, -2.89)
			bounds = Vector3(1.05, 1.15, 0.035)
		_: target.free(); return
	target.configure(data, bounds)
	target.position = pos
	world.add_child(target)
	register_target(target)
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
				_block(lid, Vector3(0.24, 0.08, 0.07), Vector3(0, 0.06, d / 2), METAL)
			else:
				_block(lid, Vector3(0.12, 0.008, d), Vector3(0, 0.032, d / 2), Color("d5bd83"))
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
			_block(target, Vector3(0.6, 0.1, 0.5), Vector3(0, 0.05, 0), METAL)
			_block(target, Vector3(0.12, 0.3, 0.12), Vector3(0, 0.22, -0.1), METAL)
			_block(target, Vector3(0.58, 0.42, 0.16), Vector3(0, 0.44, -0.1), METAL)
			_block(target, Vector3(0.48, 0.32, 0.01), Vector3(0, 0.44, -0.01), Color("70b8a0"))
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
