class_name SecurityLevelLegend
extends PanelContainer

enum DisplayMode { DISABLED, COLLAPSED, EXPANDED }

const DEFAULT_CONFIG := preload("res://cyberspace/display/cyberspace_visualization_config.tres")
const SWATCH := preload("res://cyberspace/display/SecurityLevelSwatch.gd")

@export var display_mode: DisplayMode = DisplayMode.COLLAPSED
@export var visualization_config: Resource = DEFAULT_CONFIG

@onready var toggle_button: Button = %ToggleButton
@onready var rows: VBoxContainer = %Rows

func _ready() -> void:
	toggle_button.pressed.connect(_toggle)
	_rebuild()

func set_visualization_config(config: Resource) -> void:
	visualization_config = config if config != null else DEFAULT_CONFIG
	if is_node_ready(): _rebuild()

func set_display_mode(mode: DisplayMode) -> void:
	display_mode = mode
	if is_node_ready(): _apply_mode()

func legend_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if visualization_config.unknown_level_style != null:
		entries.append(_entry(visualization_config.unknown_level_style))
	var styles: Array[Resource] = visualization_config.level_styles.duplicate()
	styles.sort_custom(func(a: Resource, b: Resource) -> bool: return int(a.level) < int(b.level))
	for style: Resource in styles: entries.append(_entry(style))
	return entries

func _entry(style: Resource) -> Dictionary:
	return {"style": style, "label": String(style.label), "display_name": String(style.display_name)}

func _toggle() -> void:
	set_display_mode(DisplayMode.EXPANDED if display_mode == DisplayMode.COLLAPSED else DisplayMode.COLLAPSED)

func _rebuild() -> void:
	for child in rows.get_children(): child.queue_free()
	for entry: Dictionary in legend_entries():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var swatch: Control = SWATCH.new()
		swatch.configure(entry.style)
		row.add_child(swatch)
		var label := Label.new()
		label.text = "%s   %s" % [entry.label, entry.display_name]
		label.add_theme_color_override("font_color", entry.style.border_color)
		label.add_theme_font_size_override("font_size", 10)
		row.add_child(label)
		rows.add_child(row)
	_apply_mode()

func _apply_mode() -> void:
	visible = display_mode != DisplayMode.DISABLED
	if not visible: return
	rows.visible = display_mode == DisplayMode.EXPANDED
	toggle_button.text = "NODE LEVEL  [−]" if rows.visible else "NODE LEVEL  [+]"
