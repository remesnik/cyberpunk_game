class_name MeatspaceInteractable
extends Control

signal selected(object_id: StringName)
signal focus_changed(object_id: StringName, focused: bool)

var object_id: StringName
var display_name := "OBJECT"
var interaction_text := "[ INTERACT ]"
var description := ""
var kind: StringName = &"GENERIC"
var focused := false

func configure(data: Dictionary) -> void:
	object_id = StringName(data.get("id", &""))
	display_name = String(data.get("display_name", object_id))
	interaction_text = String(data.get("interaction_text", "[ INTERACT ]"))
	description = String(data.get("description", ""))
	kind = StringName(data.get("kind", &"GENERIC"))
	tooltip_text = "%s\n%s" % [display_name, interaction_text]
	queue_redraw()

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_set_focused.bind(true))
	mouse_exited.connect(_set_focused.bind(false))
	focus_entered.connect(_set_focused.bind(true))
	focus_exited.connect(_set_focused.bind(false))
	gui_input.connect(_gui_input)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus(); selected.emit(object_id); accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		selected.emit(object_id); accept_event()

func _set_focused(value: bool) -> void:
	if focused == value: return
	focused = value; queue_redraw(); focus_changed.emit(object_id, value)

func _draw() -> void:
	var fill := Color("182129")
	var edge := Color("56717a")
	if kind == &"POSTER": fill = Color("272329"); edge = Color("9b7760")
	elif kind in [&"BOX", &"TOOLBOX"]: fill = Color("302b22"); edge = Color("b08b55")
	elif kind == &"JACK": fill = Color("102b30"); edge = Color("45c3cf")
	elif kind == &"BED": fill = Color("20252b"); edge = Color("687783")
	if focused: edge = Color("f1be68")
	draw_rect(Rect2(Vector2.ZERO, size), fill, true)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), edge, false, 2.0 if focused else 1.0)
	_draw_motif(edge)
	draw_string(ThemeDB.fallback_font, Vector2(7, size.y - 8), display_name, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, size.x - 14), 11, edge)

func _draw_motif(color: Color) -> void:
	var center := size * 0.5
	match kind:
		&"BED":
			draw_rect(Rect2(Vector2(8, 8), Vector2(size.x - 16, size.y - 28)), color.darkened(0.45), false, 2); draw_line(Vector2(8, 26), Vector2(size.x - 8, 26), color, 1)
		&"POSTER": draw_line(Vector2(8, 8), size - Vector2(8, 24), color, 1); draw_line(Vector2(size.x - 8, 8), Vector2(8, size.y - 24), color, 1)
		&"BOX": draw_rect(Rect2(center - Vector2(18, 13), Vector2(36, 26)), color, false, 2); draw_line(center - Vector2(18, 3), center + Vector2(18, -3), color, 1)
		&"TOOLBOX": draw_rect(Rect2(center - Vector2(20, 10), Vector2(40, 20)), color, false, 2); draw_rect(Rect2(center - Vector2(7, 16), Vector2(14, 6)), color, false, 1)
		&"SHELF":
			for y in [12.0, 25.0, 38.0]: draw_line(Vector2(8, y), Vector2(size.x - 8, y), color, 1)
		&"JACK": draw_circle(center - Vector2(12, 4), 10, color, false, 2); draw_line(center, center + Vector2(24, 13), color, 2); draw_circle(center + Vector2(27, 15), 3, color)
		_: draw_rect(Rect2(center - Vector2(22, 12), Vector2(44, 24)), color, false, 1)
