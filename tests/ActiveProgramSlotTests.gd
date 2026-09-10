extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var inventory := ProgramInventory.new()
	var loadout := ProgramLoadout.new(4)
	var icebreaker := ProgramInstance.new(&"ICEBREAKER_INSTANCE", ProgramDefinition.new(&"ICEBREAKER", "Icebreaker"))
	var sniffer := ProgramInstance.new(&"SNIFFER_INSTANCE", ProgramDefinition.new(&"SNIFFER", "Sniffer"))
	var spare := ProgramInstance.new(&"SPARE_INSTANCE", ProgramDefinition.new(&"SPARE", "Spare"))
	inventory.add_instance(icebreaker)
	inventory.add_instance(sniffer)
	inventory.add_instance(spare)
	_expect(loadout.capacity == 4 and loadout.active_slots.size() == 4, "active slot bar model supports variable capacity")
	_expect(loadout.install_at(0, icebreaker.instance_id, inventory) and loadout.install_at(2, sniffer.instance_id, inventory), "occupied programs can load into explicit slots")
	_expect(loadout.instance_at(1).is_empty() and loadout.instance_at(3).is_empty(), "empty active slots remain explicit")
	var selected := 0
	for step in 4: selected = posmod(selected + 1, loadout.capacity)
	_expect(selected == 0, "next-slot traversal cycles all slots including empty positions")
	for step in 4: selected = posmod(selected - 1, loadout.capacity)
	_expect(selected == 0, "previous-slot traversal cycles all slots including empty positions")
	var moved_id := loadout.uninstall_at(0)
	_expect(moved_id == icebreaker.instance_id and loadout.instance_at(0).is_empty() and inventory.has_instance(moved_id), "moving a program to storage preserves the instance")
	inventory.storage_capacity = inventory.stored_count(loadout)
	_expect(not inventory.can_store(loadout), "full storage rejects another move without deletion")
	var dump_id := loadout.uninstall_at(2)
	inventory.remove_instance(dump_id)
	_expect(not inventory.has_instance(dump_id) and loadout.instance_at(2).is_empty(), "confirmed dump removes the program and frees its slot")
	print("%s: %d active program slot assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
