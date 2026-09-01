class_name EquipmentOrderManager
extends Node

signal orders_changed
signal order_status_changed(order_id: StringName, previous_status: EquipmentOrder.Status, current_status: EquipmentOrder.Status)
signal delivery_event(event: Dictionary)

var equipment_catalog: Dictionary = {}
var vendors: Dictionary = {}
var orders: Dictionary = {}
var story_hooks: Dictionary = {}
var available_equipment: Dictionary = {}
var messages: Array[Dictionary] = []
var credits := 1000
var _process_manager: RealtimeProcessManager
var _clock: RealtimeWorldClock
var _serial := 0


func configure(process_manager: RealtimeProcessManager, clock: RealtimeWorldClock) -> void:
	_process_manager = process_manager
	_clock = clock
	if not _process_manager.processes_updated.is_connected(_on_realtime_updated):
		_process_manager.processes_updated.connect(_on_realtime_updated)


func add_equipment(equipment: EquipmentDefinition) -> bool:
	if equipment == null or equipment.id == &"" or equipment_catalog.has(equipment.id):
		return false
	equipment_catalog[equipment.id] = equipment
	return true


func add_vendor(vendor: VendorDefinition) -> bool:
	if vendor == null or vendor.id == &"" or vendors.has(vendor.id):
		return false
	vendors[vendor.id] = vendor
	return true


func add_story_hook(hook: StoryHook) -> bool:
	if hook == null or hook.id == &"" or story_hooks.has(hook.id):
		return false
	story_hooks[hook.id] = hook
	return true


func create_cart(equipment_id: StringName, vendor_id: StringName, quantity: int, destination: StringName) -> EquipmentOrder:
	var equipment := equipment_catalog.get(equipment_id) as EquipmentDefinition
	var vendor := vendors.get(vendor_id) as VendorDefinition
	if equipment == null or vendor == null or not vendor.sells(equipment_id) or quantity <= 0 or not vendor.delivery_destinations.has(destination):
		return null
	_serial += 1
	var order := EquipmentOrder.new(StringName("ORDER_%04d" % _serial), equipment_id, vendor_id, quantity)
	order.cost = vendor.price_for(equipment, quantity)
	order.delivery_duration = vendor.delivery_duration
	order.delivery_destination = destination
	order.story_tags.assign(equipment.story_tags)
	order.story_tags.append_array(vendor.story_tags)
	orders[order.id] = order
	order.status_changed.connect(_on_order_status_changed)
	orders_changed.emit()
	return order


func place_order(order_id: StringName) -> Dictionary:
	var order := orders.get(order_id) as EquipmentOrder
	if order == null or order.status != EquipmentOrder.Status.CART:
		return {"success": false, "reason": "Order is not available in cart."}
	if credits < order.cost:
		return {"success": false, "reason": "Insufficient fictional credits."}
	credits -= order.cost
	order.ordered_at = _clock.elapsed_seconds
	order.realtime_process_id = StringName("DELIVERY_%s" % order.id)
	var process := RealtimeProcess.new(order.realtime_process_id, RealtimeProcess.ProcessType.DELIVERY, "Delivery %s" % order.id, order.vendor_id, order.delivery_duration)
	_process_manager.add_process(process, true)
	order._set_status(EquipmentOrder.Status.ORDERED, "ORDER CONFIRMED")
	return {"success": true, "reason": "Fictional order placed.", "order_id": order.id, "cost": order.cost, "ordered_at": order.ordered_at}


func cancel_order(order_id: StringName) -> bool:
	var order := orders.get(order_id) as EquipmentOrder
	if order == null or not order.cancel():
		return false
	var process := _process_manager.get_process(order.realtime_process_id)
	if process != null:
		_process_manager.set_process_state(process.id, RealtimeProcess.State.INTERRUPTED)
	return true


func intercept_order(order_id: StringName, reason := "DELIVERY INTERCEPTED") -> bool:
	var order := orders.get(order_id) as EquipmentOrder
	if order == null or not order.intercept(reason):
		return false
	var process := _process_manager.get_process(order.realtime_process_id)
	if process != null:
		_process_manager.set_process_state(process.id, RealtimeProcess.State.INTERRUPTED)
	return true


func _on_realtime_updated(_session_time: float) -> void:
	for value: Variant in orders.values():
		var order := value as EquipmentOrder
		if order.realtime_process_id == &"":
			continue
		var process := _process_manager.get_process(order.realtime_process_id)
		if process != null:
			order.advance_to(process.elapsed_time)
	orders_changed.emit()


func _on_order_status_changed(order_id: StringName, previous: EquipmentOrder.Status, current: EquipmentOrder.Status) -> void:
	order_status_changed.emit(order_id, previous, current)
	if current == EquipmentOrder.Status.DELIVERED:
		_resolve_delivery(orders[order_id])
	orders_changed.emit()


func _resolve_delivery(order: EquipmentOrder) -> void:
	available_equipment[order.equipment_id] = int(available_equipment.get(order.equipment_id, 0)) + order.quantity
	var equipment := equipment_catalog[order.equipment_id] as EquipmentDefinition
	var event := {"type": &"EQUIPMENT_DELIVERED", "order_id": order.id, "equipment_id": order.equipment_id, "quantity": order.quantity, "destination": order.delivery_destination, "story_tags": order.story_tags.duplicate()}
	messages.append({"time": _clock.elapsed_seconds, "text": "%s delivered to %s." % [equipment.display_name, order.delivery_destination], "order_id": order.id})
	if equipment.delivery_story_hook_id != &"" and story_hooks.has(equipment.delivery_story_hook_id):
		var hook := story_hooks[equipment.delivery_story_hook_id] as StoryHook
		event["story_hook_id"] = hook.id
		for effect: Dictionary in hook.effects:
			event["hook_effects"] = hook.effects.duplicate(true)
	delivery_event.emit(event)
