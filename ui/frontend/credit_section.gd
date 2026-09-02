class_name CreditSection
extends Resource

@export var heading: String
@export var entries: Array[Resource] = []

func _init(p_heading := "", p_entries: Array[Resource] = []) -> void:
	heading = p_heading; entries = p_entries
