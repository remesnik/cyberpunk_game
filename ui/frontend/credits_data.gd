class_name CreditsData
extends Resource

@export var record_id: StringName = &"CREDITS_CURRENT"
@export var display_title := "CREDITS"
@export var revision := "REV 0.1"
@export var sections: Array[Resource] = []
@export_group("Optional End Event")
@export var end_event_enabled := false
@export var end_event_lines: Array[Dictionary] = []
@export var end_event_return_prompt := "PRESS BACK TO RETURN"
