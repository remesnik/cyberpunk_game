class_name SplashScreen
extends Control

signal finished
signal audio_cue_requested(cue: StringName)

@export_group("Boot Timing")
@export_range(0.0, 2.0, 0.05) var initial_black_duration := 0.3
@export_range(0.1, 2.0, 0.05) var status_line_interval := 0.48
@export_range(0.1, 2.0, 0.05) var logo_resolve_duration := 0.55
@export_range(0.2, 3.0, 0.05) var resolved_logo_hold := 1.35
@export_range(0.05, 1.0, 0.01) var interference_duration := 0.22
@export_group("Presentation")
@export var boot_heading := "INITIALIZING INTERFACE..."
@export var boot_status_lines: Array[String] = ["ROUTING TABLE........OK", "DECK INTERFACE.......OK", "SIGNAL................LOCKED"]

var _elapsed := 0.0
var _finished := false
var _logo_started := false
var _logo_resolved := false
var _visible_status_count := 0
var _logo_tween: Tween
var _boot_cue_emitted := false
var _reduced_animation := false
var _glitch_effects_enabled := true

@onready var blackout: ColorRect = %Blackout
@onready var boot_block: Control = %BootBlock
@onready var boot_title: Label = %BootTitle
@onready var status_text: Label = %StatusText
@onready var logo_block: Control = %LogoBlock
@onready var logo: Label = %Logo
@onready var interference: ColorRect = %Interference
@onready var background: Control = %Background

func _ready() -> void:
	set_process_unhandled_input(true)
	reset()

func _process(delta: float) -> void:
	if _finished: return
	_elapsed += delta
	var activity_time := initial_black_duration
	if _elapsed >= activity_time:
		blackout.hide(); boot_block.show()
		if not _boot_cue_emitted:
			_boot_cue_emitted = true; audio_cue_requested.emit(&"SPLASH_BOOT")
	var desired_lines := clampi(int(floor((_elapsed - activity_time) / status_line_interval)), 0, boot_status_lines.size())
	if desired_lines != _visible_status_count:
		_visible_status_count = desired_lines; _refresh_status(); audio_cue_requested.emit(&"SPLASH_STATUS")
	var logo_time := activity_time + status_line_interval * (boot_status_lines.size() + 0.65)
	if _elapsed >= logo_time and not _logo_started: _begin_logo_resolution()
	if _logo_started and not _logo_resolved: _distort_logo()
	var finish_time := logo_time + logo_resolve_duration + resolved_logo_hold
	if _elapsed >= finish_time: _finish(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled(); _finish(true)

func _finish(skipped: bool) -> void:
	if _finished: return
	_finished = true; set_process(false); set_process_unhandled_input(false)
	if _logo_tween != null and _logo_tween.is_valid(): _logo_tween.kill()
	if skipped and _glitch_effects_enabled:
		interference.show(); interference.modulate.a = 0.16
	finished.emit()

func reset() -> void:
	_elapsed = 0.0; _finished = false; _logo_started = false; _logo_resolved = false; _visible_status_count = 0; _boot_cue_emitted = false
	if not is_node_ready(): return
	blackout.show(); boot_block.hide(); logo_block.hide(); interference.hide()
	boot_title.text = boot_heading; status_text.text = ""; logo.text = "C_YB_RSP_C_"; logo.position = Vector2.ZERO; logo.modulate.a = 0.0
	set_process(true); set_process_unhandled_input(true)

func total_duration() -> float:
	return initial_black_duration + status_line_interval * (boot_status_lines.size() + 0.65) + logo_resolve_duration + resolved_logo_hold

func apply_accessibility(config: FrontendAccessibilityConfig) -> void:
	_reduced_animation = config.reduced_animation
	_glitch_effects_enabled = config.glitch_effects_enabled
	if background.has_method("apply_accessibility"): background.apply_accessibility(config)
	if not _glitch_effects_enabled and is_node_ready(): interference.hide()

func _refresh_status() -> void:
	var lines: PackedStringArray = []
	for index in _visible_status_count: lines.append(boot_status_lines[index])
	status_text.text = "\n".join(lines)

func _begin_logo_resolution() -> void:
	_logo_started = true; boot_block.hide(); logo_block.show(); interference.visible = _glitch_effects_enabled; audio_cue_requested.emit(&"SPLASH_RESOLVE")
	if _reduced_animation:
		logo.modulate.a = 1.0; _resolve_logo(); return
	_logo_tween = create_tween().set_parallel(true)
	_logo_tween.tween_property(logo, "modulate:a", 1.0, logo_resolve_duration)
	_logo_tween.tween_property(interference, "modulate:a", 0.0, interference_duration)
	_logo_tween.chain().tween_callback(_resolve_logo)

func _distort_logo() -> void:
	if not _glitch_effects_enabled:
		logo.text = "CYBERSPACE"; logo.position = Vector2.ZERO; return
	var frames := ["CYB_RSPAC_", "C¥BERSP/CE", "CYBERSPA_E", "CYB#RSPACE"]
	logo.text = frames[int(_elapsed * 24.0) % frames.size()]
	logo.position.x = sin(_elapsed * 93.0) * 2.5

func _resolve_logo() -> void:
	_logo_resolved = true; logo.text = "CYBERSPACE"; logo.position = Vector2.ZERO; interference.hide()
