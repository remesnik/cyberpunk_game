class_name CompactMeatspaceLocation
extends MeatspaceRoomView3D

@export var location_id: StringName
@export var display_name := "CITY LOCATION"
@export var palette := Color("35505a")

func _build_room() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new(); settings.background_mode = Environment.BG_COLOR; settings.background_color = palette.darkened(0.72); settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; settings.ambient_light_color = palette.lightened(0.35); settings.ambient_light_energy = 0.85
	environment.environment = settings; world.add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-48, -28, 0); light.light_energy = 1.1; world.add_child(light)
	camera.position = Vector3(0, 3.2, 7.2)
	camera.look_at_from_position(camera.position, Vector3(0, 1.25, 0), Vector3.UP)
	_block(world, Vector3(8.0, 0.18, 6.0), Vector3(0, -0.09, 0), palette.darkened(0.55))
	_block(world, Vector3(8.0, 3.5, 0.18), Vector3(0, 1.75, -2.85), palette.darkened(0.4))
	_block(world, Vector3(2.5, 1.1, 0.8), Vector3(0.8, 0.55, -1.7), palette)
	_block(world, Vector3(1.4, 2.4, 0.25), Vector3(-2.45, 1.2, -2.65), palette.lightened(0.18))
	for index in 4:
		_block(world, Vector3(0.45, 0.8 + index * 0.18, 0.45), Vector3(-1.0 + index * 0.72, (0.8 + index * 0.18) * 0.5, 0.4), palette.lightened(0.08 * index))
	var exit := MeatspaceTarget3D.new()
	exit.configure({
		"id": &"TRAVEL_EXIT",
		"display_name": "Exit",
		"examine": "Return home.",
		"kind": &"DOOR",
		"primary_action": &"TRAVEL",
	}, Vector3(1.35, 2.4, 0.35))
	exit.position = Vector3(-2.45, 0, -2.45)
	world.add_child(exit)
	register_target(exit)

func _block(parent: Node3D, dimensions: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = dimensions; instance.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.82
	instance.material_override = material; instance.position = position; parent.add_child(instance)
	return instance
