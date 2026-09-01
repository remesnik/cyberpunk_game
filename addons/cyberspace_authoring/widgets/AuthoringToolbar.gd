@tool
extends HBoxContainer

signal action_requested(action: StringName)

const ACTIONS: Array[String] = [
	"NEW", "OPEN", "SAVE", "VALIDATE", "PLAY FROM HERE",
	"GRAPH", "STORY", "MEATSPACE", "CONTENT", "OPERATION", "PREVIEW", "CREATE FROM TEMPLATE"
]


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = "  CYBERSPACE // AUTHORING STUDIO  "
	title.add_theme_color_override("font_color", Color("56e8ff"))
	add_child(title)

	for action: String in ACTIONS:
		if action == "GRAPH":
			var spacer := VSeparator.new()
			add_child(spacer)
		var button := Button.new()
		button.text = action
		button.tooltip_text = _tooltip_for(action)
		button.pressed.connect(_emit_action.bind(StringName(action)))
		add_child(button)

	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(fill)


func _emit_action(action: StringName) -> void:
	action_requested.emit(action)


func _tooltip_for(action: String) -> String:
	return action.capitalize()
