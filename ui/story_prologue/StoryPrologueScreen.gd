class_name StoryPrologueScreen
extends Control
const FirstMeatspaceTutorial = preload("res://core/story/FirstMeatspaceTutorial.gd")

@onready var phase_label: Label = %PhaseLabel
@onready var narrative_label: Label = %NarrativeLabel
@onready var interaction_list: VBoxContainer = %InteractionList
@onready var choice_panel: VBoxContainer = %ChoicePanel
@onready var choice_title: Label = %ChoiceTitle
@onready var choice_prompt: Label = %ChoicePrompt
@onready var choice_list: VBoxContainer = %ChoiceList
@onready var result_label: Label = %ResultLabel
@onready var bedroom: PlayerBedroom = %PlayerBedroom
@onready var location_host: Control = %LocationHost
@onready var travel_fade: ColorRect = %TravelFade
@onready var action_panel: MeatspaceActionPanel = %ActionPanel
@onready var time_selector: OptionButton = %TimeSelector
var physical_interactions := MeatspaceInteractionController.new()
@export var show_progression_debug := false
var debug_label: Label
var selected_object: Dictionary = {}
var observed_state: PersistentGameState
var current_location_view: MeatspaceRoomView3D
var loaded_location_id: StringName = &""
var travel_selector_open := false
var travel_buttons: Array[Button] = []
var _travel_focus_armed := true

func _ready() -> void:
	EventBus.session_started.connect(_refresh)
	EventBus.game_domain_changed.connect(_on_domain_changed)
	bedroom.object_selected.connect(_on_room_object_selected)
	action_panel.action_requested.connect(_physical_action)
	time_selector.hide()
	action_panel.hide()
	%DismissChoices.pressed.connect(_dismiss_choices)
	GameplayBindings.semantic_action_triggered.connect(_on_semantic_action)
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
		if debug_label.visible: debug_label.text = JSON.stringify(_chapter_debug_view(), "  ")
	var time := String(state.world_state.get("time_of_day", "NIGHT"))
	var location := physical_interactions.get_location_definition(physical_interactions.current_meatspace_location())
	phase_label.text = "%s  //  %s  //  FATIGUE %d  //  %d ICs" % [String(location.get("display_name", "MEATSPACE")).to_upper(), time, int(state.player_state.get("fatigue", 0)), int(state.player_state.get("credits", 0))]
	for index in range(time_selector.item_count):
		if time_selector.get_item_text(index) == time: time_selector.select(index)

func _chapter_debug_view() -> Dictionary:
	var story := StoryState.new(Game.persistent_game_state)
	var run: Dictionary = Game.story_mission_system.active_run if Game.story_mission_system != null else {}
	return {"chapter": story.get_state(&"current_story_chapter", &"intro"), "deck_choice": Game.persistent_game_state.player_state.get("selected_deck_variant", &""), "active_slots": Game.persistent_game_state.player_state.get("active_slot_count", 2), "latch_unlocked": story.is_contact_unlocked(&"latch"), "mission_status": Game.story_mission_system.status(&"glasshouse_01") if Game.story_mission_system != null else &"LOCKED", "objectives": run.get("objectives", {}), "trace": Game.trace_level, "alarm": run.get("alarm_triggered", false), "flags": Game.persistent_game_state.campaign_state.get("story_flags", {}), "chapter_complete": story.get_flag(&"glasshouse_completed")}

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
	_show_current_location()
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
	travel_selector_open = false
	if current_location_view != null: current_location_view.call_deferred("focus_first")

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
		var description := String(choice.get("description", ""))
		if choice.get("id") == "DECK_SCOUT": description = "Carry more active programs during a run."
		elif choice.get("id") == "DECK_BALANCED": description = "Carry more files and stored programs."
		button.text = "%s%s\n%s" % [String(choice.get("label", choice.id)), price, description]
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
	elif object_data.get("primary_action") == "TRAVEL":
		_open_travel_selector()
	elif object_data.get("primary_action") == "CONNECT":
		result_label.text = "Connecting..."
		var connected := Game.prologue_controller.connect_first_contact()
		if not connected.success: result_label.text = String(connected.reason)
	elif object_data.get("primary_action", "PHYSICAL") == "STORY":
		physical_interactions.primary(id)
		if id == &"STARTER_DECK_BOX": FirstMeatspaceTutorial.advance_to(physical_interactions.state, FirstMeatspaceTutorial.Step.CHOOSE_DECK)
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

func _show_current_location() -> void:
	var location_id := physical_interactions.current_meatspace_location()
	if loaded_location_id == location_id and current_location_view != null: return
	for child in location_host.get_children():
		location_host.remove_child(child); child.queue_free()
	loaded_location_id = location_id
	bedroom.visible = location_id == &"HOME"
	if bedroom.visible:
		current_location_view = bedroom
		bedroom.bind_state(physical_interactions.state)
		return
	var location := physical_interactions.get_location_definition(location_id)
	var packed := load(String(location.get("scene_path", ""))) as PackedScene
	if packed == null:
		result_label.text = "Destination scene unavailable."
		physical_interactions.travel_to(&"HOME")
		loaded_location_id = &""
		_show_current_location()
		return
	current_location_view = packed.instantiate() as MeatspaceRoomView3D
	location_host.add_child(current_location_view)
	current_location_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current_location_view.object_selected.connect(_on_room_object_selected)
	current_location_view.bind_state(physical_interactions.state)

func _open_travel_selector() -> void:
	var destinations := physical_interactions.get_available_meatspace_destinations()
	if destinations.is_empty():
		result_label.text = "There is nowhere to go."
		return
	travel_selector_open = true
	choice_panel.visible = true
	choice_panel.get_parent().show()
	choice_title.text = "WHERE TO?"
	choice_prompt.text = "SELECT A DESTINATION"
	%DismissChoices.text = "CANCEL"
	choice_panel.move_child(%DismissChoices, choice_panel.get_child_count() - 1)
	_clear(choice_list)
	travel_buttons.clear()
	for destination: Dictionary in destinations:
		var button := Button.new()
		button.name = "Travel_%s" % destination.id
		button.text = String(destination.display_name).to_upper()
		button.tooltip_text = String(destination.get("description", ""))
		button.custom_minimum_size = Vector2(0, 54)
		button.pressed.connect(_travel_to.bind(StringName(destination.id)))
		choice_list.add_child(button)
		travel_buttons.append(button)
	if not travel_buttons.is_empty(): travel_buttons[0].grab_focus()

func _travel_to(destination_id: StringName) -> void:
	var result := physical_interactions.travel_to(destination_id)
	if not result.get("success", false):
		result_label.text = String(result.get("reason", "Travel unavailable.")); return
	travel_selector_open = false
	choice_panel.get_parent().hide()
	_show_current_location()
	var destination: Dictionary = result.destination
	phase_label.text = "MEATSPACE  //  %s" % String(destination.display_name).to_upper()
	result_label.text = String(destination.description)
	travel_fade.show(); travel_fade.modulate.a = 1.0
	var tween := create_tween(); tween.tween_property(travel_fade, "modulate:a", 0.0, 0.18); tween.tween_callback(travel_fade.hide)
	if current_location_view != null: current_location_view.call_deferred("focus_first")

func _cancel_travel_selector() -> void:
	travel_selector_open = false
	choice_panel.get_parent().hide()
	if current_location_view != null: current_location_view.grab_focus()

func _dismiss_choices() -> void:
	if travel_selector_open: _cancel_travel_selector()
	else: choice_panel.get_parent().hide()

func _on_semantic_action(action_id: StringName) -> void:
	if travel_selector_open and action_id == &"back_action": _cancel_travel_selector()

func _process(_delta: float) -> void:
	if not travel_selector_open: return
	var direction := GameplayBindings.focus_vector()
	if absf(direction.y) < 0.35: _travel_focus_armed = true
	elif _travel_focus_armed and not travel_buttons.is_empty():
		_travel_focus_armed = false
		var focused := get_viewport().gui_get_focus_owner()
		var index := travel_buttons.find(focused)
		travel_buttons[posmod(index + (1 if direction.y > 0 else -1), travel_buttons.size())].grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if travel_selector_open and event.is_action_pressed(&"ui_cancel"):
		_cancel_travel_selector(); accept_event(); return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		show_progression_debug = not show_progression_debug
		_update_status()
		accept_event()
