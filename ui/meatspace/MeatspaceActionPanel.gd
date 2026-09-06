class_name MeatspaceActionPanel
extends PanelContainer
## Compact authored verb presentation, shared by physical locations.
signal action_requested(object_id: StringName, verb_id: StringName)
var object_id: StringName
var verbs: HFlowContainer
var title: Label

func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	title = Label.new()
	title.text = "Point at an object to examine it"
	column.add_child(title)
	verbs = HFlowContainer.new()
	column.add_child(verbs)

func present(id: StringName, display_name: String, actions: Array[Dictionary]) -> void:
	object_id = id
	title.text = display_name
	for child in verbs.get_children():
		verbs.remove_child(child)
		child.queue_free()
	for action: Dictionary in actions:
		var button := Button.new()
		button.text = String(action.get("label", action.id))
		button.pressed.connect(_request.bind(id, StringName(action.id)))
		verbs.add_child(button)

func _request(id: StringName, verb: StringName) -> void:
	action_requested.emit(id, verb)
