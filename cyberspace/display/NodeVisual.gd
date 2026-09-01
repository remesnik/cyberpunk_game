class_name NodeVisual
extends Control

signal selected(node_id: StringName)
signal scan_requested(contact_id: StringName)

const CYAN := Color("48e8ff")
const AMBER := Color("ffc857")
const RED := Color("ff496c")
const DIM := Color("254e62")

var node_id: StringName = &""
var title := "UNKNOWN"
var subtitle := "UNRESOLVED ROUTE"
var is_current := false
var is_unknown := false
var is_destination := false
var is_security_visible := false
var is_selectable := false
var security_level := 0
var _hovered := false
var _pulse := 0.0

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())
	set_process(true)

func configure(node: NetworkNodeDefinition, current: bool, selectable: bool, security_visible: bool) -> void:
	configure_view({"id": node.id, "display_name": node.display_name, "node_type": node.node_type, "security_level": node.security_level, "level": KnowledgeLevel.Value.SCANNED}, current, selectable, security_visible)

func configure_view(record: Dictionary, current: bool, selectable: bool, security_visible: bool) -> void:
	node_id = record.get("id", &"")
	title = String(record.get("display_name", "UNKNOWN NODE")).to_upper()
	var level := int(record.get("level", KnowledgeLevel.Value.DETECTED))
	var type_text := _type_name(int(record.get("node_type", NetworkNodeDefinition.NodeType.SYSTEM))) if level >= KnowledgeLevel.Value.IDENTIFIED else "UNIDENTIFIED"
	subtitle = type_text
	if level >= KnowledgeLevel.Value.SCANNED:
		subtitle += "  //  SEC %d" % int(record.get("security_level", 0))
	is_current = current
	is_selectable = selectable
	is_security_visible = security_visible
	security_level = int(record.get("security_level", 0))
	is_unknown = false
	queue_redraw()

func configure_unknown(contact_id: StringName = &"") -> void:
	node_id = contact_id
	title = "???"
	subtitle = "SIGNAL FRAGMENT"
	is_unknown = true
	is_selectable = contact_id != &""
	queue_redraw()

func set_destination_emphasis(enabled: bool) -> void:
	is_destination = enabled
	queue_redraw()

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 2.5, TAU)
	if is_current or is_destination:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if is_selectable and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(node_id)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			scan_requested.emit(node_id)
			accept_event()

func _draw() -> void:
	var center := size * 0.5
	var radius := 54.0 if is_current else 42.0
	var color := DIM if is_unknown else (RED if is_security_visible else CYAN)
	if _hovered and is_selectable:
		color = AMBER
	if is_destination:
		color = AMBER
	var glow_alpha := 0.10 + (sin(_pulse) + 1.0) * 0.04
	draw_circle(center, radius + 12.0, Color(color, glow_alpha))
	var points := PackedVector2Array()
	for index in 6:
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	points.append(points[0])
	draw_polyline(points, Color(color, 0.35 if is_unknown else 0.95), 3.0 if is_current else 2.0, true)
	if not is_unknown:
		draw_circle(center, 8.0 if is_current else 5.0, color, false, 2.0, true)
		draw_line(center + Vector2(-radius * 0.65, 0), center + Vector2(radius * 0.65, 0), Color(color, 0.45), 1.0)
	if is_current:
		draw_arc(center, radius + 8.0, _pulse, _pulse + PI * 1.35, 28, AMBER, 2.0, true)
		var marker := PackedVector2Array([center + Vector2(0, -17), center + Vector2(-10, 4), center + Vector2(10, 4), center + Vector2(0, -17)])
		draw_colored_polygon(marker, AMBER)
	var font := ThemeDB.fallback_font
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2(center.x - title_width * 0.5, size.y - 17.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	var sub_width := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2(center.x - sub_width * 0.5, size.y - 3.0), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(color, 0.68))
	if is_security_visible:
		draw_string(font, Vector2(center.x + radius - 6.0, center.y - radius + 8.0), "ICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RED)

func _type_name(value: NetworkNodeDefinition.NodeType) -> String:
	return NetworkNodeDefinition.NodeType.keys()[value].replace("_", " ")
