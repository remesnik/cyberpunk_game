@tool
extends VBoxContainer

signal preview_event(message: String)

var editor_state: AuthoringEditorState
var _running := false
var _realtime := 0.0
var _cyber_tick := 0
var _readout: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var row := HBoxContainer.new(); add_child(row)
	var profiles := OptionButton.new()
	for profile in ["TRUE WORLD", "NEW PLAYER", "SCANNED PLAYER", "COMPROMISED PLAYER", "CUSTOM PLAYER KNOWLEDGE"]: profiles.add_item(profile)
	row.add_child(profiles)
	for caption in ["START", "PAUSE PREVIEW", "RESET", "STEP CYBER TICK"]:
		var button := Button.new(); button.text = caption; row.add_child(button)
		if caption == "START": button.pressed.connect(func(): _running = true)
		elif caption == "PAUSE PREVIEW": button.pressed.connect(func(): _running = false)
		elif caption == "RESET": button.pressed.connect(_reset)
		else: button.pressed.connect(func(): _cyber_tick += 1; _refresh())
	var speed := HSlider.new(); speed.min_value = 0.25; speed.max_value = 4.0; speed.step = 0.25; speed.value = 1.0; speed.custom_minimum_size.x = 130
	speed.value_changed.connect(func(value):
		if editor_state != null: editor_state.preview_realtime_speed = value
	)
	row.add_child(speed)
	_readout = Label.new(); add_child(_readout); _refresh()


func set_editor_state(value: AuthoringEditorState) -> void: editor_state = value
func _process(delta: float) -> void:
	if _running: _realtime += delta * (editor_state.preview_realtime_speed if editor_state != null else 1.0); _refresh()
func _reset() -> void: _running = false; _realtime = 0.0; _cyber_tick = 0; _refresh()
func _refresh() -> void:
	if _readout != null: _readout.text = "EDITOR-ONLY PREVIEW // REALTIME %06.2fs // CYBER TICK %03d // %s" % [_realtime, _cyber_tick, "RUNNING" if _running else "PAUSED"]
