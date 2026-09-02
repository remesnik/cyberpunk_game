class_name CreditEntry
extends Resource

@export var name: String
@export var role: String
@export var optional_url: String
@export_multiline var optional_note: String

func _init(p_name := "", p_role := "", p_url := "", p_note := "") -> void:
	name = p_name; role = p_role; optional_url = p_url; optional_note = p_note
