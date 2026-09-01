@tool
extends VBoxContainer

signal issue_activated(entry_id: StringName)

var _log: RichTextLabel


func _ready() -> void:
	var header := HBoxContainer.new()
	add_child(header)
	var label := Label.new()
	label.text = "VALIDATION // EVENT LOG"
	label.add_theme_color_override("font_color", Color("7df7c5"))
	header.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var clear := Button.new()
	clear.text = "CLEAR"
	clear.pressed.connect(_clear)
	header.add_child(clear)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = false
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.meta_clicked.connect(func(meta): issue_activated.emit(StringName(meta)))
	add_child(_log)


func add_entry(level: String, message: String, entry_id: StringName = &"") -> void:
	if _log == null:
		return
	var color := "#56e8ff"
	if level == "STUB":
		color = "#ffcc66"
	elif level == "ERROR":
		color = "#ff6688"
	var linked := "[url=%s]%s[/url]" % [entry_id, message] if entry_id != &"" else message
	_log.append_text("[color=%s][%s][/color] %s\n" % [color, level, linked])


func _clear() -> void:
	_log.clear()
