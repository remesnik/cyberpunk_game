class_name FrontendAudioProfile
extends Resource

@export_group("Splash Cues")
@export var splash_boot: AudioStream
@export var splash_status: AudioStream
@export var splash_resolve: AudioStream
@export_group("Interface Cues")
@export var focus_navigation: AudioStream
@export var selection: AudioStream
@export var back_cancel: AudioStream
@export_group("Ambience")
@export var menu_ambience: AudioStream
@export var credits_ambience: AudioStream
@export_group("Mix")
@export_range(-60.0, 6.0, 0.5) var ambience_volume_db := -18.0
@export_range(-60.0, 6.0, 0.5) var ui_volume_db := -10.0
@export_range(0.0, 3.0, 0.05) var screen_crossfade_seconds := 0.45
@export_range(0.0, 3.0, 0.05) var gameplay_fade_seconds := 0.65
