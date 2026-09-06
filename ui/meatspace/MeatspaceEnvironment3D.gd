class_name MeatspaceEnvironment3D
extends Node3D
## Reusable exterior, time profile, audio portal and entry-relative event view.
var definition: Dictionary
var environment: Environment
var events: MeatspaceEnvironmentEvents
var train: Node3D
var neon: Node3D
var city_audio: AudioStreamPlayer
var utility_audio: AudioStreamPlayer
var train_audio: AudioStreamPlayer
var bus_name: StringName
var lowpass: AudioEffectLowPassFilter
var current_time := "NIGHT"
var window_open := false
var active := false
var profile: Dictionary = {}

func configure(source: Dictionary, target_environment: Environment) -> void:
	definition = source
	environment = target_environment
	bus_name = StringName("MeatspaceExterior_%s" % get_instance_id())
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, bus_name)
	lowpass = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(bus, lowpass)
	city_audio = _audio(String(source.audio.city), true)
	utility_audio = _audio(String(source.audio.utility), true)
	train_audio = _audio(String(source.audio.train), false)
	events = MeatspaceEnvironmentEvents.new()
	events.definitions = source.get("events", [])
	add_child(events)
	events.event_started.connect(_event_started)
	events.event_progress.connect(_event_progress)
	events.event_finished.connect(_event_finished)
	_build_exterior()
	apply_state(null)

func _audio(path: String, loop: bool) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := load(path) as AudioStreamWAV
	if stream != null:
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
	player.stream = stream
	player.bus = bus_name
	add_child(player)
	return player

func set_active(value: bool) -> void:
	if active == value: return
	active = value
	if active:
		city_audio.play()
		utility_audio.play()
		events.enter()
	else:
		events.leave()
		city_audio.stop()
		utility_audio.stop()
		train_audio.stop()

func apply_state(state: PersistentGameState) -> void:
	current_time = String(state.world_state.get("time_of_day", "NIGHT")) if state != null else "NIGHT"
	profile = definition.profiles.get(current_time, definition.profiles.NIGHT)
	var flags: Dictionary = state.campaign_state.get("story_flags", {}) if state != null else {}
	window_open = bool(flags.get(definition.get("window_flag", ""), false))
	environment.background_color = Color(String(profile.sky))
	environment.ambient_light_color = Color(String(profile.ambient))
	environment.ambient_light_energy = float(profile.energy)
	neon.visible = bool(profile.neon)
	lowpass.cutoff_hz = 18000 if window_open else 850
	var attenuation := 0.0 if window_open else -9.0
	city_audio.volume_db = float(profile.city_db) + attenuation
	utility_audio.volume_db = float(profile.utility_db) + attenuation
	train_audio.volume_db = -17.0 + attenuation

func _build_exterior() -> void:
	neon = Node3D.new()
	add_child(neon)
	for row in range(3):
		for i in range(11):
			var height := 2.5 + float((i * 7 + row * 3) % 9) * 0.55
			var x := -13.0 + i * 2.6 + row * 0.7
			var z := -7.0 - row * 4
			block(self, Vector3(2.1, height, 2), Vector3(x, height / 2 - 1, z), Color("354552").lightened(row * 0.06))
			block(self, Vector3(0.7, 0.45, 0.6), Vector3(x, height - 0.78, z), Color("626c73"))
			for floor_index in range(4):
				for column in range(3):
					block(neon, Vector3(0.22, 0.3, 0.02), Vector3(x - 0.65 + column * 0.6, floor_index * 0.7 + 0.2, z + 1.02), Color("e8c278"), true)
			if i % 3 == 0:
				block(neon, Vector3(0.25, 1.6, 0.05), Vector3(x + 0.8, height - 2, z + 1.08), Color("ef599c"), true)
	block(self, Vector3(25, 0.12, 0.7), Vector3(0, 0.95, -4.8), Color("505761"))
	train = Node3D.new()
	add_child(train)
	for car in range(3):
		block(train, Vector3(1.7, 0.65, 0.55), Vector3(car * 1.85, 0, 0), Color("929d9e"))
		for pane in range(4): block(train, Vector3(0.25, 0.25, 0.02), Vector3(car * 1.85 - 0.6 + pane * 0.38, 0.1, 0.29), Color("d6dfb3"), true)
	train.visible = false

func _event_started(id: StringName) -> void:
	if id == &"TRAIN":
		train.visible = true
		train_audio.play()

func _event_progress(id: StringName, progress: float) -> void:
	if id == &"TRAIN": train.position = Vector3(lerpf(-2, 6, progress), 1.5, -4.8)

func _event_finished(id: StringName) -> void:
	if id == &"TRAIN":
		train.visible = false
		train_audio.stop()

func _exit_tree() -> void:
	set_active(false)
	for player in [city_audio, utility_audio, train_audio]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	var bus := AudioServer.get_bus_index(bus_name)
	if bus > 0: AudioServer.remove_bus(bus)

static func block(parent: Node3D, dimensions: Vector3, pos: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	material.emission_enabled = emissive
	material.emission = color if emissive else Color.BLACK
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance
