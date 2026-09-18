class_name CapabilityGlossary
extends PanelContainer

enum DisplayMode { DISABLED, COLLAPSED, EXPANDED }

const DEFAULT_CONFIG := preload("res://cyberspace/display/cyberspace_visualization_config.tres")
const ICON_SWATCH := preload("res://cyberspace/display/NodeCapabilityIconSwatch.gd")

@export var display_mode: DisplayMode = DisplayMode.COLLAPSED
@export var visualization_config: Resource = DEFAULT_CONFIG

@onready var toggle_button: Button = %ToggleButton
@onready var glossary_scroll: ScrollContainer = %GlossaryScroll
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

func glossary_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if visualization_config == null or visualization_config.capability_catalog == null: return entries
	var definitions: Array[Resource] = visualization_config.capability_catalog.definitions.duplicate()
	for definition: Resource in definitions:
		entries.append({"definition": definition, "capability_type": int(definition.capability_type), "name": String(definition.display_name), "description": String(definition.tooltip_description)})
	return entries

func _toggle() -> void:
	set_display_mode(DisplayMode.EXPANDED if display_mode == DisplayMode.COLLAPSED else DisplayMode.COLLAPSED)

func _rebuild() -> void:
	for child in rows.get_children(): child.queue_free()
	for entry: Dictionary in glossary_entries():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var swatch: Control = ICON_SWATCH.new()
		swatch.configure(entry.capability_type, visualization_config.capability_icon_theme, int(entry.definition.palette_role))
		row.add_child(swatch)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var heading := Label.new()
		heading.text = String(entry.name).to_upper()
		heading.add_theme_font_size_override("font_size", 10)
		heading.add_theme_color_override("font_color", visualization_config.capability_icon_theme.color_for(int(entry.definition.palette_role)))
		copy.add_child(heading)
		var description := Label.new()
		description.text = entry.description
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 9)
		description.add_theme_color_override("font_color", Color(0.68, 0.72, 0.72, 1))
		copy.add_child(description)
		row.add_child(copy)
		rows.add_child(row)
	_apply_mode()

func _apply_mode() -> void:
	visible = display_mode != DisplayMode.DISABLED
	if not visible: return
	glossary_scroll.visible = display_mode == DisplayMode.EXPANDED
	toggle_button.text = "ICON GLOSSARY  [−]" if glossary_scroll.visible else "ICON GLOSSARY  [+]"
