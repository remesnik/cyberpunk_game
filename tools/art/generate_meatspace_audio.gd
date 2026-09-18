extends SceneTree
## Small deterministic ambience placeholders, generated once and stored as WAV.
func _initialize() -> void:
	for kind in ["city", "utility", "train"]:
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var duration := 24 if kind != "train" else 7
		var count := duration * stream.mix_rate
		var data := PackedByteArray()
		data.resize(count * 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 914
		var rumble := 0.0
		var wind := 0.0
		for i in range(count):
			var t := float(i) / stream.mix_rate
			rumble = lerpf(rumble, rng.randf_range(-1, 1), 0.018)
			wind = lerpf(wind, rng.randf_range(-1, 1), 0.12)
			var sample := rumble * 2.4 + wind * 0.3
			if kind == "utility": sample = rumble + 0.12 * sin(TAU * 60 * t) + 0.045 * sin(TAU * 120 * t)
			if kind == "city": sample *= 0.7 + 0.3 * sin(TAU * t / 12)
			if kind == "train": sample = sample * 1.5 + 0.12 * sin(TAU * 85 * t) * pow(maxf(0, sin(TAU * 3 * t)), 6)
			var fade := minf(1.0, minf(t, duration - t) / 0.5)
			data.encode_s16(i * 2, int(clampf(sample * fade, -1, 1) * 26000))
		stream.data = data
		stream.save_to_wav("res://assets/meatspace/audio/%s.wav" % kind)
	quit()
