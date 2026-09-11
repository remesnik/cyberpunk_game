class_name NetworkResidueState
extends RefCounted
## Save-friendly authoritative consequences with opt-in recovery deadlines.
signal residue_changed(kind: StringName, id: StringName, state: StringName)

var records: Dictionary = {}

func configure(saved: Dictionary = {}) -> void:
	records = saved.duplicate(true)

func mark(kind: StringName, id: StringName, state: StringName, changed_at: float, recovery: Dictionary = {}) -> void:
	if kind == &"" or id == &"": return
	var record := {"kind": kind, "id": id, "state": state, "changed_at": changed_at}
	if not recovery.is_empty():
		record["recover_at"] = changed_at + maxf(0.0, float(recovery.get("delay", 0.0)))
		record["recovery_state"] = StringName(recovery.get("state", &"ACTIVE"))
	records[_key(kind, id)] = record
	residue_changed.emit(kind, id, state)

func get_record(kind: StringName, id: StringName) -> Dictionary:
	return (records.get(_key(kind, id), {}) as Dictionary).duplicate(true)

func has_state(kind: StringName, id: StringName, state: StringName) -> bool:
	return StringName(records.get(_key(kind, id), {}).get("state", &"")) == state

func advance(now: float) -> Array[Dictionary]:
	var recovered: Array[Dictionary] = []
	for key: Variant in records.keys():
		var record: Dictionary = records[key]
		if not record.has("recover_at") or now < float(record.recover_at): continue
		record["state"] = StringName(record.get("recovery_state", &"ACTIVE"))
		record["recovered_at"] = now
		record.erase("recover_at")
		record.erase("recovery_state")
		records[key] = record
		recovered.append(record.duplicate(true))
		residue_changed.emit(StringName(record.kind), StringName(record.id), StringName(record.state))
	return recovered

func observe_events(events: Array[Dictionary], now: float) -> void:
	for event: Dictionary in events:
		match StringName(event.get("type", &"")):
			&"SERVICE_COMPROMISED": mark(&"SERVICE", StringName(event.get("service_id", &"")), &"COMPROMISED", now)
			&"SERVICE_DISABLED": mark(&"SERVICE", StringName(event.get("service_id", &"")), &"DISABLED", now, event.get("recovery", {}))
			&"FILE_DELETED": mark(&"FILE", StringName(event.get("file_id", &"")), &"DELETED", now, event.get("recovery", {}))
			&"DATA_EXTRACTED", &"FILE_DOWNLOADED": mark(&"FILE", StringName(event.get("file_id", event.get("resource_id", &""))), &"DOWNLOADED", now)
			&"DEVICE_CONTROLLED": mark(&"DEVICE", StringName(event.get("device_id", &"")), StringName(event.get("state", &"CONTROLLED")), now, event.get("recovery", {}))
			&"ALARM_TRIGGERED": mark(&"ALARM", StringName(event.get("alarm_id", &"")), &"TRIGGERED", now, event.get("recovery", {}))
			&"ICE_DESTROYED": mark(&"ICE", StringName(event.get("ice_id", &"")), &"DESTROYED", now, event.get("recovery", {}))

func capture_runtime(graph: NetworkGraph, controller: IceController, alarm_manager: Variant = null) -> void:
	if graph != null:
		for link: NetworkLinkDefinition in graph.links.values():
			if link.disabled or link.locked or link.discovered:
				records[_key(&"LINK", link.id)] = {"kind": &"LINK", "id": link.id, "state": &"CHANGED", "disabled": link.disabled, "locked": link.locked, "hidden": link.hidden, "discovered": link.discovered}
		for node: NetworkNodeDefinition in graph.nodes.values():
			for service: Dictionary in node.services:
				var service_id := StringName(service.id)
				if service.get("disabled", false) and get_record(&"SERVICE", service_id).is_empty(): mark(&"SERVICE", service_id, &"DISABLED", Time.get_unix_time_from_system())
				elif service.get("compromised", false) and get_record(&"SERVICE", service_id).is_empty(): mark(&"SERVICE", service_id, &"COMPROMISED", Time.get_unix_time_from_system())
	if controller != null:
		for ice_id: Variant in controller.instances:
			var ice := controller.instances[ice_id] as IceInstance
			if not ice.operational:
				var record := get_record(&"ICE", StringName(ice_id))
				if record.is_empty(): mark(&"ICE", StringName(ice_id), &"DESTROYED", Time.get_unix_time_from_system())
	if alarm_manager != null:
		for alarm_id: Variant in alarm_manager.instances:
			var alarm: Variant = alarm_manager.instances[alarm_id]
			if int(alarm.state) != 0:
				var alarm_record := get_record(&"ALARM", StringName(alarm_id))
				if alarm_record.is_empty(): alarm_record = {"kind": &"ALARM", "id": StringName(alarm_id), "state": &"TRIGGERED"}
				alarm_record["alarm_state"] = alarm.state
				records[_key(&"ALARM", StringName(alarm_id))] = alarm_record

func apply_to_graph(graph: NetworkGraph) -> void:
	if graph == null: return
	for link: NetworkLinkDefinition in graph.links.values():
		var link_record := get_record(&"LINK", link.id)
		if not link_record.is_empty():
			link.disabled = bool(link_record.get("disabled", link.disabled))
			link.locked = bool(link_record.get("locked", link.locked))
			link.hidden = bool(link_record.get("hidden", link.hidden))
			link.discovered = bool(link_record.get("discovered", link.discovered))
	for node: NetworkNodeDefinition in graph.nodes.values():
		for index in node.services.size():
			var service: Dictionary = node.services[index]
			var record := get_record(&"SERVICE", StringName(service.get("id", &"")))
			if not record.is_empty():
				service["runtime_state"] = record.state
				service["disabled"] = record.state == &"DISABLED"
				service["compromised"] = record.state == &"COMPROMISED"
				node.services[index] = service

func apply_to_ice(controller: IceController) -> void:
	if controller == null: return
	for ice_id: Variant in controller.instances:
		var record := get_record(&"ICE", StringName(ice_id))
		if not record.is_empty(): (controller.instances[ice_id] as IceInstance).operational = record.state != &"DESTROYED"

func apply_to_knowledge(knowledge: PlayerKnowledge) -> void:
	if knowledge == null: return
	for service_id: Variant in knowledge.service_records:
		var residue := get_record(&"SERVICE", StringName(service_id))
		if residue.is_empty(): continue
		var service: Dictionary = knowledge.service_records[service_id].duplicate(true)
		service["runtime_state"] = residue.state
		service["disabled"] = residue.state == &"DISABLED"
		service["compromised"] = residue.state == &"COMPROMISED"
		knowledge.service_records[service_id] = service
		var node_id := StringName(service.get("node_id", &""))
		if knowledge.node_records.has(node_id):
			var node: Dictionary = knowledge.node_records[node_id].duplicate(true)
			node["concise_status"] = String(residue.state).to_lower()
			if residue.state == &"COMPROMISED": node["compromised"] = true
			knowledge.node_records[node_id] = node

func apply_to_alarms(alarm_manager: Variant) -> void:
	if alarm_manager == null: return
	for alarm_id: Variant in alarm_manager.instances:
		var record := get_record(&"ALARM", StringName(alarm_id))
		if not record.is_empty() and record.has("alarm_state"): alarm_manager.instances[alarm_id].state = int(record.alarm_state)

func to_save_data() -> Dictionary:
	return records.duplicate(true)

func _key(kind: StringName, id: StringName) -> String:
	return "%s/%s" % [kind, id]
