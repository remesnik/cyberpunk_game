class_name MeatspaceLocationGraph
extends RefCounted

var locations: Dictionary = {}
var connections: Dictionary = {}


func add_location(location_id: StringName, display_name: String = "") -> bool:
	if location_id == &"" or locations.has(location_id):
		return false
	locations[location_id] = {"id": location_id, "display_name": display_name if not display_name.is_empty() else String(location_id).capitalize()}
	connections[location_id] = {}
	return true


func add_connection(from_id: StringName, to_id: StringName, travel_seconds: float, bidirectional := true, access_point_id: StringName = &"") -> bool:
	if not locations.has(from_id) or not locations.has(to_id) or travel_seconds <= 0.0:
		return false
	connections[from_id][to_id] = {"travel_time": travel_seconds, "access_point_id": access_point_id}
	if bidirectional:
		connections[to_id][from_id] = {"travel_time": travel_seconds, "access_point_id": access_point_id}
	return true


func travel_time(from_id: StringName, to_id: StringName) -> float:
	var connection: Variant = connections.get(from_id, {}).get(to_id, {})
	return float(connection.get("travel_time", -1.0)) if connection is Dictionary else float(connection)


func access_point_for(from_id: StringName, to_id: StringName) -> StringName:
	var connection: Variant = connections.get(from_id, {}).get(to_id, {})
	return connection.get("access_point_id", &"") if connection is Dictionary else &""


func is_valid_route(route: Array[StringName]) -> bool:
	if route.is_empty():
		return false
	for index in range(route.size() - 1):
		if travel_time(route[index], route[index + 1]) <= 0.0:
			return false
	return true
