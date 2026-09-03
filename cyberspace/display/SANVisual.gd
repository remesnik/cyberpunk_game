class_name SANVisual
extends Control

signal selected(san_id: StringName)

const LOCAL := Color("64d8d0")
const ENEMY := Color("d17859")
const WARNING := Color("ffbd55")
const DANGER := Color("ff496c")
const DEAD := Color("59646d")

var san_id: StringName
var state := "NORMAL"
var owner_label := "UNKNOWN"
var is_local := false
var defense_count := 0
var _pulse := 0.0

func configure(view: Dictionary) -> void:
	san_id = view.get("id", &""); state = String(view.get("visual_state", "NORMAL")); owner_label = String(view.get("owner_label", "UNKNOWN")); is_local = bool(view.get("is_local", false)); defense_count = view.get("defenses", []).size()
	tooltip_text = "SYSTEM ACCESS NODE // %s\nDECK RETURN LINK" % owner_label
	queue_redraw()

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process(true)

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 3.0, TAU)
	if state in ["UNDER_ATTACK", "BREACHED", "DISCONNECTED"]: queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(san_id); accept_event()

func _draw() -> void:
	var color := _state_color()
	var center := Vector2(36, 34)
	# Short tether visibly terminates inside the host glyph rather than becoming a route.
	draw_line(Vector2(36, 4), Vector2(36, 16), Color(color, 0.75), 2.0)
	draw_circle(Vector2(36, 4), 3.0, color)
	var diamond := PackedVector2Array([center + Vector2(0, -15), center + Vector2(15, 0), center + Vector2(0, 15), center + Vector2(-15, 0), center + Vector2(0, -15)])
	draw_polyline(diamond, color, 2.5, true)
	draw_circle(center, 7.0, color, false, 2.0)
	if defense_count > 0:
		for index in mini(defense_count, 4):
			draw_arc(center, 20.0 + index * 3.0, -PI * 0.75, PI * 0.75, 16, Color(color, 0.65), 1.2)
	if state == "UNDER_ATTACK": draw_arc(center, 25.0, _pulse, _pulse + PI, 18, DANGER, 3.0)
	if state == "DISCONNECTED":
		draw_line(center + Vector2(-12, -12), center + Vector2(12, 12), DEAD, 3.0)
		draw_line(center + Vector2(12, -12), center + Vector2(-12, 12), DEAD, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(4, 69), "SAN // %s" % owner_label, HORIZONTAL_ALIGNMENT_CENTER, 64, 9, color)

func _state_color() -> Color:
	match state:
		"UNDER_ATTACK", "BREACHED": return DANGER
		"DAMAGED": return WARNING
		"DISCONNECTED": return DEAD
	return LOCAL if is_local else ENEMY
