extends SceneTree

const ProcessManagerScript := preload("res://core/RealtimeProcessManager.gd")
const ClockScript := preload("res://core/RealtimeWorldClock.gd")
const EquipmentScript := preload("res://core/equipment/EquipmentDefinition.gd")
const VendorScript := preload("res://core/equipment/VendorDefinition.gd")
const OrderManagerScript := preload("res://core/equipment/EquipmentOrderManager.gd")
const CyberClockScript := preload("res://core/CyberspaceClock.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_realtime_delivery_and_story_resolution()
	print("%s: %d equipment order assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_realtime_delivery_and_story_resolution() -> void:
	var process_manager = ProcessManagerScript.new()
	var clock = ClockScript.new()
	var manager = OrderManagerScript.new()
	manager.configure(process_manager, clock)
	manager.credits = 500
	var equipment = EquipmentScript.new(&"CAMERA_TAP", "Camera Tap", EquipmentScript.EquipmentType.CAMERA_TAP, 100)
	equipment.delivery_story_hook_id = &"TAP_DELIVERED"
	equipment.story_tags.assign([&"CAMERA_SUPPORT"])
	manager.add_equipment(equipment)
	var vendor = VendorScript.new(&"TEST_VENDOR", "Test Vendor", 30.0)
	vendor.inventory.append(equipment.id)
	vendor.delivery_destinations.append(&"SAFEHOUSE")
	manager.add_vendor(vendor)
	var hook := StoryHook.new(&"TAP_DELIVERED", &"EQUIPMENT_DELIVERED")
	hook.effects.append({"type": &"UNLOCK_INTERACTION", "interaction_id": &"INSTALL_TAP"})
	manager.add_story_hook(hook)
	var delivered_events: Array[Dictionary] = []
	manager.delivery_event.connect(func(event: Dictionary) -> void: delivered_events.append(event))

	var order := manager.create_cart(equipment.id, vendor.id, 2, &"SAFEHOUSE")
	_expect(order != null and order.status == EquipmentOrder.Status.CART and order.cost == 200, "authored item and vendor create fictional cart")
	var placed: Dictionary = manager.place_order(order.id)
	_expect(placed.success and manager.credits == 300 and order.status == EquipmentOrder.Status.ORDERED, "placing order spends fictional credits and starts delivery")
	process_manager.advance_to_realtime(5.0)
	_expect(order.status == EquipmentOrder.Status.PROCESSING, "order enters processing from realtime progress")
	process_manager.advance_to_realtime(15.0)
	_expect(order.status == EquipmentOrder.Status.SHIPPED, "order ships at authored realtime threshold")

	var cyber = CyberClockScript.new()
	cyber.resolve_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 100), _valid, _applied)
	_expect(cyber.current_tick == 100 and order.elapsed_time == 15.0 and order.status == EquipmentOrder.Status.SHIPPED, "100 cyber ticks do not progress delivery")
	process_manager.advance_to_realtime(30.0)
	_expect(order.status == EquipmentOrder.Status.DELIVERED and manager.available_equipment[equipment.id] == 2, "realtime completion makes equipment available")
	_expect(manager.messages.size() == 1 and delivered_events.size() == 1, "delivery triggers message and internal event")
	_expect(delivered_events[0].story_hook_id == hook.id and delivered_events[0].hook_effects[0].interaction_id == &"INSTALL_TAP", "delivery resolves authored StoryHook effects")

	clock.restore(30.0, false)
	var cancelled := manager.create_cart(equipment.id, vendor.id, 1, &"SAFEHOUSE")
	manager.place_order(cancelled.id)
	_expect(manager.cancel_order(cancelled.id) and cancelled.status == EquipmentOrder.Status.CANCELLED, "processing order can be cancelled")
	var intercepted := manager.create_cart(equipment.id, vendor.id, 1, &"SAFEHOUSE")
	manager.place_order(intercepted.id)
	process_manager.advance_to_realtime(45.0)
	_expect(manager.intercept_order(intercepted.id) and intercepted.status == EquipmentOrder.Status.INTERCEPTED, "authored systems can intercept an in-transit order")
	manager.free()
	process_manager.free()
	clock.free()


func _valid(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _applied(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
