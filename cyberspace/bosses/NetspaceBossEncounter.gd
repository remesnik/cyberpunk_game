class_name NetspaceBossEncounter
extends RefCounted
## Authoritative, tick-driven state for system-style Netspace bosses.
## Presentation consumes target_views(); normal commands mutate it through apply_command().

signal state_changed(snapshot: Dictionary)
signal event_emitted(event: Dictionary)

enum Archetype { WARDEN, HUNTER, VAULT, ARCHITECT, HYDRA, SWARM, AUDITOR, GHOST, MIRROR, ROOT }
enum BossResolution { ACTIVE, DEFEATED, BYPASSED }

var id: StringName
var archetype: Archetype
var node_id: StringName
var phase: StringName
var completed := false
var bypassed := false
var tick_count := 0
var graph: NetworkGraph
var services: Dictionary = {}
var actors: Dictionary = {}
var objective: Dictionary = {}
var encounter_state: Dictionary = {}
var _original_link_states: Dictionary = {}
var _action_clock: ActionClock
var _player_position: PlayerNetworkPosition

func resolution() -> BossResolution:
	if bypassed: return BossResolution.BYPASSED
	if archetype == Archetype.WARDEN and not actor_active(&"WARDEN"): return BossResolution.DEFEATED
	if completed: return BossResolution.DEFEATED
	return BossResolution.ACTIVE

func is_resolved() -> bool: return resolution() != BossResolution.ACTIVE

static func create(kind: Archetype, encounter_id: StringName, host_node_id: StringName, network: NetworkGraph = null) -> NetspaceBossEncounter:
	var result := NetspaceBossEncounter.new()
	result.id = encounter_id; result.archetype = kind; result.node_id = host_node_id; result.graph = network
	result._initialize()
	return result

func _initialize() -> void:
	match archetype:
		Archetype.WARDEN: _init_warden()
		Archetype.HUNTER: _init_hunter()
		Archetype.VAULT: _init_vault()
		Archetype.ARCHITECT: _init_architect()
		Archetype.HYDRA: _init_hydra()
		Archetype.SWARM: _init_swarm()
		Archetype.AUDITOR: _init_auditor()
		Archetype.GHOST: _init_ghost()
		Archetype.MIRROR: _init_mirror()
		Archetype.ROOT: _init_root()

func bind_action_clock(clock: ActionClock, player_position: PlayerNetworkPosition) -> void:
	if _action_clock != null: _action_clock.unregister_network_updater(_on_action_clock_update)
	_action_clock = clock; _player_position = player_position
	if _action_clock != null: _action_clock.register_network_updater(_on_action_clock_update)

func _on_action_clock_update(_current_tick: int, request: ActionRequest) -> Array[Dictionary]:
	var current := _player_position.current_node_id if _player_position != null else &""
	return tick(current, StringName(request.get_action_name()))

func _service(suffix: String, title: String, role: StringName) -> Dictionary:
	return {"id": StringName("%s_%s" % [id, suffix]), "node_id": node_id, "display_name": title, "role": role, "active": true, "disabled": false, "scanned": false, "operational": true}

func _actor(suffix: String, title: String, role: StringName, host := node_id) -> Dictionary:
	return {"id": StringName("%s_%s" % [id, suffix]), "node_id": host, "display_name": title, "role": role, "active": true, "disabled": false, "scanned": false, "integrity": 12, "maximum_integrity": 12}

func _objective(title: String) -> Dictionary:
	return {"id": StringName("%s_OBJECTIVE" % id), "node_id": node_id, "display_name": title, "accessible": false, "downloaded": false, "scanned": false, "locked": true}

func _init_warden() -> void:
	phase = &"PROTECTED"
	services = {&"AUTHENTICATION": _service("AUTH", "Authentication Service", &"AUTHENTICATION"), &"TRACE": _service("TRACE", "Trace Service", &"TRACE"), &"ALARM": _service("ALARM", "Alarm Service", &"ALARM")}
	actors = {&"WARDEN": _actor("WARDEN", "THE WARDEN", &"BOSS")}
	objective = _objective("Warden Objective")

func configure_objective(objective_id: StringName, title: String) -> void:
	if objective.is_empty(): return
	objective["id"] = objective_id
	objective["display_name"] = title
	objective["node_id"] = node_id
	state_changed.emit(snapshot())

func _init_hunter() -> void:
	phase = &"PURSUIT"; actors = {&"HUNTER": _actor("HUNTER", "THE HUNTER", &"BOSS", node_id)}
	encounter_state = {"detected": false, "contact_pressure": 0, "last_known_player_node": &"", "accelerated": false}

func _init_vault() -> void:
	phase = &"SEALED"
	services = {&"AUTHENTICATION": _service("AUTH", "Authentication Service", &"AUTHENTICATION"), &"ENCRYPTION": _service("ENCRYPTION", "Encryption Service", &"ENCRYPTION"), &"AUDIT": _service("AUDIT", "Audit Service", &"AUDIT"), &"CONTROL": _service("CONTROL", "Control Service", &"CONTROL"), &"FILE_STORE": _service("STORE", "Protected File Store", &"FILE_STORE")}
	objective = _objective("Vault Objective File")
	encounter_state = {"authenticated": false, "control_owned": false, "trace_pressure": 2}

func _init_architect() -> void:
	phase = &"OBSERVING"; actors = {&"ARCHITECT": _actor("ARCHITECT", "THE ARCHITECT", &"BOSS")}
	encounter_state = {"route_cursor": 0, "warnings": {}, "link_states": {}}
	if graph != null:
		for link: NetworkLinkDefinition in graph.links.values(): _original_link_states[link.id] = _link_state(link)

func _init_hydra() -> void:
	phase = &"DISTRIBUTED"
	actors = {&"DEFENSE": _actor("HEAD_A", "HYDRA // DEFENSE", &"DEFENSE"), &"TRACE": _actor("HEAD_B", "HYDRA // TRACE", &"TRACE"), &"REGENERATION": _actor("HEAD_C", "HYDRA // REGENERATION", &"REGENERATION")}
	encounter_state = {"stability": 3, "neutralization_window": 0}

func _init_swarm() -> void:
	phase = &"SPAWNING"; services = {&"SPAWN": _service("SPAWN", "Swarm Controller", &"SPAWN")}
	encounter_state = {"spawn_interval": 2, "maximum_active": 4, "spawn_serial": 0}

func _init_auditor() -> void:
	phase = &"OBSERVE"; actors = {&"AUDITOR": _actor("AUDITOR", "THE AUDITOR", &"BOSS")}
	services = {&"LOGGING": _service("LOGGING", "Logging Service", &"LOGGING"), &"TRACE": _service("TRACE", "Trace Service", &"TRACE"), &"CORRELATION": _service("CORRELATION", "Correlation Service", &"CORRELATION")}
	encounter_state = {"repeated_actions": {}, "trace_pressure": 1}

func _init_ghost() -> void:
	phase = &"UNKNOWN"; actors = {&"GHOST": _actor("GHOST", "UNKNOWN PROCESS", &"BOSS"), &"DECOY_A": _actor("DECOY_A", "INCONSISTENT SIGNAL", &"DECOY"), &"DECOY_B": _actor("DECOY_B", "DUPLICATE SIGNAL", &"DECOY")}
	encounter_state = {"identification": 0, "required_identification": 3}

func _init_mirror() -> void:
	phase = &"REFLECTING"; actors = {&"MIRROR": _actor("MIRROR", "THE MIRROR", &"BOSS")}
	encounter_state = {"usage": {}, "adaptations": {}, "threshold": 3, "decay_ticks": 4, "last_used": {}}

func _init_root() -> void:
	phase = &"ACCESS"
	services = {&"AUTHENTICATION": _service("AUTH", "Root Authentication", &"AUTHENTICATION"), &"TRACE": _service("TRACE", "Root Trace", &"TRACE"), &"CONTROL": _service("CONTROL", "Root Control", &"CONTROL")}
	actors = {&"ROOT": _actor("CORE", "THE ROOT", &"BOSS")}
	objective = _objective("Root Access Core")
	encounter_state = {"phase_objective_complete": false, "temporary_actor_ids": [], "distributed_components": 3}

func service_active(role: StringName) -> bool:
	return services.has(role) and bool((services[role] as Dictionary).get("active", false)) and not bool((services[role] as Dictionary).get("disabled", false))

func disable_service(role: StringName) -> bool:
	if not services.has(role): return false
	var service := services[role] as Dictionary
	if bool(service.get("disabled", false)): return false
	service["active"] = false; service["disabled"] = true; service["operational"] = false
	services[role] = service; _recalculate(); _emit(&"BOSS_SERVICE_DISABLED", {"service_role": role})
	return true

func set_authenticated(value: bool) -> void:
	encounter_state["authenticated"] = value; _recalculate()

func take_control() -> void:
	encounter_state["control_owned"] = true; _recalculate()

func access_file_store() -> bool:
	if archetype != Archetype.VAULT or not service_active(&"FILE_STORE") or not bool(encounter_state.get("authenticated", false)): return false
	encounter_state["file_store_access"] = true; _recalculate(); return true

func defense_multiplier() -> float:
	if archetype == Archetype.WARDEN: return 1.75 if service_active(&"AUTHENTICATION") else 1.0
	if archetype == Archetype.HYDRA and actor_active(&"DEFENSE"): return 1.5
	return 1.0

func trace_multiplier() -> float:
	match archetype:
		Archetype.WARDEN: return 1.6 if service_active(&"TRACE") else 1.0
		Archetype.VAULT: return 1.5 if service_active(&"AUDIT") else 1.0
		Archetype.AUDITOR:
			var pressure := 1.0
			if service_active(&"LOGGING"): pressure += 0.35
			if service_active(&"TRACE"): pressure += 0.45
			if service_active(&"CORRELATION"): pressure += 0.25
			return pressure
	return 1.0

func reinforcement_enabled() -> bool:
	return (archetype == Archetype.WARDEN and service_active(&"ALARM")) or (archetype == Archetype.SWARM and service_active(&"SPAWN"))

func actor_active(role: StringName) -> bool:
	return actors.has(role) and bool((actors[role] as Dictionary).get("active", false)) and not bool((actors[role] as Dictionary).get("disabled", false))

func disable_actor(role: StringName) -> bool:
	if not actors.has(role): return false
	var actor := actors[role] as Dictionary; actor["active"] = false; actor["disabled"] = true; actors[role] = actor
	if archetype == Archetype.HYDRA: encounter_state.stability = maxi(0, int(encounter_state.stability) - 1)
	_recalculate(); _emit(&"BOSS_ACTOR_DISABLED", {"actor_role": role}); return true

func _recalculate() -> void:
	match archetype:
		Archetype.WARDEN:
			var active_supports := 0
			for role in [&"AUTHENTICATION", &"TRACE", &"ALARM"]:
				if service_active(role): active_supports += 1
			phase = &"PROTECTED" if active_supports == 3 else (&"ALERT" if active_supports >= 2 else &"ISOLATED")
			objective.accessible = not actor_active(&"WARDEN") or bypassed; objective.locked = not objective.accessible
		Archetype.VAULT:
			objective.accessible = bool(encounter_state.get("authenticated", false)) and not service_active(&"ENCRYPTION") and (bool(encounter_state.get("file_store_access", false)) or bool(encounter_state.get("control_owned", false)))
			objective.locked = not objective.accessible; phase = &"OPEN" if objective.accessible else (&"BREACHED" if bool(encounter_state.get("authenticated", false)) else &"SEALED")
		Archetype.HYDRA:
			if int(encounter_state.get("stability", 3)) == 0: phase = &"CORE_EXPOSED"; completed = true
		Archetype.SWARM:
			if not service_active(&"SPAWN") and _active_swarm_count() == 0: completed = true; phase = &"DEFEATED"
		Archetype.AUDITOR:
			if not actor_active(&"AUDITOR"): phase = &"DEFEATED"
		Archetype.GHOST:
			var score := int(encounter_state.get("identification", 0)); phase = &"EXPOSED" if score >= 3 else (&"IDENTIFIED" if score == 2 else (&"SUSPECTED" if score == 1 else &"UNKNOWN"))
		Archetype.ROOT: _recalculate_root()
	state_changed.emit(snapshot())

func tick(player_node_id: StringName = &"", player_action: StringName = &"") -> Array[Dictionary]:
	if completed: return []
	tick_count += 1
	var produced: Array[Dictionary] = []
	match archetype:
		Archetype.WARDEN:
			if service_active(&"ALARM") and tick_count % 3 == 0: produced.append(_event(&"ALARM_ESCALATED", {"node_id": node_id}))
			if phase == &"ISOLATED" and tick_count % 4 == 0: produced.append(_event(&"WARDEN_HARDENING", {}))
		Archetype.HUNTER: produced.append_array(_hunter_tick(player_node_id))
		Archetype.ARCHITECT: produced.append_array(_architect_tick())
		Archetype.HYDRA: produced.append_array(_hydra_tick())
		Archetype.SWARM: produced.append_array(_swarm_tick())
		Archetype.AUDITOR: produced.append_array(_auditor_tick(player_action))
		Archetype.MIRROR: _decay_mirror()
		Archetype.ROOT: produced.append_array(_root_tick(player_node_id))
	for event in produced: event_emitted.emit(event)
	_recalculate(); return produced

func _hunter_tick(player_node_id: StringName) -> Array[Dictionary]:
	if graph == null or player_node_id == &"" or not actors.has(&"HUNTER"): return []
	var hunter := actors[&"HUNTER"] as Dictionary; var from := StringName(hunter.node_id)
	encounter_state.last_known_player_node = player_node_id
	if from == player_node_id:
		encounter_state.contact_pressure = int(encounter_state.contact_pressure) + 1; phase = &"CONTACT"
		return [_event(&"HUNTER_CONTACT", {"node_id": from, "trace_increase": 2, "damage": 1})]
	var path := _shortest_path(from, player_node_id)
	if path.size() < 2: return []
	hunter.node_id = path[1]; actors[&"HUNTER"] = hunter
	var link := graph.find_link(from, StringName(path[1]))
	return [_event(&"ICE_MOVED_DEBUG", {"ice_id": hunter.id, "from": from, "to": path[1], "link_id": link.id if link != null else &""})]

func _shortest_path(start: StringName, goal: StringName) -> Array[StringName]:
	if graph == null or graph.get_node(start) == null or graph.get_node(goal) == null: return []
	var queue: Array[StringName] = [start]; var previous := {start: &""}
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		if current == goal: break
		for next in graph.get_visible_connected_nodes(current):
			var link := graph.find_link(current, next)
			if previous.has(next) or link == null or link.disabled or link.locked: continue
			previous[next] = current; queue.append(next)
	if not previous.has(goal): return []
	var path: Array[StringName] = []; var cursor := goal
	while cursor != &"": path.push_front(cursor); cursor = StringName(previous[cursor])
	return path

func set_link_state(link_id: StringName, state: StringName) -> bool:
	if graph == null: return false
	var link := graph.get_link(link_id); if link == null: return false
	if not _original_link_states.has(link_id): _original_link_states[link_id] = _link_state(link)
	match state:
		&"ACTIVE": link.disabled = false; link.locked = false; link.one_way = false
		&"BLOCKED": link.disabled = false; link.locked = true
		&"HOSTILE": link.disabled = false; link.locked = false; link.set_meta(&"hostile", true)
		&"ONE_WAY": link.disabled = false; link.locked = false; link.one_way = true
		&"DISABLED": link.disabled = true; link.locked = false
		_: return false
	var link_states := encounter_state.get("link_states", {}) as Dictionary; link_states[link_id] = state; encounter_state["link_states"] = link_states
	link.set_meta(&"runtime_state", state); graph.display_update_requested.emit(); _emit(&"BOSS_LINK_STATE_CHANGED", {"link_id": link_id, "state": state}); return true

func _architect_tick() -> Array[Dictionary]:
	if graph == null or graph.links.is_empty(): return []
	var ids: Array = graph.links.keys(); ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var cursor := int(encounter_state.get("route_cursor", 0)) % ids.size(); var link_id := StringName(ids[cursor])
	encounter_state.route_cursor = cursor + 1
	var state: StringName = [&"BLOCKED", &"ONE_WAY", &"HOSTILE", &"ACTIVE"][tick_count % 4]
	set_link_state(link_id, state)
	phase = &"CONTAINMENT" if tick_count >= 3 else &"OBSERVING"
	return [_event(&"ARCHITECT_ROUTE_CHANGED", {"link_id": link_id, "state": state})]

func _hydra_tick() -> Array[Dictionary]:
	if actor_active(&"REGENERATION") and tick_count % 2 == 0:
		for role in [&"DEFENSE", &"TRACE"]:
			if not actors.has(role): continue
			var head := actors[role] as Dictionary
			if bool(head.disabled): head.disabled = false; head.active = true; head.integrity = 4; actors[role] = head; encounter_state.stability = int(encounter_state.stability) + 1; return [_event(&"HYDRA_HEAD_REGENERATED", {"actor_role": role})]
	return []

func _swarm_tick() -> Array[Dictionary]:
	if not service_active(&"SPAWN") or tick_count % int(encounter_state.spawn_interval) != 0 or _active_swarm_count() >= int(encounter_state.maximum_active): return []
	encounter_state.spawn_serial = int(encounter_state.spawn_serial) + 1; var role := StringName("UNIT_%d" % int(encounter_state.spawn_serial)); actors[role] = _actor(String(role), "SWARM UNIT", &"SWARM")
	return [_event(&"SWARM_UNIT_SPAWNED", {"actor_id": (actors[role] as Dictionary).id})]

func _active_swarm_count() -> int:
	var count := 0
	for actor: Dictionary in actors.values():
		if actor.get("role") == &"SWARM" and bool(actor.get("active", false)): count += 1
	return count

func _auditor_tick(action: StringName) -> Array[Dictionary]:
	if action == &"": return []
	var repeated := encounter_state.repeated_actions as Dictionary; repeated[action] = int(repeated.get(action, 0)) + 1; encounter_state.repeated_actions = repeated
	var count := int(repeated[action]); phase = &"IDENTIFIED" if count >= 3 else (&"CORRELATE" if count >= 2 else &"OBSERVE")
	var extra := (count - 1 if service_active(&"CORRELATION") else 0) + (1 if service_active(&"LOGGING") else 0)
	return [_event(&"AUDITOR_TRACE", {"action": action, "trace_increase": maxi(0, extra)})]

func identify_ghost(target_role: StringName) -> Dictionary:
	if archetype != Archetype.GHOST or not actors.has(target_role): return {"success": false}
	if target_role != &"GHOST": actors.erase(target_role); _emit(&"GHOST_DECOY_REMOVED", {"actor_role": target_role}); return {"success": true, "decoy": true}
	var ghost := actors[&"GHOST"] as Dictionary; ghost.scanned = true; actors[&"GHOST"] = ghost
	encounter_state.identification = mini(int(encounter_state.required_identification), int(encounter_state.identification) + 1); _recalculate()
	return {"success": true, "decoy": false, "phase": phase}

func record_program(program_id: StringName) -> float:
	if archetype != Archetype.MIRROR: return 1.0
	var usage := encounter_state.usage as Dictionary; usage[program_id] = int(usage.get(program_id, 0)) + 1; encounter_state.usage = usage
	var last := encounter_state.last_used as Dictionary; last[program_id] = tick_count; encounter_state.last_used = last
	if int(usage[program_id]) >= int(encounter_state.threshold):
		var adaptations := encounter_state.adaptations as Dictionary; adaptations[program_id] = 0.5; encounter_state.adaptations = adaptations; _emit(&"MIRROR_ADAPTED", {"program_id": program_id})
	return float((encounter_state.adaptations as Dictionary).get(program_id, 1.0))

func _decay_mirror() -> void:
	var adaptations := encounter_state.adaptations as Dictionary; var last := encounter_state.last_used as Dictionary
	for program_id in adaptations.keys():
		if tick_count - int(last.get(program_id, 0)) >= int(encounter_state.decay_ticks): adaptations.erase(program_id)
	encounter_state.adaptations = adaptations

func advance_root_phase() -> bool:
	if archetype != Archetype.ROOT: return false
	match phase:
		&"ACCESS":
			if service_active(&"AUTHENTICATION") or service_active(&"TRACE") or service_active(&"CONTROL"): return false
			phase = &"CONTAINMENT"
		&"CONTAINMENT": phase = &"PURSUIT"; actors[&"HUNTER"] = _actor("HUNTER", "ROOT HUNTER", &"HUNTER")
		&"PURSUIT": actors.erase(&"HUNTER"); phase = &"DISTRIBUTED"; for index in 3: actors[StringName("COMPONENT_%d" % index)] = _actor("COMPONENT_%d" % index, "ROOT COMPONENT", &"COMPONENT")
		&"DISTRIBUTED":
			for role in actors:
				if String(role).begins_with("COMPONENT_") and actor_active(StringName(role)): return false
			phase = &"FINAL_ACCESS"; objective.accessible = true; objective.locked = false
		&"FINAL_ACCESS": completed = true; phase = &"DEFEATED"
		_: return false
	_emit(&"ROOT_PHASE_CHANGED", {"phase": phase}); state_changed.emit(snapshot()); return true

func _recalculate_root() -> void:
	if phase == &"ACCESS" and not service_active(&"AUTHENTICATION") and not service_active(&"TRACE") and not service_active(&"CONTROL"): encounter_state.phase_objective_complete = true

func _root_tick(player_node_id: StringName) -> Array[Dictionary]:
	if phase != &"PURSUIT" or not actors.has(&"HUNTER") or graph == null: return []
	var hunter := actors[&"HUNTER"] as Dictionary; var from := StringName(hunter.node_id); var path := _shortest_path(from, player_node_id)
	if path.size() < 2: return [_event(&"ROOT_HUNTER_CONTACT", {"node_id": from})] if from == player_node_id else []
	hunter.node_id = path[1]; actors[&"HUNTER"] = hunter; return [_event(&"ICE_MOVED_DEBUG", {"ice_id": hunter.id, "from": from, "to": path[1]})]

func target_views() -> Dictionary:
	var result := {}
	for service: Dictionary in services.values():
		result[service.id] = {"kind": &"SERVICE", "title": service.display_name, "service": service.duplicate(true), "scanned": service.scanned, "probeable": service.scanned, "connectable": service.scanned and archetype == Archetype.VAULT and service.role == &"FILE_STORE" and bool(encounter_state.get("authenticated", false)), "disableable": service.scanned and service.active, "boss_id": id, "boss_phase": phase, "dependencies": _dependencies_for(StringName(service.role))}
	for actor: Dictionary in actors.values():
		var exposed: bool = archetype != Archetype.GHOST or phase in [&"IDENTIFIED", &"EXPOSED"] or actor.role == &"DECOY"
		result[actor.id] = {"kind": &"ICE", "title": actor.display_name, "ice": actor.duplicate(true), "actor_id": actor.id, "scanned": actor.scanned, "attackable": exposed and actor.scanned, "bypassable": archetype == Archetype.WARDEN and actor.scanned and phase == &"ISOLATED", "boss_id": id, "boss_phase": phase, "dependencies": _dependencies_for(StringName(actor.role))}
	if not objective.is_empty(): result[objective.id] = {"kind": &"FILE", "title": objective.display_name, "file": objective.duplicate(true), "scanned": objective.scanned, "downloadable": objective.accessible and not objective.downloaded, "boss_id": id, "boss_phase": phase}
	return result

func _dependencies_for(role: StringName) -> Array[StringName]:
	match archetype:
		Archetype.WARDEN:
			if role == &"BOSS": return [&"AUTHENTICATION: DEFENSE", &"TRACE: TRACE PRESSURE", &"ALARM: REINFORCEMENTS"]
		Archetype.VAULT: return [&"AUTHENTICATION gates access", &"ENCRYPTION gates download", &"AUDIT adds trace"]
		Archetype.HYDRA: return ["Shared Hydra stability", "%s head role" % role]
		Archetype.GHOST: return ["Scan/Probe reveals identity", "Decoys return inconsistent metadata"]
		Archetype.MIRROR: return ["Repeated program signatures gain temporary resistance"]
	return []

func apply_command(target_id: StringName, command: StringName) -> Dictionary:
	for role in services:
		if StringName((services[role] as Dictionary).id) == target_id:
			if command == &"CONNECT" and StringName(role) == &"FILE_STORE": return {"success": access_file_store(), "events": []}
			if command in [&"DISABLE", &"BYPASS"]: return {"success": disable_service(StringName(role)), "events": []}
			if command in [&"SCAN", &"PROBE"]: var service := services[role] as Dictionary; service.scanned = true; services[role] = service; return {"success": true, "details": _dependencies_for(StringName(role))}
	for role in actors:
		if StringName((actors[role] as Dictionary).id) != target_id: continue
		if archetype == Archetype.GHOST and command in [&"SCAN", &"PROBE"]: return identify_ghost(StringName(role))
		if command in [&"ATTACK", &"BYPASS"]:
			if command == &"BYPASS": bypassed = true
			var changed := disable_actor(StringName(role)); _recalculate()
			return {"success": changed, "events": [], "resolution": BossResolution.keys()[resolution()]}
		if command in [&"SCAN", &"PROBE"]: var actor := actors[role] as Dictionary; actor.scanned = true; actors[role] = actor; return {"success": true, "details": _dependencies_for(StringName(actor.role))}
	if not objective.is_empty() and target_id == StringName(objective.id) and command == &"DOWNLOAD" and bool(objective.accessible): objective.downloaded = true; completed = true; phase = &"DEFEATED"; return {"success": true}
	return {"success": false, "reason": "Command is not valid for this boss target."}

func cleanup() -> void:
	if _action_clock != null: _action_clock.unregister_network_updater(_on_action_clock_update)
	_action_clock = null; _player_position = null
	if graph != null:
		for link_id in _original_link_states:
			var link := graph.get_link(StringName(link_id)); if link == null: continue
			var state := _original_link_states[link_id] as Dictionary; link.disabled = state.disabled; link.locked = state.locked; link.one_way = state.one_way; link.remove_meta(&"hostile"); link.remove_meta(&"runtime_state")
		graph.display_update_requested.emit()
	encounter_state.erase("adaptations"); encounter_state.erase("usage"); completed = true; state_changed.emit(snapshot())

func snapshot() -> Dictionary:
	return {"id": id, "archetype": archetype, "node_id": node_id, "phase": phase, "completed": completed, "bypassed": bypassed, "tick_count": tick_count, "services": services.duplicate(true), "actors": actors.duplicate(true), "objective": objective.duplicate(true), "encounter_state": encounter_state.duplicate(true)}

func restore(data: Dictionary) -> void:
	id = StringName(data.get("id", id)); archetype = int(data.get("archetype", archetype)) as Archetype; node_id = StringName(data.get("node_id", node_id)); phase = StringName(data.get("phase", phase)); completed = bool(data.get("completed", false)); bypassed = bool(data.get("bypassed", false)); tick_count = int(data.get("tick_count", 0)); services = data.get("services", {}).duplicate(true); actors = data.get("actors", {}).duplicate(true); objective = data.get("objective", {}).duplicate(true); encounter_state = data.get("encounter_state", {}).duplicate(true)
	if archetype == Archetype.ARCHITECT and graph != null:
		for link_id in (encounter_state.get("link_states", {}) as Dictionary): set_link_state(StringName(link_id), StringName(encounter_state.link_states[link_id]))

func _link_state(link: NetworkLinkDefinition) -> Dictionary:
	return {"disabled": link.disabled, "locked": link.locked, "one_way": link.one_way}

func _event(type: StringName, extra: Dictionary) -> Dictionary:
	var event := {"type": type, "boss_id": id, "phase": phase, "tick": tick_count}; event.merge(extra, true); return event

func _emit(type: StringName, extra: Dictionary) -> void:
	event_emitted.emit(_event(type, extra))
