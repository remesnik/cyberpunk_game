class_name StoryPrologueScreen
extends Control

@onready var phase_label: Label = %PhaseLabel
@onready var narrative_label: Label = %NarrativeLabel
@onready var interaction_list: VBoxContainer = %InteractionList
@onready var choice_panel: VBoxContainer = %ChoicePanel
@onready var choice_title: Label = %ChoiceTitle
@onready var choice_prompt: Label = %ChoicePrompt
@onready var choice_list: VBoxContainer = %ChoiceList
@onready var result_label: Label = %ResultLabel
@onready var bedroom: PlayerBedroom = %PlayerBedroom
@onready var action_panel: MeatspaceActionPanel = %ActionPanel
@onready var time_selector: OptionButton = %TimeSelector
var physical_interactions := MeatspaceInteractionController.new()
var selected_object: Dictionary = {}
var observed_state: PersistentGameState

func _ready() -> void:
	EventBus.session_started.connect(_refresh)
	EventBus.game_domain_changed.connect(_on_domain_changed)
	bedroom.object_selected.connect(_on_room_object_selected)
	action_panel.action_requested.connect(_physical_action)
	for time in ["DAY", "DUSK", "NIGHT", "DAWN"]: time_selector.add_item(time)
	time_selector.item_selected.connect(_set_time)
	%DismissChoices.pressed.connect(func() -> void: choice_panel.get_parent().hide())
	_refresh()

func _on_domain_changed(_previous: int, _current: int) -> void:
	_refresh()

func _set_time(index: int) -> void:
	physical_interactions.set_time_of_day(time_selector.get_item_text(index))
	_update_status()

func _update_status() -> void:
	if physical_interactions.state == null: return
	var state := physical_interactions.state
	var time := String(state.world_state.get("time_of_day", "NIGHT"))
	phase_label.text = "BEDROOM  //  %s  //  FATIGUE %d" % [time, int(state.player_state.get("fatigue", 0))]
	for index in range(time_selector.item_count):
		if time_selector.get_item_text(index) == time: time_selector.select(index)

func _state_changed() -> void:
	_update_status()
	_present_actions()

func _exit_tree() -> void:
	if observed_state != null and observed_state.changed.is_connected(_state_changed): observed_state.changed.disconnect(_state_changed)

func _refresh() -> void:
	var controller: MeatspacePrologueController = Game.prologue_controller
	bedroom.bind_state(controller.game_state if controller != null else null)
	physical_interactions.configure(bedroom.location_definition, controller.game_state if controller != null else null)
	if observed_state != physical_interactions.state:
		if observed_state != null and observed_state.changed.is_connected(_state_changed): observed_state.changed.disconnect(_state_changed)
		observed_state = physical_interactions.state
		if observed_state != null: observed_state.changed.connect(_state_changed)
	visible = controller != null and Game.game_domain == Game.GameDomain.MEATSPACE
	if not visible: return
	var state := controller.view()
	phase_label.text = "LOCAL STATE // %s" % String(state.phase).replace("_", " ")
	_update_status()
	narrative_label.text = String(state.opening_text)
	_clear(interaction_list)
	for interaction: Dictionary in state.interactions:
		var button := Button.new()
		button.text = "[ %s ]\n%s" % [String(interaction.get("display_name", interaction.id)).to_upper(), interaction.get("description", "")]
		button.custom_minimum_size = Vector2(0, 62)
		button.pressed.connect(_select_interaction.bind(StringName(interaction.id)))
		interaction_list.add_child(button)
	choice_panel.visible = false
	choice_panel.get_parent().hide()
	bedroom.call_deferred("focus_first")

func _select_interaction(interaction_id: StringName) -> void:
	var selected := Game.prologue_controller.select_interaction(interaction_id)
	if not selected.get("success", false): result_label.text = selected.get("reason", "INTERACTION UNAVAILABLE"); return
	var interaction: Dictionary = selected.interaction
	choice_panel.visible = true
	choice_panel.get_parent().show()
	choice_title.text = String(interaction.get("display_name", interaction_id)).to_upper()
	choice_prompt.text = String(interaction.get("prompt", "SELECT RESPONSE"))
	_clear(choice_list)
	for choice: Dictionary in interaction.get("choices", []):
		var button := Button.new()
		button.text = "%s\n%s" % [String(choice.get("label", choice.id)), String(choice.get("description", ""))]
		button.custom_minimum_size = Vector2(0, 58)
		button.pressed.connect(_choose.bind(interaction_id, StringName(choice.id)))
		choice_list.add_child(button)
	if choice_list.get_child_count() > 0: (choice_list.get_child(0) as Control).grab_focus()

func _on_room_object_selected(object_data: Dictionary) -> void:
	selected_object = object_data.duplicate(true)
	_present_actions()
	choice_panel.get_parent().hide()
	result_label.text = ""

func _present_actions() -> void:
	if selected_object.is_empty(): return
	var object_data := selected_object
	var actions := physical_interactions.actions_for(StringName(object_data.id))
	var controller: MeatspacePrologueController = Game.prologue_controller
	if controller != null and object_data.get("phase_interactions", {}).has(controller.phase):
		actions.append({"id": "STORY", "label": "CONNECT" if StringName(object_data.id) == &"JACK_IN_INTERFACE" else "USE"})
	action_panel.present(StringName(object_data.id), String(object_data.get("display_name", object_data.id)), actions)

func _physical_action(object_id: StringName, verb: StringName) -> void:
	if selected_object.is_empty() or StringName(selected_object.id) != object_id: return
	if verb != &"STORY":
		var result := physical_interactions.execute(object_id, verb)
		result_label.text = String(result.text)
		_present_actions()
		_update_status()
		return
	var object_data := selected_object
	result_label.text = "%s  %s\n%s" % [object_data.get("display_name", object_data.get("id", "OBJECT")), object_data.get("interaction_text", "[ INTERACT ]"), object_data.get("description", "")]
	var controller: MeatspacePrologueController = Game.prologue_controller
	if controller == null: return
	var phase_links: Dictionary = object_data.get("phase_interactions", {})
	var interaction_id := StringName(phase_links.get(controller.phase, &""))
	if not interaction_id.is_empty(): _select_interaction(interaction_id)

func _choose(interaction_id: StringName, choice_id: StringName) -> void:
	var controller: MeatspacePrologueController = Game.prologue_controller
	if controller == null: return
	var result := controller.choose(interaction_id, choice_id)
	if not result.get("success", false): result_label.text = result.get("reason", "CHOICE REJECTED"); return
	result_label.text = String(result.event.get("text", ""))
	call_deferred("_refresh")
	call_deferred("_present_actions")

func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
