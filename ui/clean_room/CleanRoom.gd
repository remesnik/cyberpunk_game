class_name CleanRoom
extends Control

@onready var go_button: Button = %GoButton
@onready var home_button: Button = %HomeButton
@onready var credits_label: Label = %CreditsLabel
@onready var connection_label: Label = %ConnectionLabel
@onready var buy_link_button: Button = %BuyLinkButton
@onready var available_programs: OptionButton = %AvailablePrograms
@onready var loaded_programs: OptionButton = %LoadedPrograms
@onready var slots_label: Label = %SlotsLabel
@onready var message_label: Label = %MessageLabel
var available_ids: Array[StringName] = []
var loaded_ids: Array[StringName] = []

func _ready() -> void:
	go_button.pressed.connect(_go)
	home_button.pressed.connect(_home)
	buy_link_button.pressed.connect(_buy_link)
	%LoadButton.pressed.connect(_load_program)
	%UnloadButton.pressed.connect(_unload_program)
	%ContactButton.pressed.connect(_contact_latch)
	EventBus.game_domain_changed.connect(_on_domain_changed)
	EventBus.session_started.connect(_on_session_started)
	visible = Game.game_domain == Game.GameDomain.CLEAN_ROOM
	if visible: _bind_controller()

func _on_session_started() -> void:
	visible = Game.game_domain == Game.GameDomain.CLEAN_ROOM
	if visible: _bind_controller()

func _on_domain_changed(_previous: int, current: int) -> void:
	visible = current == Game.GameDomain.CLEAN_ROOM
	if visible: _bind_controller()

func _bind_controller() -> void:
	var controller: CleanRoomController = Game.clean_room_controller
	if controller == null: return
	if not controller.state_changed.is_connected(_refresh): controller.state_changed.connect(_refresh)
	if not controller.ally_contacted.is_connected(_show_contact): controller.ally_contacted.connect(_show_contact)
	_refresh(controller.view())
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
	available_ids.clear(); loaded_ids.clear(); available_programs.clear(); loaded_programs.clear()
	var installed: Array = view.get("installed_instance_ids", [])
	for item: Dictionary in view.get("owned_programs", []):
		var id := StringName(item.instance_id)
		if installed.has(id):
			loaded_ids.append(id); loaded_programs.add_item(String(item.display_name))
		else:
			available_ids.append(id); available_programs.add_item(String(item.display_name))
	slots_label.text = "ACTIVE SLOTS  %d / %d" % [loaded_ids.size(), int(view.get("active_slot_capacity", 0))]
	%LoadButton.disabled = available_ids.is_empty() or loaded_ids.size() >= int(view.get("active_slot_capacity", 0))
	%UnloadButton.disabled = loaded_ids.is_empty()

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
	_show_contact(Game.clean_room_controller.contact_ally(&"LATCH"))
func _show_contact(event: Dictionary) -> void:
	message_label.text = "LATCH // %s" % String(event.get("text", "Channel open."))
