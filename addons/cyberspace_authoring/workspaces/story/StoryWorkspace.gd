@tool
class_name StoryAuthoringWorkspace
extends VBoxContainer

signal entry_selected(entry_id: StringName)
signal document_changed
const SequenceEditor := preload("res://addons/cyberspace_authoring/widgets/story_sequence/StorySequenceEditor.gd")
const ContentWorkspace := preload("res://addons/cyberspace_authoring/workspaces/content/ContentWorkspace.gd")

func _ready() -> void:
	var tabs := TabContainer.new(); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(tabs)
	var sequences := SequenceEditor.new(); sequences.name = "SEQUENCES"; sequences.entry_selected.connect(entry_selected.emit); sequences.document_changed.connect(document_changed.emit); tabs.add_child(sequences)
	var content := ContentWorkspace.new(); content.name = "STORY DATA"; content.entry_selected.connect(entry_selected.emit); content.document_changed.connect(document_changed.emit); tabs.add_child(content)
	content.set_collections([&"story_hooks", &"story_bundles", &"story_variables", &"objectives", &"rewards", &"tutorial_guidance_rules"] as Array[StringName])
	if _document != null: sequences.set_document(_document); content.set_document(_document)

var _document: CyberspaceContentDocument
func set_document(value: CyberspaceContentDocument) -> void:
	_document = value
	for child in get_children():
		if child is TabContainer:
			for workspace in child.get_children():
				if workspace.has_method("set_document"): workspace.set_document(value)
