@tool
class_name StoryAuthoringWorkspace
extends AuthoringContentWorkspace


func _ready() -> void:
	super()
	set_collections([&"story_hooks", &"story_bundles", &"story_variables"] as Array[StringName])

