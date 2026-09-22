class_name NodeModeDebugSnapshot
extends RefCounted

static func capture(inventory: ProgramInventory, loadout: ProgramLoadout, node: NetworkNodeDefinition, bypass_result: Dictionary, graph: NetworkGraph) -> Dictionary:
	var stored: Array[StringName] = []
	var installed: Array[StringName] = []
	var running: Array[StringName] = []
	var affinities: Array[Dictionary] = []
	if inventory != null:
		for instance: ProgramInstance in inventory.all_instances():
			var is_installed := loadout != null and loadout.is_installed(instance.instance_id)
			if not is_installed: stored.append(instance.instance_id)
			if is_installed and instance.definition.is_passive_utility(): installed.append(instance.instance_id)
			if is_installed and not instance.definition.is_passive_utility(): running.append(instance.instance_id)
			if not instance.definition.exploit_security_family.is_empty():
				affinities.append({"instance": instance.instance_id, "family": instance.definition.exploit_security_family, "compatible": instance.definition.exploit_family_matches(node), "affinity": instance.definition.network_affinity_label(node), "rating": instance.definition.utility_rating, "effective": instance.definition.effective_exploit_rating(node)})
	stored.sort(); installed.sort(); running.sort()
	var sleeves: Array[Dictionary] = []
	if graph != null:
		for sleeve: SecuritySleeve in graph.security_sleeves.values():
			sleeves.append({"id": sleeve.id, "security_count": sleeve.security_count, "level": StringName(SecuritySleeve.EscalationLevel.keys()[sleeve.escalation_level]), "trace": sleeve.metadata.get("system_trace_active", false), "tags": sleeve.metadata.get("punitive_tags", []), "shutdown": sleeve.metadata.get("system_shutdown", false)})
	return {
		"storage_used": inventory.storage_used() if inventory != null else 0,
		"storage_total": inventory.storage_capacity if inventory != null else 0,
		"memory_used": loadout.memory_used(inventory) if loadout != null else 0,
		"memory_total": loadout.memory_capacity if loadout != null else 0,
		"active_used": loadout.active_slots_used() if loadout != null else 0,
		"active_total": loadout.capacity if loadout != null else 0,
		"stored_software": stored, "installed_utilities": installed, "running_programs": running,
		"node": {"id": node.id if node != null else &"", "network_type": node.network_type if node != null else &"", "security_family": node.security_family_name() if node != null else &"", "difficulty": node.difficulty_rating if node != null else 0},
		"affinity": affinities, "bypass": bypass_result.duplicate(true),
		"security_event": bypass_result.get("generated_security_event", {}).duplicate(true), "sleeves": sleeves,
	}

static func format(snapshot: Dictionary) -> String:
	var node: Dictionary = snapshot.get("node", {})
	var lines: PackedStringArray = ["NODE MODE AUDIT", "DECK  STORAGE %d/%d  MEMORY %d/%d  ACTIVE %d/%d" % [snapshot.storage_used, snapshot.storage_total, snapshot.memory_used, snapshot.memory_total, snapshot.active_used, snapshot.active_total], "STORED: %s" % str(snapshot.stored_software), "UTILITIES: %s" % str(snapshot.installed_utilities), "RUNNING: %s" % str(snapshot.running_programs), "NODE %s  TYPE %s  FAMILY %s  DIFFICULTY %d" % [node.get("id", &"--"), node.get("network_type", &"--"), node.get("security_family", &"--"), node.get("difficulty", 0)]]
	for item: Dictionary in snapshot.affinity:
		lines.append("AFFINITY %s  %s/%s  RATING %d -> %d  MATCH %s" % [item.instance, item.family, item.affinity, item.rating, item.effective, item.compatible])
	var bypass: Dictionary = snapshot.bypass
	if not bypass.is_empty(): lines.append("BYPASS %s  ATTACK %s  DEFENSE %s  NOISY %s  USED %s" % ["SUCCESS" if bypass.get("success", false) else "FAIL", bypass.get("attack_value", "--"), bypass.get("defense_value", "--"), bypass.get("noisy", false), bypass.get("utility_or_program_used", &"--")])
	if not snapshot.security_event.is_empty(): lines.append("SECURITY EVENT: %s" % str(snapshot.security_event))
	for sleeve: Dictionary in snapshot.sleeves: lines.append("SLEEVE %s  COUNT %d  %s  TRACE %s  TAGS %s  SHUTDOWN %s" % [sleeve.id, sleeve.security_count, sleeve.level, sleeve.trace, sleeve.tags, sleeve.shutdown])
	return "\n".join(lines)
