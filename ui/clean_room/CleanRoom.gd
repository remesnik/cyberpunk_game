class_name CleanRoom
extends Control

const FirstMeatspaceTutorial = preload("res://core/story/FirstMeatspaceTutorial.gd")

@onready var go_button: Button = %GoButton
@onready var home_button: Button = %HomeButton
@onready var controls_button: Button = %ControlsButton
@onready var controls_sheet: Control = %ControlsSheet
@onready var primary_bindings: Label = %PrimaryBindings
@onready var alternate_bindings: Label = %AlternateBindings
@onready var tutorial_hint: Label = %TutorialHint
@onready var loadout_panel: Control = %LoadoutPanel
@onready var readiness_label: Label = %ReadinessLabel

var _stored_ids: Array[StringName] = []
var _installed_ids: Array[StringName] = []
var _running_ids: Array[StringName] = []
var _stored_active_ids: Array[StringName] = []
var _focus_gesture_armed := true
var _reconfiguration_was_active := false

func _ready() -> void:
	go_button.pressed.connect(_go)
	home_button.pressed.connect(_home)
	controls_button.pressed.connect(open_controls)
	%CloseControlsButton.pressed.connect(close_controls)
	%LoadoutButton.pressed.connect(open_loadout)
	%CloseLoadoutButton.pressed.connect(close_loadout)
	%InstallButton.pressed.connect(_install_selected)
	%RemoveButton.pressed.connect(_remove_selected)
	%SwapButton.pressed.connect(_swap_selected)
	EventBus.game_domain_changed.connect(_on_domain_changed)
	EventBus.session_started.connect(_on_session_started)
	GameplayBindings.semantic_action_triggered.connect(_on_semantic_action)
	GameplayBindings.device_mode_changed.connect(_on_device_mode_changed)
	visible = Game.game_domain == Game.GameDomain.CLEAN_ROOM
	if visible: _activate()
	_update_controls_for_device()

func _activate() -> void:
	GameplayBindings.set_context(GameplayBindings.Context.CLEAN_ROOM)
	var controller: CleanRoomController = Game.clean_room_controller
	if controller != null:
		if not controller.state_changed.is_connected(_refresh): controller.state_changed.connect(_refresh)
		_refresh(controller.view())
	_refresh_tutorial_hint()
	_focus_default_for_device()

func _on_session_started() -> void:
	visible = Game.game_domain == Game.GameDomain.CLEAN_ROOM
	if visible: _activate()

func _on_domain_changed(_previous: int, current: int) -> void:
	visible = current == Game.GameDomain.CLEAN_ROOM
	if visible: _activate()

func _refresh(view: Dictionary) -> void:
	%CreditsLabel.text = "%d ICs" % int(view.get("credits", 0))
	var installed: Array = view.get("installed_instance_ids", [])
	var utilities := PackedStringArray(); var active := PackedStringArray()
	for item: Dictionary in view.get("owned_programs", []):
		if not installed.has(StringName(item.instance_id)): continue
		if bool(item.get("consumes_active_slot", true)): active.append(String(item.display_name))
		else: utilities.append(String(item.display_name))
	%DeckUsageLabel.text = "MEMORY  %d / %d\nSTORAGE  %d / %d\nACTIVE SLOTS  %d / %d" % [view.memory_used, view.memory_capacity, view.storage_used, view.storage_capacity, view.active_slots_used, view.active_slot_capacity]
	%DeckSoftwareLabel.text = "INSTALLED UTILITIES\n%s\n\nRUNNING PROGRAMS\n%s" % [", ".join(utilities) if not utilities.is_empty() else "None", ", ".join(active) if not active.is_empty() else "None"]
	%MissionLabel.text = _mission_text(view)
	var readiness: Dictionary = view.get("launch_readiness", {"ready": true, "reason": "READY"})
	go_button.disabled = not bool(readiness.get("ready", true))
	readiness_label.text = "DECK STATUS: %s" % String(readiness.get("reason", "READY"))
	_refresh_loadout(view)

func _mission_text(view: Dictionary) -> String:
	var briefing: Dictionary = view.get("mission_briefing", {})
	var first_contact := bool(view.get("first_contact_first_run", false))
	if first_contact:
		return "FIRST CONTACT\n\nLatch has given you an address for an old office subnet.\n\nOBJECTIVE\nRetrieve the file Latch left inside.\n\nKNOWN SECURITY\nLimited intelligence. Expect resistance."
	if briefing.is_empty(): return "TARGET\nNo mission selected.\n\nOBJECTIVE\nEnter the available network."
	var primary: Array = briefing.get("primary_objectives", [])
	var objective := String(primary[0].description) if not primary.is_empty() else "Unspecified"
	var constraints := PackedStringArray(briefing.get("known_constraints", []))
	var difficulty := String(briefing.get("known_difficulty", "Unknown"))
	var security := String(briefing.get("known_security", "; ".join(constraints) if not constraints.is_empty() else "Unknown"))
	var context := String(briefing.get("description", briefing.get("flavor", "Review the target and enter when ready.")))
	return "%s\n\nOBJECTIVE\n%s\n\nDIFFICULTY\n%s\n\nKNOWN SECURITY\n%s\n\n%s" % [String(briefing.get("title", "TARGET")).to_upper(), objective, difficulty, security, context]

func _refresh_loadout(view: Dictionary) -> void:
	%MemoryBar.max_value = maxi(1, int(view.memory_capacity)); %MemoryBar.value = int(view.memory_used)
	%LoadoutUsageLabel.text = "MEMORY %d/%d  //  STORAGE %d/%d  //  ACTIVE SLOTS %d/%d" % [view.memory_used, view.memory_capacity, view.storage_used, view.storage_capacity, view.active_slots_used, view.active_slot_capacity]
	_stored_ids.clear(); _installed_ids.clear(); _running_ids.clear(); _stored_active_ids.clear()
	%StoredOption.clear(); %InstalledOption.clear(); %RunningOption.clear(); %StoredActiveOption.clear()
	var iu := PackedStringArray(); var su := PackedStringArray(); var rp := PackedStringArray(); var sp := PackedStringArray()
	var installed: Array = view.get("installed_instance_ids", [])
	for item: Dictionary in view.get("owned_programs", []):
		var id := StringName(item.instance_id); var loaded := installed.has(id); var active_program := bool(item.get("consumes_active_slot", true))
		var line := "%s  // RATING %d  // MEMORY %d" % [item.display_name, _rating_for(id), int(item.memory_cost)]
		if loaded:
			_installed_ids.append(id); %InstalledOption.add_item(line)
			if active_program: _running_ids.append(id); %RunningOption.add_item(line); rp.append(line)
			else: iu.append(line)
		else:
			_stored_ids.append(id); %StoredOption.add_item(line)
			if active_program: _stored_active_ids.append(id); %StoredActiveOption.add_item(line); sp.append(line)
			else: su.append(line)
	%InstalledUtilitiesLabel.text = "INSTALLED PASSIVE UTILITIES\n%s" % ("\n".join(iu) if not iu.is_empty() else "None")
	%StoredUtilitiesLabel.text = "\nSTORED UTILITIES\n%s" % ("\n".join(su) if not su.is_empty() else "None")
	%RunningProgramsLabel.text = "\nRUNNING ACTIVE PROGRAMS\n%s" % ("\n".join(rp) if not rp.is_empty() else "None")
	%StoredProgramsLabel.text = "\nSTORED ACTIVE PROGRAMS\n%s" % ("\n".join(sp) if not sp.is_empty() else "None")
	%InstallButton.disabled = _stored_ids.is_empty(); %RemoveButton.disabled = _installed_ids.is_empty(); %SwapButton.disabled = _running_ids.is_empty() or _stored_active_ids.is_empty()

func _rating_for(id: StringName) -> int:
	var instance := Game.program_inventory.get_instance(id) if Game.program_inventory != null else null
	return instance.definition.utility_rating if instance != null else 0

func open_loadout() -> void: loadout_panel.visible = true; (%CloseLoadoutButton as Button).grab_focus()
func close_loadout() -> void: loadout_panel.visible = false; (%LoadoutButton as Button).grab_focus()
func _install_selected() -> void:
	if %StoredOption.selected < 0 or %StoredOption.selected >= _stored_ids.size(): return
	_show_loadout_result(Game.clean_room_controller.install_program(_stored_ids[%StoredOption.selected]))
func _remove_selected() -> void:
	if %InstalledOption.selected < 0 or %InstalledOption.selected >= _installed_ids.size(): return
	_show_loadout_result(Game.clean_room_controller.remove_program(_installed_ids[%InstalledOption.selected]))
func _swap_selected() -> void:
	if %RunningOption.selected < 0 or %RunningOption.selected >= _running_ids.size() or %StoredActiveOption.selected < 0 or %StoredActiveOption.selected >= _stored_active_ids.size(): return
	_show_loadout_result(Game.meatspace_management.swap_active_program(_running_ids[%RunningOption.selected], _stored_active_ids[%StoredActiveOption.selected]))
func _show_loadout_result(result: Dictionary) -> void: %LoadoutStatus.text = String(result.get("reason", ""))

func _go() -> void:
	var result := Game.enter_netspace_from_clean_room()
	if not result.success: readiness_label.text = "CANNOT LAUNCH: %s" % String(result.reason)
func _home() -> void: Game.return_home_from_clean_room()

func _process(_delta: float) -> void:
	if not visible: return
	if Game.meatspace_management != null:
		var operation := Game.meatspace_management.deck_reconfiguration_view()
		if not operation.is_empty():
			_reconfiguration_was_active = true
			%LoadoutStatus.text = "%s  %d%%  %.1fs" % [String(operation.operation_name).replace("_", " "), roundi(float(operation.progress) * 100.0), float(operation.remaining)]
		elif _reconfiguration_was_active:
			_reconfiguration_was_active = false; _refresh(Game.clean_room_controller.view())
	var direction := GameplayBindings.focus_vector()
	if direction.length() < 0.3: _focus_gesture_armed = true
	elif _focus_gesture_armed: _focus_gesture_armed = false; _focus_control(direction)

func _focus_control(direction: Vector2) -> void:
	var controls: Array[Control] = [%CloseControlsButton] if controls_sheet.visible else ([%CloseLoadoutButton, %StoredOption, %InstallButton, %InstalledOption, %RemoveButton, %RunningOption, %SwapButton, %StoredActiveOption] if loadout_panel.visible else [go_button, %LoadoutButton, home_button, controls_button])
	var candidates: Array[Dictionary] = []
	for control in controls: candidates.append({"id": StringName(control.name), "position": control.get_global_rect().get_center(), "priority": 500.0 if control == go_button else 0.0, "enabled": control.visible and not bool(control.get("disabled"))})
	var owner := get_viewport().gui_get_focus_owner(); var current := StringName(owner.name) if owner != null and owner in controls else &""
	var next := DirectionalFocusSelector.choose(current, direction, candidates)
	for control in controls:
		if StringName(control.name) == next: control.grab_focus(); break

func _on_semantic_action(action_id: StringName) -> void:
	if not visible: return
	if action_id == &"primary_action":
		var owner := get_viewport().gui_get_focus_owner()
		if owner is Button and owner.visible and not owner.disabled: owner.pressed.emit()
	elif action_id == &"back_action":
		if controls_sheet.visible: close_controls()
		elif loadout_panel.visible: close_loadout()
	elif action_id == &"open_loadout": open_loadout()

func _focus_default_for_device() -> void: go_button.grab_focus()
func _on_device_mode_changed(_mode: int) -> void: _update_controls_for_device(); if visible and not controls_sheet.visible and not loadout_panel.visible: _focus_default_for_device()
func open_controls() -> void: controls_sheet.visible = true; _update_controls_for_device(); %CloseControlsButton.grab_focus()
func close_controls() -> void: controls_sheet.visible = false; controls_button.grab_focus()
func _update_controls_for_device() -> void:
	if primary_bindings == null: return
	var controller := "CONTROLLER\n\nCLEAN-ROOM\nD-pad / stick — select\nA / Cross — activate\nY / Triangle — loadout\nB / Circle — close\n\nNETSPACE\nRight Stick — target\nA / Cross — act\nB / Circle — back\n\nMEATSPACE\nA / Cross — interact\nB / Circle — close"
	var keyboard := "KEYBOARD + MOUSE\n\nCLEAN-ROOM\nMouse / arrows — select\nClick / Enter — activate\nEscape — close\n\nNETSPACE\nMouse — target\nClick — act\nEscape — back\n\nMEATSPACE\nClick — interact\nEscape — close"
	var pad := GameplayBindings.device_mode == GameplayBindings.DeviceMode.GAMEPAD
	primary_bindings.text = controller if pad else keyboard; alternate_bindings.text = keyboard if pad else controller
	primary_bindings.modulate.a = 1.0; alternate_bindings.modulate.a = 0.58
func _refresh_tutorial_hint() -> void:
	if Game.persistent_game_state == null: return
	var active := FirstMeatspaceTutorial.reconcile(Game.persistent_game_state) == FirstMeatspaceTutorial.Step.ENTER_CLEAN_ROOM
	tutorial_hint.visible = active
	if active: tutorial_hint.text = "GO — enter Netspace  •  REVIEW LOADOUT — optional preparation"
