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
@export var show_progression_debug := false
var debug_label: Label
var selected_object: Dictionary = {}
var observed_state: PersistentGameState

func _ready() -> void:
	EventBus.session_started.connect(_refresh)
	EventBus.game_domain_changed.connect(_on_domain_changed)
	bedroom.object_selected.connect(_on_room_object_selected)
	action_panel.action_requested.connect(_physical_action)
	time_selector.hide()
	action_panel.hide()
	%DismissChoices.pressed.connect(func() -> void: choice_panel.get_parent().hide())
	debug_label = Label.new()
	debug_label.position = Vector2(18, 65)
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(debug_label)
	_refresh()

func _on_domain_changed(_previous: int, _current: int) -> void:
	_refresh()

func _set_time(index: int) -> void:
	physical_interactions.set_time_of_day(time_selector.get_item_text(index))
	_update_status()

func _update_status() -> void:
	if physical_interactions.state == null: return
	var state := physical_interactions.state
	if debug_label != null:
		debug_label.visible = OS.is_debug_build() and show_progression_debug
		if debug_label.visible: debug_label.text = JSON.stringify(Game.prologue_controller.progression_view(), "  ")
	var time := String(state.world_state.get("time_of_day", "NIGHT"))
	phase_label.text = "BEDROOM  //  %s  //  FATIGUE %d  //  %d ICs" % [time, int(state.player_state.get("fatigue", 0)), int(state.player_state.get("credits", 0))]
	for index in range(time_selector.item_count):
		if time_selector.get_item_text(index) == time: time_selector.select(index)

func _state_changed() -> void:
	_update_status()
	_present_actions()
	if choice_panel.get_parent().visible and Game.prologue_controller != null:
		var selected := Game.prologue_controller.selected_interaction_id
		if not selected.is_empty(): _select_interaction(selected)
		else: choice_panel.get_parent().hide()

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
	%DismissChoices.text = "CANCEL" if String(interaction_id).begins_with("CLASS_") else "BACK TO ROOM"
	if bool(interaction.get("show_costs", false)): choice_prompt.text += "\nBalance: %d ICs" % int(Game.persistent_game_state.player_state.get("credits", 0))
	_clear(choice_list)
	for choice: Dictionary in interaction.get("choices", []):
		var button := Button.new()
		var cost := Game.prologue_controller.choice_cost(choice)
		var price := "  -  %d ICs" % cost if bool(interaction.get("show_costs", false)) or cost > 0 else ""
		if cost < 0: price = "  -  Damage-based IC cost"
		button.text = "%s%s\n%s" % [String(choice.get("label", choice.id)), price, String(choice.get("description", ""))]
		button.disabled = not Game.prologue_controller.choice_available(choice)
		if bool(interaction.get("show_costs", false)) or button.disabled:
			button.text += "\n" + Game.prologue_controller.choice_status(choice)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 58)
		button.pressed.connect(_choose.bind(interaction_id, StringName(choice.id)))
		choice_list.add_child(button)
	if choice_list.get_child_count() > 0: (choice_list.get_child(0) as Control).grab_focus()

func _on_room_object_selected(object_data: Dictionary) -> void:
	selected_object = object_data.duplicate(true)
	choice_panel.get_parent().hide()
	var id := StringName(object_data.id)
	if object_data.get("primary_action") == "CLASS":
		_select_interaction(StringName("CLASS_" + String(object_data.class_id)))
	elif object_data.get("primary_action") == "CONNECT":
		result_label.text = "Connecting..."
		var connected := Game.prologue_controller.connect_first_contact()
		if not connected.success: result_label.text = String(connected.reason)
	elif object_data.get("primary_action", "PHYSICAL") == "STORY":
		physical_interactions.primary(id)
		_physical_action(id, &"STORY")
	else:
		var result := physical_interactions.primary(id)
		result_label.text = String(result.get("text", ""))
	_update_status()

func _present_actions() -> void:
	action_panel.hide()

func _physical_action(object_id: StringName, verb: StringName) -> void:
	if selected_object.is_empty() or StringName(selected_object.id) != object_id: return
	if verb != &"STORY":
		var result := physical_interactions.execute(object_id, verb)
		result_label.text = String(result.text)
		_present_actions()
		_update_status()
		return
	var object_data := selected_object
	result_label.text = ""
	var controller: MeatspacePrologueController = Game.prologue_controller
	if controller == null: return
	var phase_links: Dictionary = object_data.get("phase_interactions", {})
	var interaction_id := StringName(object_data.get("story_interaction", phase_links.get(controller.phase, &"")))
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

func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		show_progression_debug = not show_progression_debug
		_update_status()
		accept_event()
