class_name FrontendAudioController
extends Node

enum Context { SILENT, SPLASH, MENU, CREDITS, GAMEPLAY }
@export var profile: Resource
var current_context := Context.SILENT
var _menu_ui_gain := 1.0

@onready var menu_ambience: AudioStreamPlayer = %MenuAmbience
@onready var credits_ambience: AudioStreamPlayer = %CreditsAmbience
@onready var ui_cues: AudioStreamPlayer = %UICues
@onready var splash_cues: AudioStreamPlayer = %SplashCues

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_profile()

func play_context(context: Context) -> void:
	if context == current_context: return
	current_context = context
	match context:
		Context.MENU: _crossfade(menu_ambience, credits_ambience)
		Context.CREDITS:
			# An unset (or shared) credits bed deliberately carries the menu bed
			# across the screen boundary without seeking or restarting it.
			if credits_ambience.stream == null or credits_ambience.stream == menu_ambience.stream:
				_crossfade(menu_ambience, credits_ambience)
			else:
				_crossfade(credits_ambience, menu_ambience)
		Context.SPLASH: _fade_out(menu_ambience); _fade_out(credits_ambience)
		Context.SILENT, Context.GAMEPLAY: _fade_out(menu_ambience); _fade_out(credits_ambience)

func play_cue(cue: StringName) -> void:
	if profile == null: return
	var stream: AudioStream
	var player := ui_cues
	match cue:
		&"SPLASH_BOOT": stream = profile.get("splash_boot"); player = splash_cues
		&"SPLASH_STATUS": stream = profile.get("splash_status"); player = splash_cues
		&"SPLASH_RESOLVE": stream = profile.get("splash_resolve"); player = splash_cues
		&"FOCUS": stream = profile.get("focus_navigation")
		&"SELECT": stream = profile.get("selection")
		&"BACK": stream = profile.get("back_cancel")
	if stream == null: return
	player.stream = stream; player.volume_db = float(profile.get("ui_volume_db")) + linear_to_db(_menu_ui_gain); player.play()

func apply_accessibility(config: FrontendAccessibilityConfig) -> void:
	_menu_ui_gain = maxf(config.menu_ui_volume, 0.0001)
	var master_index := AudioServer.get_bus_index(&"Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, config.master_volume <= 0.0)
		AudioServer.set_bus_volume_db(master_index, linear_to_db(maxf(config.master_volume, 0.0001)))
	var ambience_db := _profile_float("ambience_volume_db", -18.0) + linear_to_db(_menu_ui_gain)
	for player: AudioStreamPlayer in [menu_ambience, credits_ambience]:
		if player.playing: player.volume_db = ambience_db

func transition_to_gameplay() -> void:
	current_context = Context.GAMEPLAY
	var duration := _profile_float("gameplay_fade_seconds", 0.65)
	var tweens: Array[Tween] = []
	for player: AudioStreamPlayer in [menu_ambience, credits_ambience]:
		if player.playing:
			var tween := create_tween(); tween.tween_property(player, "volume_db", -60.0, duration); tweens.append(tween)
	if not tweens.is_empty() and duration > 0.0: await tweens[0].finished
	menu_ambience.stop(); credits_ambience.stop()

func _apply_profile() -> void:
	if profile == null: return
	menu_ambience.stream = profile.get("menu_ambience")
	credits_ambience.stream = profile.get("credits_ambience")

func _crossfade(incoming: AudioStreamPlayer, outgoing: AudioStreamPlayer) -> void:
	var target := _profile_float("ambience_volume_db", -18.0) + linear_to_db(_menu_ui_gain)
	var duration := _profile_float("screen_crossfade_seconds", 0.45)
	if incoming.stream != null and not incoming.playing:
		incoming.volume_db = -60.0; incoming.play()
	if incoming.playing: create_tween().tween_property(incoming, "volume_db", target, duration)
	_fade_out(outgoing, duration)

func _fade_out(player: AudioStreamPlayer, duration := -1.0) -> void:
	if not player.playing: return
	var fade := _profile_float("screen_crossfade_seconds", 0.45) if duration < 0.0 else duration
	var tween := create_tween(); tween.tween_property(player, "volume_db", -60.0, fade); tween.tween_callback(player.stop)

func _profile_float(property: StringName, fallback: float) -> float:
	return float(profile.get(property)) if profile != null else fallback
