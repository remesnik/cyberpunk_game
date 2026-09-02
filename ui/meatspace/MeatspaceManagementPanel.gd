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


func _ready() -> void:
	visible = Game.game_domain == Game.GameDomain.MEATSPACE
	EventBus.game_domain_changed.connect(_on_domain_changed)
	%JackBackInButton.pressed.connect(_jack_back_in)
	%UpgradeButton.pressed.connect(_upgrade_deck)
	%InstallButton.pressed.connect(_install_selected)
	%RemoveButton.pressed.connect(_remove_selected)
	%OrderButton.pressed.connect(_order_equipment)
	%ProgramButton.pressed.connect(_start_programming)
	%CollectButton.pressed.connect(_collect_completed)
	%StoryButton.pressed.connect(_story_interaction)
	_refresh()


func _process(_delta: float) -> void:
	if visible and Game.meatspace_management != null:
		Game.meatspace_management.update_tasks()
		_refresh_status()


func _on_domain_changed(_previous: int, current: int) -> void:
	visible = current == Game.GameDomain.MEATSPACE
	if visible:
		_refresh()


func _refresh() -> void:
	var view := Game.suspended_doorstop_view()
	backdoor_label.text = "CONNECTION SUSPENDED\nBackdoor remains open.\n\nACTIVE BACKDOOR\nTarget: %s\nReturn Node: %s\nIntrusion: %s\n\nOne re-entry. Returning destroys this temporary route." % [view.get("target_name", "UNKNOWN"), view.get("return_node_id", &"UNKNOWN"), view.get("intrusion_run_id", &"UNKNOWN")]
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


func _jack_back_in() -> void:
	var result := Game.jack_back_in_through_doorstop()
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
