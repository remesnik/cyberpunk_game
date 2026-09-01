class_name EquipmentOrderPanel
extends PanelContainer

@onready var credits_label: Label = %CreditsLabel
@onready var vendor_option: OptionButton = %VendorOption
@onready var equipment_option: OptionButton = %EquipmentOption
@onready var destination_option: OptionButton = %DestinationOption
@onready var quantity_spin: SpinBox = %QuantitySpin
@onready var order_button: Button = %OrderButton
@onready var tracking_label: Label = %TrackingLabel

var _vendor_ids: Array[StringName] = []
var _equipment_ids: Array[StringName] = []
var _destination_ids: Array[StringName] = []


func _ready() -> void:
	vendor_option.item_selected.connect(_on_vendor_selected)
	order_button.pressed.connect(_place_order)
	_build_catalog()


func _process(_delta: float) -> void:
	_refresh_tracking()


func _build_catalog() -> void:
	if Game.equipment_order_manager == null:
		visible = false
		return
	visible = true
	_vendor_ids.assign(Game.equipment_order_manager.vendors.keys())
	_vendor_ids.sort()
	vendor_option.clear()
	for vendor_id: StringName in _vendor_ids:
		vendor_option.add_item(Game.equipment_order_manager.vendors[vendor_id].display_name.to_upper())
	_on_vendor_selected(0)


func _on_vendor_selected(index: int) -> void:
	_equipment_ids.clear()
	_destination_ids.clear()
	equipment_option.clear()
	destination_option.clear()
	if index < 0 or index >= _vendor_ids.size():
		return
	var vendor: VendorDefinition = Game.equipment_order_manager.vendors[_vendor_ids[index]]
	_equipment_ids.assign(vendor.inventory)
	_equipment_ids.sort()
	for equipment_id: StringName in _equipment_ids:
		var equipment: EquipmentDefinition = Game.equipment_order_manager.equipment_catalog[equipment_id]
		equipment_option.add_item("%s // %d CR" % [equipment.display_name.to_upper(), vendor.price_for(equipment, 1)])
	_destination_ids.assign(vendor.delivery_destinations)
	for destination: StringName in _destination_ids:
		destination_option.add_item(String(destination).replace("_", " "))


func _place_order() -> void:
	if vendor_option.selected < 0 or equipment_option.selected < 0 or destination_option.selected < 0:
		return
	var order: EquipmentOrder = Game.equipment_order_manager.create_cart(
		_equipment_ids[equipment_option.selected], _vendor_ids[vendor_option.selected],
		int(quantity_spin.value), _destination_ids[destination_option.selected]
	)
	if order != null:
		Game.equipment_order_manager.place_order(order.id)


func _refresh_tracking() -> void:
	if Game.equipment_order_manager == null:
		return
	credits_label.text = "FICTIONAL CREDITS // %04d" % Game.equipment_order_manager.credits
	var lines: PackedStringArray = []
	var order_ids: Array = Game.equipment_order_manager.orders.keys()
	order_ids.sort()
	for order_id: StringName in order_ids.slice(maxi(0, order_ids.size() - 5)):
		var order: EquipmentOrder = Game.equipment_order_manager.orders[order_id]
		lines.append("%s  %s\n  %s  %05.1f/%05.1fs" % [order.id, order.status_label(), order.tracking_state, order.elapsed_time, order.delivery_duration])
	tracking_label.text = "ACTIVE ORDERS\n%s" % ("\n".join(lines) if not lines.is_empty() else "--")
