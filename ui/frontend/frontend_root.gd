class_name FrontendRoot
extends Control

const SplashScreenScript := preload("res://ui/frontend/splash_screen.gd")
const MainMenuScript := preload("res://ui/frontend/main_menu.gd")
const CreditsScreenScript := preload("res://ui/frontend/credits_screen.gd")

signal new_game_requested
signal game_mode_requested(mode_id: StringName)
signal continue_game_requested
signal load_game_requested
signal settings_requested
signal frontend_screen_changed(screen: Screen)

enum Screen { SPLASH, MAIN_MENU, GAME_MODE_SELECTION, TUTORIAL_PROMPT, LOAD, SETTINGS, CREDITS }
enum TransitionType { FADE, DIGITAL_CORRUPTION, SIGNAL_LOSS, SIGNAL_ACQUISITION }
@export var initial_screen := Screen.SPLASH
@export var transition_duration := 0.22
@export_file("*.tscn") var gameplay_scene_path := "res://Main.tscn"
@export var automatically_start_gameplay := true
@export var accessibility_config: FrontendAccessibilityConfig = preload("res://ui/frontend/accessibility/frontend_accessibility_config.tres")
var current_screen := Screen.SPLASH
var _transitioning := false
var _normal_transition_duration := 0.22
var save_provider: FrontendSaveProvider
var _recent_save: FrontendSaveSummary
var _new_game_commit_in_progress := false

@onready var splash: Control = %SplashScreen
@onready var main_menu: Control = %MainMenu
@onready var game_mode_selection: Control = %GameModeSelection
@onready var tutorial_prompt: FrontendTutorialPrompt = %TutorialPrompt
@onready var credits: Control = %CreditsScreen
@onready var load_screen: Control = %LoadScreen
@onready var settings_screen: Control = %SettingsScreen
@onready var frontend_audio: FrontendAudioController = %FrontendAudio
@onready var transition_layer: FrontendTransitionLayer = %TransitionLayer

func _ready() -> void:
	_normal_transition_duration = transition_duration
	splash.finished.connect(show_main_menu)
	main_menu.credits_requested.connect(show_credits)
	main_menu.continue_game_requested.connect(_continue_game)
	main_menu.new_game_requested.connect(show_game_mode_selection)
	main_menu.load_game_requested.connect(show_load)
	main_menu.settings_requested.connect(show_settings)
	main_menu.quit_requested.connect(get_tree().quit)
	game_mode_selection.mode_selected.connect(_on_mode_selected)
	game_mode_selection.back_requested.connect(show_main_menu)
	tutorial_prompt.decision_made.connect(_on_free_roam_tutorial_decision)
	tutorial_prompt.back_requested.connect(show_game_mode_selection)
	credits.back_requested.connect(show_main_menu)
	load_screen.back_requested.connect(show_main_menu)
	settings_screen.back_requested.connect(show_main_menu)
	load_screen.save_selected.connect(_load_selected_save)
	splash.audio_cue_requested.connect(frontend_audio.play_cue)
	main_menu.audio_cue_requested.connect(frontend_audio.play_cue)
	game_mode_selection.audio_cue_requested.connect(frontend_audio.play_cue)
	tutorial_prompt.audio_cue_requested.connect(frontend_audio.play_cue)
	credits.audio_cue_requested.connect(frontend_audio.play_cue)
	load_screen.audio_cue_requested.connect(frontend_audio.play_cue)
	settings_screen.audio_cue_requested.connect(frontend_audio.play_cue)
	apply_accessibility(accessibility_config)
	set_save_provider(PersistentGameSaveProvider.new())
	(save_provider as PersistentGameSaveProvider).refresh()
	_show_immediately(initial_screen)

func set_save_provider(provider: FrontendSaveProvider) -> void:
	if save_provider != null and save_provider.saves_changed.is_connected(refresh_save_state):
		save_provider.saves_changed.disconnect(refresh_save_state)
	save_provider = provider if provider != null else FrontendSaveProvider.new()
	save_provider.saves_changed.connect(refresh_save_state)
	refresh_save_state()

func refresh_save_state() -> void:
	_recent_save = save_provider.get_most_recent_resumable() if save_provider != null else null
	main_menu.apply_save_state(_recent_save, true, true)
	load_screen.set_saves(save_provider.get_resumable_saves() if save_provider != null else [])

func _continue_game() -> void:
	if _recent_save == null or not _recent_save.is_valid():
		refresh_save_state(); return
	if save_provider.continue_save(_recent_save.save_id) != OK:
		# Compatibility hook for a game-state owner that has not adopted the
		# provider adapter yet.
		continue_game_requested.emit()
	else:
		await _handoff_to_gameplay()

func _load_selected_save(save_id: StringName) -> void:
	if save_provider != null and save_provider.continue_save(save_id) == OK:
		await _handoff_to_gameplay()

func _handoff_to_gameplay() -> void:
	if not automatically_start_gameplay or gameplay_scene_path.is_empty(): return
	await frontend_audio.transition_to_gameplay()
	get_tree().change_scene_to_file(gameplay_scene_path)

func apply_accessibility(config: FrontendAccessibilityConfig) -> void:
	if config == null: return
	accessibility_config = config
	get_window().content_scale_factor = config.ui_scale
	transition_duration = 0.0 if config.reduced_animation else _normal_transition_duration
	splash.apply_accessibility(config)
	main_menu.apply_accessibility(config)
	game_mode_selection.apply_accessibility(config)
	tutorial_prompt.apply_accessibility(config)
	credits.apply_accessibility(config)
	load_screen.apply_accessibility(config)
	settings_screen.apply_accessibility(config)
	frontend_audio.apply_accessibility(config)

func show_splash() -> void:
	splash.reset(); transition_to(Screen.SPLASH, TransitionType.SIGNAL_LOSS)
func show_main_menu() -> void: transition_to(Screen.MAIN_MENU, TransitionType.SIGNAL_ACQUISITION)
func show_game_mode_selection() -> void:
	_new_game_commit_in_progress = false
	game_mode_selection.prepare(_recent_save != null and _recent_save.is_valid())
	transition_to(Screen.GAME_MODE_SELECTION, TransitionType.SIGNAL_ACQUISITION)
func show_tutorial_prompt() -> void: transition_to(Screen.TUTORIAL_PROMPT, TransitionType.SIGNAL_ACQUISITION)
func show_load() -> void:
	load_game_requested.emit(); transition_to(Screen.LOAD, TransitionType.SIGNAL_ACQUISITION)
func show_settings() -> void:
	settings_requested.emit(); transition_to(Screen.SETTINGS, TransitionType.SIGNAL_ACQUISITION)
func show_credits() -> void: transition_to(Screen.CREDITS, TransitionType.DIGITAL_CORRUPTION)

func _on_mode_selected(mode_id: StringName) -> void:
	if mode_id in [&"FREE_ROAM", &"FREE_ROAM_MODE"]:
		show_tutorial_prompt()
		return
	_start_new_game(mode_id, false)

func _on_free_roam_tutorial_decision(run_introduction: bool) -> void:
	_start_new_game(&"FREE_ROAM", run_introduction)

func _start_new_game(mode_id: StringName, run_introduction := false) -> void:
	if _new_game_commit_in_progress: return
	_new_game_commit_in_progress = true
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_method("create_new_game"): game.create_new_game(mode_id, {"run_introduction": run_introduction})
	game_mode_requested.emit(mode_id)
	new_game_requested.emit()
	if automatically_start_gameplay and not gameplay_scene_path.is_empty():
		await _handoff_to_gameplay()

func transition_to(destination: Screen, transition_type := TransitionType.FADE) -> void:
	if _transitioning or destination == current_screen: return
	_transitioning = true
	main_menu.set_navigation_enabled(false)
	game_mode_selection.set_navigation_enabled(false)
	tutorial_prompt.set_navigation_enabled(false)
	var outgoing := _screen_control(current_screen)
	var visual_type: int = transition_type
	if accessibility_config != null and not accessibility_config.glitch_effects_enabled and visual_type == TransitionType.DIGITAL_CORRUPTION:
		visual_type = TransitionType.FADE
	await transition_layer.cover(visual_type, transition_duration)
	outgoing.hide(); _activate(destination)
	var incoming := _screen_control(destination); incoming.modulate.a = 1.0; incoming.show()
	await transition_layer.reveal(transition_duration)
	# Defer activation beyond the skip event's frame so keyboard/controller
	# accept input cannot leak into the focused New Game button.
	await get_tree().process_frame
	if destination == Screen.MAIN_MENU: main_menu.set_navigation_enabled(true); main_menu.focus_default()
	elif destination == Screen.GAME_MODE_SELECTION: game_mode_selection.set_navigation_enabled(true); game_mode_selection.focus_default()
	elif destination == Screen.TUTORIAL_PROMPT: tutorial_prompt.set_navigation_enabled(true); tutorial_prompt.focus_default()
	_transitioning = false

func _show_immediately(destination: Screen) -> void:
	for screen in [splash, main_menu, game_mode_selection, tutorial_prompt, load_screen, settings_screen, credits]: screen.hide(); screen.modulate.a = 1.0
	_activate(destination); _screen_control(destination).show()
	if destination == Screen.MAIN_MENU: main_menu.call_deferred("focus_default")
	elif destination == Screen.GAME_MODE_SELECTION: game_mode_selection.call_deferred("focus_default")
	elif destination == Screen.TUTORIAL_PROMPT: tutorial_prompt.call_deferred("focus_default")

func _activate(destination: Screen) -> void:
	current_screen = destination
	match destination:
		Screen.SPLASH: frontend_audio.play_context(FrontendAudioController.Context.SPLASH)
		Screen.MAIN_MENU: frontend_audio.play_context(FrontendAudioController.Context.MENU)
		Screen.GAME_MODE_SELECTION: frontend_audio.play_context(FrontendAudioController.Context.MENU)
		Screen.TUTORIAL_PROMPT: frontend_audio.play_context(FrontendAudioController.Context.MENU)
		Screen.LOAD, Screen.SETTINGS: frontend_audio.play_context(FrontendAudioController.Context.MENU)
		Screen.CREDITS: frontend_audio.play_context(FrontendAudioController.Context.CREDITS)
	frontend_screen_changed.emit(destination)
	if destination == Screen.LOAD: load_screen.call_deferred("focus_default")
	elif destination == Screen.SETTINGS: settings_screen.call_deferred("focus_default")
	elif destination == Screen.CREDITS: credits.call_deferred("focus_default")

func _screen_control(screen: Screen) -> Control:
	match screen:
		Screen.SPLASH: return splash
		Screen.GAME_MODE_SELECTION: return game_mode_selection
		Screen.TUTORIAL_PROMPT: return tutorial_prompt
		Screen.LOAD: return load_screen
		Screen.SETTINGS: return settings_screen
		Screen.CREDITS: return credits
	return main_menu
