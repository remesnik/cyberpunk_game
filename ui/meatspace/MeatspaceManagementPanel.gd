class_name MeatspaceManagementPanel
extends PanelContainer

@onready var backdoor_label: Label = %BackdoorLabel
@onready var hardware_label: Label = %HardwareLabel
@onready var inventory_option: OptionButton = %InventoryOption
@onready var loadout_option: OptionButton = %LoadoutOption
@onready var task_label: Label = %TaskLabel
@onready var event_label: Label = %EventLabel

var _inventory_ids: Array[StringName] = []
var _loadout_ids: Array[StringName] = []
var _task_serial := 0
var _job_ids: Array[StringName] = []


func _ready() -> void:
	visible = Game.game_domain == Game.GameDomain.MEATSPACE
	EventBus.game_domain_changed.connect(_on_domain_changed)
	EventBus.session_started.connect(_on_session_started)
	HudState.widget_open_requested.connect(_on_hud_widget_open_requested)
	%JackBackInButton.pressed.connect(_jack_back_in)
	%UpgradeButton.pressed.connect(_upgrade_deck)
	%InstallButton.pressed.connect(_install_selected)
	%RemoveButton.pressed.connect(_remove_selected)
	%OrderButton.pressed.connect(_order_equipment)
	%ProgramButton.pressed.connect(_start_programming)
	%CollectButton.pressed.connect(_collect_completed)
	%StoryButton.pressed.connect(_story_interaction)
	%AcceptJobButton.pressed.connect(_accept_selected_job)
	%JobOption.item_selected.connect(_show_selected_job)
	_refresh()


func _process(_delta: float) -> void:
	if visible and Game.meatspace_management != null:
		Game.meatspace_management.update_tasks()
		_refresh_status()


func _on_domain_changed(_previous: int, current: int) -> void:
	visible = current == Game.GameDomain.MEATSPACE and Game.prologue_controller == null
	if visible:
		_refresh()

func _on_session_started() -> void:
	visible = Game.game_domain == Game.GameDomain.MEATSPACE and Game.prologue_controller == null
	if visible: _refresh()

func _on_hud_widget_open_requested(widget_id: int) -> void:
	if widget_id != HudState.Widget.PROGRAM_QUICKBAR or not visible:
		return
	_refresh_program_options()
	if inventory_option.item_count > 0:
		inventory_option.grab_focus()
	elif loadout_option.item_count > 0:
		loadout_option.grab_focus()


func _refresh() -> void:
	if Game.is_content_available(&"FREE_ROAM_HOME") and Game.game_domain == Game.GameDomain.MEATSPACE:
		$Margin/Rows/Title.text = "FREE ROAM // HOME DECK MANAGEMENT"
		backdoor_label.text = "LOCAL DECK BAY\nNo campaign route selected.\n\nDYNAMIC JOB BOARD: ONLINE\nKnown networks: %d\nAvailable jobs: %d\n\nConfigure your deck, write software, order equipment, or connect when ready." % [Game.persistent_game_state.world_state.get("known_network_ids", []).size(), Game.persistent_game_state.world_state.get("available_dynamic_job_ids", []).size()]
		%JackBackInButton.text = "[CONNECT TO PUBLIC MESH]"
		%FreeRoamJobs.visible = true
		_refresh_free_roam_jobs()
	else:
		var view := Game.suspended_doorstop_view()
		$Margin/Rows/Title.text = "MEATSPACE // SUSPENDED INTRUSION MANAGEMENT"
		backdoor_label.text = "CONNECTION SUSPENDED\nBackdoor remains open.\n\nACTIVE BACKDOOR\nTarget: %s\nReturn Node: %s\nIntrusion: %s\n\nOne re-entry. Returning destroys this temporary route." % [view.get("target_name", "UNKNOWN"), view.get("return_node_id", &"UNKNOWN"), view.get("intrusion_run_id", &"UNKNOWN")]
		%JackBackInButton.text = "[JACK BACK IN]"
		%FreeRoamJobs.visible = false
	_refresh_program_options()
	_refresh_status()


func _refresh_program_options() -> void:
	_inventory_ids.clear()
	_loadout_ids.clear()
	inventory_option.clear()
	loadout_option.clear()
	if Game.program_inventory == null or Game.program_loadout == null:
		return
	for instance: ProgramInstance in Game.program_inventory.all_instances():
		if not Game.program_loadout.is_installed(instance.instance_id):
			_inventory_ids.append(instance.instance_id)
			inventory_option.add_item("%s // %s" % [instance.definition.display_name, instance.instance_id])
	for instance_id: StringName in Game.program_loadout.installed_instance_ids:
		var instance := Game.program_inventory.get_instance(instance_id)
		if instance != null:
			_loadout_ids.append(instance_id)
			loadout_option.add_item("%s // %s" % [instance.definition.display_name, instance_id])


func _refresh_status() -> void:
	var manager: MeatspaceManagement = Game.meatspace_management
	if manager == null:
		return
	hardware_label.text = "DECK CPU %d  //  RAM %d  //  STORAGE %d\nFICTIONAL CREDITS %d" % [manager.hardware_levels.DECK_CPU, manager.hardware_levels.DECK_RAM, manager.hardware_levels.DECK_STORAGE, Game.equipment_order_manager.credits]
	var tasks: PackedStringArray = []
	for task: SoftwareProgrammingTask in manager.programming_tasks.values():
		tasks.append("%s // %s // %.1f/%.1fs" % [task.id, SoftwareProgrammingTask.State.keys()[task.state], task.elapsed(Game.realtime_world_clock.elapsed_seconds), task.duration])
	task_label.text = "SOFTWARE PROGRAMMING\n%s" % ("\n".join(tasks) if not tasks.is_empty() else "NO ACTIVE TASKS")

func _refresh_free_roam_jobs() -> void:
	_job_ids.clear()
	%JobOption.clear()
	var board: FreeRoamJobBoard = Game.free_roam_job_board
	if board == null:
		%JobDescription.text = "PUBLIC JOB EXCHANGE OFFLINE"
		return
	for job in board.available_jobs():
		_job_ids.append(job.id)
		%JobOption.add_item("%s // %d CR" % [job.display_name.to_upper(), job.reward_credits])
	var targets: Array = Game.persistent_game_state.world_state.get("discoverable_network_targets", [])
	var target_names := PackedStringArray()
	for target: Dictionary in targets: target_names.append(String(target.get("display_name", "UNKNOWN")))
	%TargetLabel.text = "NETWORK DIRECTORY // %s" % " | ".join(target_names)
	_show_selected_job(0)

func _show_selected_job(index: int) -> void:
	if index < 0 or index >= _job_ids.size() or Game.free_roam_job_board == null:
		%JobDescription.text = "NO OPEN CONTRACTS"
		return
	var job := Game.free_roam_job_board.catalog.get_job(_job_ids[index])
	%JobDescription.text = "%s\nTARGET: %s // %s" % [job.description, job.target_network_id, job.target_node_id]

func _accept_selected_job() -> void:
	var index: int = %JobOption.selected
	if index < 0 or index >= _job_ids.size() or Game.free_roam_job_board == null: return
	var result: Dictionary = Game.free_roam_job_board.accept_job(_job_ids[index])
	event_label.text = result.reason


func _jack_back_in() -> void:
	var result := Game.enter_free_roam_network() if Game.is_content_available(&"FREE_ROAM_HOME") else Game.jack_back_in_through_doorstop()
	event_label.text = result.reason
	if not result.success:
		Game.notify_doorstop_invalid(result.reason)


func _upgrade_deck() -> void:
	var result := Game.meatspace_management.upgrade_hardware(&"DECK_RAM", 100)
	event_label.text = result.reason


func _install_selected() -> void:
	if inventory_option.selected < 0 or inventory_option.selected >= _inventory_ids.size():
		return
	var result := Game.meatspace_management.install_program(_inventory_ids[inventory_option.selected])
	event_label.text = result.reason
	_refresh_program_options()


func _remove_selected() -> void:
	if loadout_option.selected < 0 or loadout_option.selected >= _loadout_ids.size():
		return
	var result := Game.meatspace_management.remove_program(_loadout_ids[loadout_option.selected])
	event_label.text = result.reason
	_refresh_program_options()


func _order_equipment() -> void:
	var manager: EquipmentOrderManager = Game.equipment_order_manager
	var vendor_ids: Array = manager.vendors.keys()
	if vendor_ids.is_empty():
		event_label.text = "NO VENDOR AVAILABLE"
		return
	var vendor: VendorDefinition = manager.vendors[vendor_ids[0]]
	if vendor.inventory.is_empty() or vendor.delivery_destinations.is_empty():
		event_label.text = "VENDOR CANNOT FULFILL ORDER"
		return
	var result := Game.meatspace_management.order_equipment(vendor.inventory[0], vendor.id, 1, vendor.delivery_destinations[0])
	event_label.text = result.reason


func _start_programming() -> void:
	_task_serial += 1
	var task_id := StringName("DOORSTOP_TASK_%03d" % _task_serial)
	var result := Game.meatspace_management.start_programming(task_id, Game.doorstop_programming_definition)
	event_label.text = result.reason


func _collect_completed() -> void:
	for task_id in Game.meatspace_management.programming_tasks:
		var task: SoftwareProgrammingTask = Game.meatspace_management.programming_tasks[task_id]
		if task.state == SoftwareProgrammingTask.State.COMPLETED:
			var result := Game.meatspace_management.collect_programming(task_id)
			event_label.text = result.reason
			_refresh_program_options()
			return
	event_label.text = "NO COMPLETED SOFTWARE TASK"


func _story_interaction() -> void:
	var result := Game.meatspace_management.perform_story_interaction(&"CHECK_SAFEHOUSE_MESSAGES", &"ACKNOWLEDGE")
	event_label.text = result.reason
