class_name MeatspaceEnvironment3D
extends Node3D
## Reusable exterior, time profile, audio portal and entry-relative event view.
var definition: Dictionary
var environment: Environment
var events: MeatspaceEnvironmentEvents
var train: Node3D
var side_train: Node3D
var side_neon: Node3D
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
var layers: Dictionary = {}
var sequencer: CityAmbienceSequencer
var portal_gain := 0.4
var portal_target := 0.4
var portal_origin := 0.4
var portal_elapsed := 0.5
var open_fraction := 0.0

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
	for layer: Dictionary in source.get("layers", []):
		layers[String(layer.id)] = _audio(String(layer.path), true)
	sequencer = CityAmbienceSequencer.new()
	add_child(sequencer)
	sequencer.configure(source.get("sequencer", {}), bus_name)
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
		stream.loop_end = stream.data.size() / (2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1) / (2 if stream.stereo else 1)
	player.stream = stream
	player.bus = bus_name
	add_child(player)
	return player

func set_active(value: bool) -> void:
	if active == value: return
	active = value
	if active:
		# A location can be entered and exited in the same frame during story handoff.
		# Defer playback so cancelled entries never allocate pending audio voices.
		call_deferred("_start_ambience")
		events.enter()
	else:
		sequencer.leave()
		events.leave()
		for player in [city_audio, utility_audio, train_audio] + layers.values(): player.stop()

func _start_ambience() -> void:
	if not active or not is_inside_tree(): return
	sequencer.enter()
	for player in [city_audio, utility_audio] + layers.values():
		if not player.playing: player.play()

func apply_state(state: PersistentGameState) -> void:
	current_time = String(state.world_state.get("time_of_day", "NIGHT")) if state != null else "NIGHT"
	profile = definition.profiles.get(current_time, definition.profiles.NIGHT)
	var flags: Dictionary = state.campaign_state.get("story_flags", {}) if state != null else {}
	var open_count := 0
	window_open = false
	for flag: String in definition.get("window_flags", [definition.get("window_flag", "")]):
		if bool(flags.get(flag, false)): open_count += 1
	window_open = open_count > 0
	open_fraction = float(open_count) / maxf(1, definition.get("window_flags", []).size())
	environment.background_color = Color(String(profile.sky))
	environment.ambient_light_color = Color(String(profile.ambient))
	environment.ambient_light_energy = float(profile.energy)
	neon.visible = bool(profile.neon)
	side_neon.visible = neon.visible
	var portal: Dictionary = definition.get("portal", {})
	portal_origin = portal_gain
	portal_target = lerpf(float(portal.get("closed_gain", 0.4)), float(portal.get("open_gain", 1.0)), open_fraction)
	portal_elapsed = 0.0
	if not active: portal_elapsed = float(portal.get("transition_seconds", 0.5))
	advance_portal(0)
	city_audio.volume_db = float(profile.city_db)
	utility_audio.volume_db = float(profile.utility_db)
	train_audio.volume_db = -17.0
	sequencer.interval_scale = float(profile.get("event_interval_scale", 1.0))

func advance_portal(delta: float) -> void:
	var portal: Dictionary = definition.get("portal", {})
	portal_elapsed += maxf(0, delta)
	var progress := clampf(portal_elapsed / maxf(0.01, float(portal.get("transition_seconds", 0.5))), 0, 1)
	portal_gain = lerpf(portal_origin, portal_target, progress)
	var bus := AudioServer.get_bus_index(bus_name)
	if bus > 0: AudioServer.set_bus_volume_db(bus, linear_to_db(portal_gain))
	var amount := inverse_lerp(float(portal.get("closed_gain", 0.4)), float(portal.get("open_gain", 1)), portal_gain)
	lowpass.cutoff_hz = lerpf(float(portal.get("closed_cutoff_hz", 1200)), float(portal.get("open_cutoff_hz", 18000)), amount)

func _process(delta: float) -> void:
	advance_portal(delta)
	if sequencer != null: sequencer.advance(delta, train.visible)

func _build_exterior() -> void:
	neon = Node3D.new()
	add_child(neon)
	for row in range(3):
		for i in range(11):
			var height := 1.6 + float((i * 7 + row * 3) % 9) * 0.32
			var x := -13.0 + i * 2.6 + row * 0.7
			var z := -7.0 - row * 4
			block(self, Vector3(2.1, height, 2), Vector3(x, height / 2 - 1, z), Color("354552").lightened(row * 0.06))
			block(self, Vector3(0.7, 0.45, 0.6), Vector3(x, height - 0.78, z), Color("626c73"))
			for floor_index in range(maxi(1, int((height - 1.15) / 0.7))):
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
	var side := Node3D.new()
	side.rotation_degrees.y = -90
	for child in get_children():
		if child is MeshInstance3D: side.add_child(child.duplicate())
	side_neon = neon.duplicate() as Node3D
	side.add_child(side_neon)
	side_train = train.duplicate() as Node3D
	side.add_child(side_train)
	add_child(side)

func _event_started(id: StringName) -> void:
	if id == &"TRAIN":
		train.position = Vector3(-8, 1.8, -4.8)
		train.visible = true
		side_train.visible = true
		sequencer.advance(0, true)
		train_audio.play()

func _event_progress(id: StringName, progress: float) -> void:
	if id == &"TRAIN":
		train.position = Vector3(lerpf(-8, 10, progress), 1.8, -4.8)
		side_train.position = train.position

func _event_finished(id: StringName) -> void:
	if id == &"TRAIN":
		train.visible = false
		side_train.visible = false
		train_audio.stop()

func _exit_tree() -> void:
	set_active(false)
	for player in [city_audio, utility_audio, train_audio] + layers.values():
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
