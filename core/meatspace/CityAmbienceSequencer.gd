class_name CityAmbienceSequencer
extends Node
## One exterior event voice, category cooldowns and an entry-relative schedule.
signal event_played(id: String, volume_db: float, pan: float)
var definition: Dictionary
var player: AudioStreamPlayer
var panner: AudioEffectPanner
var bus_name: StringName
var rng := RandomNumberGenerator.new()
var active := false
var elapsed := 0.0
var remaining := 0.0
var wait_remaining := 0.0
var interval_scale := 1.0
var last_category := ""
var cooldowns: Dictionary = {}
var history: Array[Dictionary] = []
var streams: Dictionary = {}
var current_time := "NIGHT"

func configure(source: Dictionary, exterior_bus: StringName) -> void:
	definition = source
	rng.randomize()
	bus_name = StringName("CityEvents_%s" % get_instance_id())
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, exterior_bus)
	panner = AudioEffectPanner.new()
	AudioServer.add_bus_effect(index, panner)
	player = AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	for event: Dictionary in source.get("events", []): streams[event.id] = load(String(event.path))

func apply_profile(time_of_day: String, scale: float) -> void:
	current_time = time_of_day
	interval_scale = scale

func eligible_event_ids() -> Array[String]:
	var result: Array[String] = []
	for event: Dictionary in definition.get("events", []):
		var times: Array = event.get("times", [])
		if times.is_empty() or current_time in times: result.append(String(event.id))
	return result

func enter() -> void:
	leave()
	active = true
	elapsed = 0
	cooldowns.clear()
	last_category = ""
	_schedule()

func leave() -> void:
	active = false
	remaining = 0
	if player != null: player.stop()

func _schedule() -> void:
	wait_remaining = rng.randf_range(float(definition.get("interval_min", 14)), float(definition.get("interval_max", 32))) * interval_scale

func advance(delta: float, blocked := false) -> void:
	if not active: return
	elapsed += maxf(0, delta)
	if blocked:
		player.stop()
		remaining = 0
		wait_remaining = maxf(wait_remaining, 5)
		return
	if remaining > 0:
		remaining = maxf(0, remaining - delta)
		if remaining == 0: player.stop()
		return
	wait_remaining -= maxf(0, delta)
	if wait_remaining > 0: return
	var eligible: Array[Dictionary] = []
	for event: Dictionary in definition.get("events", []):
		var times: Array = event.get("times", [])
		if (times.is_empty() or current_time in times) and event.category != last_category and elapsed >= float(cooldowns.get(event.category, 0)):
			eligible.append(event)
	if eligible.is_empty():
		wait_remaining = 4
		return
	var selected := eligible[rng.randi_range(0, eligible.size() - 1)]
	player.stream = streams[selected.id]
	player.volume_db = float(selected.volume_db) + rng.randf_range(-2, 2)
	panner.pan = rng.randf_range(-0.35, 0.35)
	player.play()
	remaining = player.stream.get_length()
	last_category = String(selected.category)
	cooldowns[last_category] = elapsed + remaining + float(selected.cooldown)
	history.append({"id": selected.id, "category": last_category, "time": elapsed, "duration": remaining, "volume_db": player.volume_db, "pan": panner.pan})
	if history.size() > 128: history.pop_front()
	event_played.emit(selected.id, player.volume_db, panner.pan)
	_schedule()

func _exit_tree() -> void:
	leave()
	if player != null: player.stream = null
	var index := AudioServer.get_bus_index(bus_name)
	if index > 0: AudioServer.remove_bus(index)
