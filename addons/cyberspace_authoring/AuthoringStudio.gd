@tool
extends MarginContainer

const AuthoringToolbar := preload("res://addons/cyberspace_authoring/widgets/AuthoringToolbar.gd")
const ContentBrowserPanel := preload("res://addons/cyberspace_authoring/panels/ContentBrowserPanel.gd")
const WorkspacePanel := preload("res://addons/cyberspace_authoring/panels/WorkspacePanel.gd")
const AuthoringInspector := preload("res://addons/cyberspace_authoring/inspectors/AuthoringInspector.gd")
const ValidationPanel := preload("res://addons/cyberspace_authoring/panels/ValidationPanel.gd")
const PreviewPanel := preload("res://addons/cyberspace_authoring/preview/PreviewPanel.gd")
const AuthoringValidator := preload("res://addons/cyberspace_authoring/validators/AuthoringValidator.gd")
const TemplateLibrary := preload("res://addons/cyberspace_authoring/templates/AuthoringTemplateLibrary.gd")

var _editor_interface: EditorInterface
var _document: CyberspaceContentDocument
var _state := AuthoringEditorState.new()
var _document_path: String
var _browser: Control
var _workspace: Control
var _inspector: Control
var _validation: Control
var _preview: Control
var _file_dialog: EditorFileDialog
var _template_menu: PopupMenu
var _built := false


func setup(editor_interface: EditorInterface) -> void: _editor_interface = editor_interface
func _ready() -> void:
	if not _built: _built = true; _build_shell(); _new_document()


func _build_shell() -> void:
	var root := VBoxContainer.new(); root.add_theme_constant_override("separation", 6); add_child(root)
	var toolbar := AuthoringToolbar.new(); toolbar.action_requested.connect(_on_toolbar_action); root.add_child(toolbar)
	var vertical := VSplitContainer.new(); vertical.size_flags_vertical = Control.SIZE_EXPAND_FILL; vertical.split_offset = 350; root.add_child(vertical)
	var main := HSplitContainer.new(); main.size_flags_vertical = Control.SIZE_EXPAND_FILL; vertical.add_child(main)
	_browser = ContentBrowserPanel.new(); _browser.custom_minimum_size.x = 230; _browser.item_selected.connect(_select_entry); main.add_child(_browser)
	_workspace = WorkspacePanel.new(); _workspace.custom_minimum_size.x = 540; _workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _workspace.entry_selected.connect(_select_entry); _workspace.document_changed.connect(_document_changed); main.add_child(_workspace)
	_inspector = AuthoringInspector.new(); _inspector.custom_minimum_size.x = 290; _inspector.entry_changed.connect(_document_changed); main.add_child(_inspector)
	var tabs := TabContainer.new(); tabs.custom_minimum_size.y = 155; vertical.add_child(tabs)
	_validation = ValidationPanel.new(); _validation.name = "VALIDATION / EVENT LOG"; _validation.issue_activated.connect(_select_entry); tabs.add_child(_validation)
	_preview = PreviewPanel.new(); _preview.name = "LIVE PREVIEW / DEBUG"; _preview.set_editor_state(_state); tabs.add_child(_preview)
	_file_dialog = EditorFileDialog.new(); _file_dialog.access = EditorFileDialog.ACCESS_RESOURCES; _file_dialog.add_filter("*.tres", "Godot Resource"); add_child(_file_dialog)
	_template_menu = PopupMenu.new()
	for template_name in TemplateLibrary.NAMES: _template_menu.add_item(template_name)
	_template_menu.id_pressed.connect(_apply_template)
	add_child(_template_menu)


func _on_toolbar_action(action: StringName) -> void:
	match action:
		&"GRAPH", &"STORY", &"MEATSPACE", &"CONTENT", &"OPERATION", &"PREVIEW": _workspace.set_mode(String(action)); _validation.add_entry("MODE", "%s workspace selected." % action)
		&"NEW": _new_document()
		&"OPEN": _choose_open()
		&"SAVE": _save()
		&"VALIDATE": _validate_all()
		&"PLAY FROM HERE": _play_from_here()
		&"CREATE FROM TEMPLATE": _template_menu.position = Vector2i(get_screen_position()) + Vector2i(420, 45); _template_menu.popup()


func _new_document() -> void:
	_document = CyberspaceContentDocument.new(); _document_path = ""; _state = AuthoringEditorState.new(); _preview.set_editor_state(_state); _bind_document(); _validation.add_entry("INFO", "New authoring document created.")


func _choose_open() -> void:
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	for connection in _file_dialog.file_selected.get_connections(): _file_dialog.file_selected.disconnect(connection.callable)
	_file_dialog.file_selected.connect(_open); _file_dialog.popup_file_dialog()


func _open(path: String) -> void:
	var loaded := ResourceLoader.load(path)
	if not loaded is CyberspaceContentDocument: _validation.add_entry("ERROR", "Selected Resource is not a CyberspaceContentDocument."); return
	_document = loaded; _document_path = path; _state = _load_state(path); _preview.set_editor_state(_state); _bind_document(); _validation.add_entry("OPEN", path)


func _save() -> void:
	if _document_path.is_empty():
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		for connection in _file_dialog.file_selected.get_connections(): _file_dialog.file_selected.disconnect(connection.callable)
		_file_dialog.file_selected.connect(func(path): _document_path = path; _save()); _file_dialog.current_file = "cyberspace_content.tres"; _file_dialog.popup_file_dialog(); return
	var error := ResourceSaver.save(_document, _document_path)
	_state.document_path = _document_path; ResourceSaver.save(_state, _state_path(_document_path))
	_validation.add_entry("SAVE" if error == OK else "ERROR", "Saved %s" % _document_path if error == OK else "Save failed: %s" % error)


func _validate_all() -> void:
	for issue: Dictionary in AuthoringValidator.new().validate(_document): _validation.add_entry(issue.level, "%s // %s" % [issue.category, issue.message], issue.entry_id)


func _play_from_here() -> void:
	if _editor_interface == null: return
	_save(); _validation.add_entry("PREVIEW", "Play request uses runtime project only; editor plugin classes are not loaded by gameplay.")
	_editor_interface.play_main_scene()


func _apply_template(index: int) -> void:
	var template_id: StringName = TemplateLibrary.NAMES[index]; var created := TemplateLibrary.new().apply(_document, template_id); _document_changed(); _validation.add_entry("TEMPLATE", "%s created: %s" % [template_id, created])


func _select_entry(value: Variant) -> void:
	var id := StringName(value); _state.selected_id = id; _inspector.show_entry(id)


func _document_changed() -> void: _browser.refresh()
func _bind_document() -> void: _browser.set_document(_document); _workspace.set_models(_document, _state); _inspector.set_document(_document)
func _state_path(path: String) -> String: return path.trim_suffix(".tres") + ".editor_state.tres"
func _load_state(path: String) -> AuthoringEditorState:
	var state_path := _state_path(path); var loaded := ResourceLoader.load(state_path) if ResourceLoader.exists(state_path) else null
	return loaded if loaded is AuthoringEditorState else AuthoringEditorState.new()
