class_name EquipmentOrder
extends RefCounted

enum Status { CART, ORDERED, PROCESSING, SHIPPED, DELIVERED, INTERCEPTED, CANCELLED }

signal status_changed(order_id: StringName, previous_status: Status, current_status: Status)

var id: StringName
var equipment_id: StringName
var vendor_id: StringName
var quantity := 1
var cost := 0
var status: Status = Status.CART
var ordered_at := 0.0
var delivery_duration := 30.0
var delivery_destination: StringName
var tracking_state: String = "IN CART"
var story_tags: Array[StringName] = []
var realtime_process_id: StringName
var elapsed_time := 0.0


func _init(order_id: StringName = &"", item_id: StringName = &"", source_vendor_id: StringName = &"", item_quantity := 1) -> void:
	id = order_id
	equipment_id = item_id
	vendor_id = source_vendor_id
	quantity = maxi(1, item_quantity)


func advance_to(process_elapsed: float) -> void:
	if status in [Status.CART, Status.DELIVERED, Status.INTERCEPTED, Status.CANCELLED]:
		return
	elapsed_time = maxf(elapsed_time, process_elapsed)
	var progress := clampf(elapsed_time / delivery_duration, 0.0, 1.0)
	if progress >= 1.0:
		_set_status(Status.DELIVERED, "DELIVERED TO %s" % delivery_destination)
	elif progress >= 0.5:
		_set_status(Status.SHIPPED, "IN TRANSIT // %03d%%" % int(progress * 100.0))
	elif progress >= 0.15:
		_set_status(Status.PROCESSING, "VENDOR PROCESSING // %03d%%" % int(progress * 100.0))
	else:
		_set_status(Status.ORDERED, "ORDER CONFIRMED")


func cancel() -> bool:
	if status not in [Status.CART, Status.ORDERED, Status.PROCESSING]:
		return false
	_set_status(Status.CANCELLED, "ORDER CANCELLED")
	return true


func intercept(reason := "DELIVERY INTERCEPTED") -> bool:
	if status not in [Status.ORDERED, Status.PROCESSING, Status.SHIPPED]:
		return false
	_set_status(Status.INTERCEPTED, reason)
	return true


func status_label() -> String:
	return Status.keys()[status]


func _set_status(next_status: Status, tracking: String) -> void:
	tracking_state = tracking
	if status == next_status:
		return
	var previous := status
	status = next_status
	status_changed.emit(id, previous, status)

