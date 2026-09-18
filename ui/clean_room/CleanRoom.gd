class_name CleanRoom
extends Control
const FirstMeatspaceTutorial = preload("res://core/story/FirstMeatspaceTutorial.gd")

@onready var go_button: Button = %GoButton
@onready var home_button: Button = %HomeButton
@onready var credits_label: Label = %CreditsLabel
@onready var connection_label: Label = %ConnectionLabel
@onready var buy_link_button: Button = %BuyLinkButton
@onready var available_programs: OptionButton = %AvailablePrograms
@onready var loaded_programs: OptionButton = %LoadedPrograms
@onready var slots_label: Label = %SlotsLabel
@onready var message_label: Label = %MessageLabel
@onready var controls_button: Button = %ControlsButton
@onready var controls_sheet: Control = %ControlsSheet
@onready var primary_bindings: Label = %PrimaryBindings
@onready var alternate_bindings: Label = %AlternateBindings
@onready var tutorial_hint: Label = %TutorialHint
var available_ids: Array[StringName] = []
var loaded_ids: Array[StringName] = []
var _focus_gesture_armed := true
var ally_ids: Array[StringName] = []
var contact_actions: Array[StringName] = []

func _ready() -> void:
	go_button.pressed.connect(_go)
	home_button.pressed.connect(_home)
	buy_link_button.pressed.connect(_buy_link)
	%LoadButton.pressed.connect(_load_program)
	%UnloadButton.pressed.connect(_unload_program)
	%ContactButton.pressed.connect(_contact_latch)
	%ContactSelect.item_selected.connect(_select_contact)
	%ContactActionButton.pressed.connect(_perform_contact_action)
	%InboxButton.pressed.connect(_read_message)
	controls_button.pressed.connect(open_controls)
	%CloseControlsButton.pressed.connect(close_controls)
	EventBus.game_domain_changed.connect(_on_domain_changed)
	EventBus.session_started.connect(_on_session_started)
	GameplayBindings.semantic_action_triggered.connect(_on_semantic_action)
	GameplayBindings.device_mode_changed.connect(_on_device_mode_changed)
	visible = Game.game_domain == Game.GameDomain.CLEAN_ROOM
	if visible:
		GameplayBindings.set_context(GameplayBindings.Context.CLEAN_ROOM)
		_bind_controller(); _focus_default_for_device()
	_update_controls_for_device()

func _on_session_started() -> void:
	visible = Game.game_domain == Game.GameDomain.CLEAN_ROOM
	if visible:
		GameplayBindings.set_context(GameplayBindings.Context.CLEAN_ROOM)
		_bind_controller(); _focus_default_for_device()

func _on_domain_changed(_previous: int, current: int) -> void:
	visible = current == Game.GameDomain.CLEAN_ROOM
	if visible:
		GameplayBindings.set_context(GameplayBindings.Context.CLEAN_ROOM)
		_bind_controller(); _focus_default_for_device()

func _bind_controller() -> void:
	var controller: CleanRoomController = Game.clean_room_controller
	if controller == null: return
	if not controller.state_changed.is_connected(_refresh): controller.state_changed.connect(_refresh)
	if not controller.ally_contacted.is_connected(_show_contact): controller.ally_contacted.connect(_show_contact)
	_refresh(controller.view())
	_refresh_tutorial_hint()
	var flags: Dictionary = Game.persistent_game_state.campaign_state.get("story_flags", {})
	if bool(flags.get(&"CLEAN_ROOM_LATCH_CONTACTED", false)) and message_label.text.is_empty():
		message_label.text = "LATCH // Clean signal. Configure the deck, then use GO when you're ready."

func _refresh(view: Dictionary) -> void:
	credits_label.text = "%d ICs" % int(view.get("credits", 0))
	var value := int(view.get("connection_value", 1))
	connection_label.text = "CONNECTION %d\nTRACE WINDOW ×%.2f  //  TRANSFER TIME ×%.2f" % [value, float(view.get("trace_resolution_multiplier", 1.0)), float(view.get("transfer_duration_multiplier", 1.0))]
	var cost := int(view.get("next_link_cost", -1))
	buy_link_button.text = "MAXIMUM LINK" if cost < 0 else "BUY LINK  //  %d ICs" % cost
	buy_link_button.disabled = cost < 0 or int(view.get("credits", 0)) < cost
	%MissionLabel.text = _mission_text(view.get("mission_briefing", {}), view.get("mission_debrief", {}))
	%MissionLabel.visible = not %MissionLabel.text.is_empty()
	available_ids.clear(); loaded_ids.clear(); available_programs.clear(); loaded_programs.clear()
	var installed: Array = view.get("installed_instance_ids", [])
	for item: Dictionary in view.get("owned_programs", []):
		var id := StringName(item.instance_id)
		if installed.has(id):
			loaded_ids.append(id); loaded_programs.add_item(String(item.display_name))
		else:
			available_ids.append(id); available_programs.add_item(String(item.display_name))
	slots_label.text = "ACTIVE SLOTS  %d / %d" % [loaded_ids.size(), int(view.get("active_slot_capacity", 0))]
	%AllyStatus.text = "LATCH // %s    %s" % [String(view.get("ally_status", "OFFLINE")), ("â— %d UNREAD" % int(view.get("unread_count", 0))) if int(view.get("unread_count", 0)) > 0 else "NO NEW MESSAGES"]
	%InboxButton.disabled = int(view.get("unread_count", 0)) == 0
	%InboxButton.text = "READ PRIORITY MESSAGE" if bool(view.get("critical_unread", false)) else "READ MESSAGE"
	%LoadButton.disabled = available_ids.is_empty() or loaded_ids.size() >= int(view.get("active_slot_capacity", 0))
	%UnloadButton.disabled = loaded_ids.is_empty()
	ally_ids.clear(); %ContactSelect.clear()
	for ally: Dictionary in view.get("allies", []): ally_ids.append(StringName(ally.contact_id)); %ContactSelect.add_item(String(ally.display_name))
	%ContactSelect.visible = not ally_ids.is_empty(); %ContactActionButton.visible = not ally_ids.is_empty()
	if not ally_ids.is_empty(): _select_contact(clampi(%ContactSelect.selected, 0, ally_ids.size() - 1))

func _mission_text(briefing: Dictionary, debrief: Dictionary) -> String:
	if not debrief.is_empty():
		var optional_lines := PackedStringArray()
		for item: Dictionary in debrief.get("optional_objectives", []): optional_lines.append("%s: %s" % [String(item.get("description", item.get("objective_id", "OPTIONAL"))), "COMPLETE" if item.get("state") == ObjectiveDefinition.COMPLETED else "MISSED"])
		return "MISSION RESULT // %s\nPRIMARY: %s\nOPTIONAL: %s\nTRACE: %s  //  REWARD: +%d ICs" % ["SUCCESS" if bool(debrief.get("success", false)) else "FAILURE", String(debrief.get("primary_result", "")), "; ".join(optional_lines), String(debrief.get("trace_result", "CLEAR")), int(debrief.get("ic_reward", 0))]
	if briefing.is_empty(): return ""
	var primary: Array = briefing.get("primary_objectives", []); var optional: Array = briefing.get("optional_objectives", [])
	var optional_labels := PackedStringArray(optional.map(func(item: Dictionary) -> String: return String(item.description)))
	var constraints := PackedStringArray(briefing.get("known_constraints", []))
	return "MISSION // %s\nPRIMARY: %s\nOPTIONAL: %s\nCONSTRAINTS: %s\nREWARD: %s" % [String(briefing.get("title", "")), String(primary[0].description) if not primary.is_empty() else "Unspecified", "; ".join(optional_labels), "; ".join(constraints), String((briefing.get("reward", {}) as Dictionary).get("description", "None"))]

func _go() -> void:
	var result := Game.enter_netspace_from_clean_room(); message_label.text = result.reason
func _home() -> void:
	var result := Game.return_home_from_clean_room(); message_label.text = result.reason
func _buy_link() -> void:
	var result := Game.clean_room_controller.buy_link(); message_label.text = result.reason
func _load_program() -> void:
	if available_programs.selected >= 0 and available_programs.selected < available_ids.size(): Game.clean_room_controller.install_program(available_ids[available_programs.selected])
func _unload_program() -> void:
	if loaded_programs.selected >= 0 and loaded_programs.selected < loaded_ids.size(): Game.clean_room_controller.remove_program(loaded_ids[loaded_programs.selected])
func _contact_latch() -> void:
	if ally_ids.is_empty(): message_label.text = "NO ALLIES AVAILABLE"; return
	var selected := clampi(%ContactSelect.selected, 0, ally_ids.size() - 1); _show_contact(Game.clean_room_controller.contact_ally(ally_ids[selected]))
func _select_contact(index: int) -> void:
	contact_actions.clear(); %ContactInteraction.clear()
	if index < 0 or index >= ally_ids.size(): return
	var selected := Game.clean_room_controller.contact_ally(ally_ids[index])
	if not selected.success: return
	for interaction: Dictionary in selected.contact.interactions: contact_actions.append(StringName(interaction.interaction_id)); %ContactInteraction.add_item(String(interaction.label))
	%ContactActionButton.disabled = contact_actions.is_empty()
func _perform_contact_action() -> void:
	if ally_ids.is_empty() or contact_actions.is_empty(): return
	var contact_index := clampi(%ContactSelect.selected, 0, ally_ids.size() - 1); var action_index := clampi(%ContactInteraction.selected, 0, contact_actions.size() - 1)
	var result := Game.clean_room_controller.contact_interaction(ally_ids[contact_index], contact_actions[action_index]); message_label.text = result.get("reason", "CONTACT ACTION STARTED")
func _read_message() -> void:
	var result := Game.clean_room_controller.read_next_message()
	if result.success:
		var message: Dictionary = result.message
		message_label.text = "%s // %s" % [String(message.actor_id), String(message.text)]
	else: message_label.text = result.reason
func _show_contact(event: Dictionary) -> void:
	message_label.text = "LATCH // %s" % String(event.get("text", "Channel open."))

func _process(_delta: float) -> void:
	if not visible: return
	var direction := GameplayBindings.focus_vector()
	if direction.length() < 0.3: _focus_gesture_armed = true
	elif _focus_gesture_armed:
		_focus_gesture_armed = false; _focus_control(direction)

func _focus_control(direction: Vector2) -> void:
	var controls: Array[Control] = [%CloseControlsButton] if controls_sheet.visible else [go_button, home_button, controls_button, buy_link_button, available_programs, %LoadButton, loaded_programs, %UnloadButton, %InboxButton, %ContactButton]
	var candidates: Array[Dictionary] = []
	for control: Control in controls:
		candidates.append({"id": StringName(control.name), "position": control.get_global_rect().get_center(), "priority": 500.0 if control == go_button else 0.0, "enabled": control.visible and not bool(control.get("disabled"))})
	var owner := get_viewport().gui_get_focus_owner()
	var current := StringName(owner.name) if owner != null and owner in controls else &""
	var next := DirectionalFocusSelector.choose(current, direction, candidates)
	for control: Control in controls:
		if StringName(control.name) == next: control.grab_focus(); break

func _on_semantic_action(action_id: StringName) -> void:
	if not visible: return
	if action_id == &"primary_action":
		var owner := get_viewport().gui_get_focus_owner()
		if owner is Button and owner.is_visible_in_tree() and not owner.disabled: owner.pressed.emit()
	elif action_id == &"back_action":
		if controls_sheet.visible: close_controls()
		else: message_label.text = "SELECT RETURN HOME TO LEAVE THE CLEAN-ROOM."
	elif action_id == &"open_loadout": available_programs.grab_focus()

func _on_device_mode_changed(_mode: int) -> void:
	_update_controls_for_device()
	_refresh_tutorial_hint()
	if visible and not controls_sheet.visible: _focus_default_for_device()

func _focus_default_for_device() -> void:
	if GameplayBindings.device_mode == GameplayBindings.DeviceMode.GAMEPAD: go_button.grab_focus()

func open_controls() -> void:
	controls_sheet.visible = true
	_update_controls_for_device()
	%CloseControlsButton.grab_focus()

func close_controls() -> void:
	controls_sheet.visible = false
	controls_button.grab_focus()

func _update_controls_for_device() -> void:
	if primary_bindings == null or alternate_bindings == null: return
	var controller := "CONTROLLER\n\nNETSPACE\nLeft Stick  —  Pan camera\nRight Stick  —  Select target/node\nD-pad Left/Right  —  Previous/next contextual command\nA / Cross  —  Primary contextual action\nD-pad Up  —  Class special skill\nLB / RB  —  Previous/next active program slot\nRT / R2  —  Execute selected active program\nLT / L2  —  Manage selected active program slot\nR3  —  Recenter camera\nB / Circle  —  Back one interaction level\n\nCLEAN-ROOM\nRight Stick / D-pad  —  Select UI element\nA / Cross  —  Activate\nB / Circle  —  Back / close\n\nMEATSPACE\nController focus  —  Examine\nA / Cross  —  Interact\nB / Circle  —  Close UI / return one level"
	var keyboard := "KEYBOARD + MOUSE\n\nNETSPACE\nWASD  —  Pan camera\nMouse  —  Select target/node\nZ / .  —  Previous/next contextual command\nLeft Click  —  Primary contextual action\nU  —  Class special skill\nQ / E  —  Previous/next active program slot\nF  —  Execute selected active program\nTab  —  Manage selected active program slot\nSpace  —  Recenter camera\nEscape  —  Back one interaction level\n\nCLEAN-ROOM\nMouse  —  Select UI element\nLeft Click  —  Activate\nEscape  —  Back / close\n\nMEATSPACE\nMouse hover  —  Examine\nLeft Click  —  Interact\nEscape  —  Close UI / return one level"
	var gamepad_active := GameplayBindings.device_mode == GameplayBindings.DeviceMode.GAMEPAD
	primary_bindings.text = controller if gamepad_active else keyboard
	alternate_bindings.text = keyboard if gamepad_active else controller
	primary_bindings.modulate = Color(0.03, 0.18, 0.22, 1.0)
	alternate_bindings.modulate = Color(0.03, 0.18, 0.22, 0.58)

func _refresh_tutorial_hint() -> void:
	if tutorial_hint == null or Game.persistent_game_state == null: return
	var step := FirstMeatspaceTutorial.reconcile(Game.persistent_game_state)
	var active := step == FirstMeatspaceTutorial.Step.ENTER_CLEAN_ROOM
	tutorial_hint.visible = active
	go_button.modulate = Color("d5f8ff") if active else Color.WHITE
	controls_button.modulate = Color("e4f4f5") if active else Color.WHITE
	home_button.modulate = Color("f2f6f6") if active else Color.WHITE
	if active: tutorial_hint.text = "GO  —  enter Netspace     •     CONTROLS  —  review controls     •     RETURN HOME  —  back to Meatspace"
