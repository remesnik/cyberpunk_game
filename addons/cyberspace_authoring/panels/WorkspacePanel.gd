@tool
extends VBoxContainer

signal entry_selected(entry_id: StringName)
signal document_changed

const NetworkWorkspace := preload("res://addons/cyberspace_authoring/workspaces/network/NetworkGraphWorkspace.gd")
const ContentWorkspace := preload("res://addons/cyberspace_authoring/workspaces/content/ContentWorkspace.gd")
const StoryWorkspace := preload("res://addons/cyberspace_authoring/workspaces/story/StoryWorkspace.gd")
const MeatspaceWorkspace := preload("res://addons/cyberspace_authoring/workspaces/meatspace/MeatspaceWorkspace.gd")
const OperationWorkspace := preload("res://addons/cyberspace_authoring/workspaces/operation/OperationWorkspace.gd")
const PreviewWorkspace := preload("res://addons/cyberspace_authoring/workspaces/preview/PreviewWorkspace.gd")

var document: CyberspaceContentDocument
var editor_state: AuthoringEditorState
var _mode: StringName = &"NETWORK"
var _title: Label
var _active: Control


func _ready() -> void:
	_title = Label.new(); _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _title.add_theme_color_override("font_color", Color("56e8ff")); add_child(_title); _show_mode()


func set_models(value: CyberspaceContentDocument, state: AuthoringEditorState) -> void: document = value; editor_state = state; _show_mode()
func set_mode(mode: String) -> void:
	_mode = &"NETWORK" if mode == "GRAPH" else StringName(mode)
	if editor_state != null: editor_state.active_workspace = _mode
	_show_mode()


func _show_mode() -> void:
	if _title == null: return
	_title.text = "%s WORKSPACE" % _mode
	if is_instance_valid(_active): _active.queue_free()
	match _mode:
		&"NETWORK": _active = NetworkWorkspace.new()
		&"STORY": _active = StoryWorkspace.new()
		&"MEATSPACE": _active = MeatspaceWorkspace.new()
		&"OPERATION": _active = OperationWorkspace.new()
		&"PREVIEW": _active = PreviewWorkspace.new()
		_: _active = ContentWorkspace.new()
	_active.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(_active)
	if _active.has_signal("entry_selected"): _active.entry_selected.connect(entry_selected.emit)
	if _active.has_signal("document_changed"): _active.document_changed.connect(document_changed.emit)
	if _active is NetworkGraphWorkspace: _active.set_models(document, editor_state)
	elif _active.has_method("set_document"): _active.set_document(document)
	if _active is AuthoringContentWorkspace and _mode == &"CONTENT": _active.set_collections([&"graffiti", &"flavor_text", &"services"] as Array[StringName])

