class_name RealtimeProcessManager
extends Node

signal process_added(process: RealtimeProcess)
signal process_state_changed(process_id: StringName, previous_state: RealtimeProcess.State, current_state: RealtimeProcess.State)
signal processes_updated(realtime_session_seconds: float)

var processes: Dictionary = {}
var endpoints: Dictionary = {}
var _clock: Node
var _last_clock_time := 0.0


func bind_clock(clock: Node) -> void:
	if _clock != null and _clock.elapsed_time_changed.is_connected(_on_clock_time_changed):
		_clock.elapsed_time_changed.disconnect(_on_clock_time_changed)
	_clock = clock
	_last_clock_time = float(_clock.elapsed_seconds)
	if not _clock.elapsed_time_changed.is_connected(_on_clock_time_changed):
		_clock.elapsed_time_changed.connect(_on_clock_time_changed)


func add_process(process: RealtimeProcess, activate := false) -> bool:
	if process == null or process.id == &"" or processes.has(process.id):
		return false
	processes[process.id] = process
	if activate:
		activate_process(process.id)
	process_added.emit(process)
	return true


func add_endpoint(endpoint: RealtimeEndpointDefinition) -> bool:
	if endpoint == null or endpoint.id == &"" or endpoints.has(endpoint.id):
		return false
	for process_id: StringName in endpoint.associated_realtime_process_ids:
		if not processes.has(process_id):
			return false
	endpoints[endpoint.id] = endpoint
	return true


func get_endpoint(endpoint_id: StringName) -> RealtimeEndpointDefinition:
	return endpoints.get(endpoint_id)


func get_endpoints_for_node(node_id: StringName) -> Array[RealtimeEndpointDefinition]:
	var result: Array[RealtimeEndpointDefinition] = []
	for value: Variant in endpoints.values():
		var endpoint := value as RealtimeEndpointDefinition
		if endpoint.network_node_id == node_id:
			result.append(endpoint)
	result.sort_custom(func(a: RealtimeEndpointDefinition, b: RealtimeEndpointDefinition) -> bool: return String(a.id) < String(b.id))
	return result


func remove_process(process_id: StringName) -> bool:
	return processes.erase(process_id)


func get_process(process_id: StringName) -> RealtimeProcess:
	return processes.get(process_id)


func activate_process(process_id: StringName) -> bool:
	var process := get_process(process_id)
	if process == null or process.state in [RealtimeProcess.State.COMPLETED, RealtimeProcess.State.FAILED, RealtimeProcess.State.LOST]:
		return false
	var previous := process.state
	if process.elapsed_time == 0.0:
		process.start_time = _last_clock_time
	process.state = RealtimeProcess.State.ACTIVE
	if previous != process.state:
		process_state_changed.emit(process.id, previous, process.state)
	return true


func set_process_state(process_id: StringName, state: RealtimeProcess.State) -> bool:
	var process := get_process(process_id)
	if process == null:
		return false
	var previous := process.state
	process.state = state
	if previous != state:
		process_state_changed.emit(process.id, previous, state)
	return true


## Public for deterministic tests and restore/catch-up coordinators. The argument is
## an absolute RealtimeWorldClock session timestamp, never a cyberspace tick.
func advance_to_realtime(realtime_session_seconds: float) -> void:
	var delta := maxf(0.0, realtime_session_seconds - _last_clock_time)
	_last_clock_time = maxf(_last_clock_time, realtime_session_seconds)
	if delta == 0.0:
		return
	for value: Variant in processes.values():
		var process := value as RealtimeProcess
		if not process.is_running():
			continue
		process.elapsed_time += delta
		if process.has_finite_duration() and process.elapsed_time >= process.duration:
			process.elapsed_time = process.duration
			var previous := process.state
			process.state = RealtimeProcess.State.COMPLETED
			process_state_changed.emit(process.id, previous, process.state)
	processes_updated.emit(_last_clock_time)


func _on_clock_time_changed(realtime_session_seconds: float) -> void:
	advance_to_realtime(realtime_session_seconds)
