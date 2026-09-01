@tool
class_name AuthoringPreviewWorkspace
extends VBoxContainer


func _ready() -> void:
	var label := Label.new(); label.text = "SAFE PREVIEW // TRUE WORLD ≠ PLAYER KNOWLEDGE"; add_child(label)
	var note := Label.new(); note.text = "Use bottom preview controls to change editor-only profiles, realtime speed, and cyber ticks. Preview state is never saved into runtime content."; note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(note)
