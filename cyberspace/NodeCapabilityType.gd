class_name NodeCapabilityType
extends RefCounted

enum Value {
	IO,
	FEED,
	DATASTORE,
	DATABASE,
	MEATSPACE,
	COMMUNICATIONS,
	CONTROL_SYSTEM,
	SECURITY,
	ICE,
	SOFTWARE,
	CREDENTIALS,
	ACTIVE_PROCESS,
	SYSTEM_ACCESS_NODE,
	OBJECTIVE,
}

static func key(value: Value) -> StringName:
	return StringName(Value.keys()[int(value)])

static func parse(value: Variant) -> int:
	if value is int and int(value) >= 0 and int(value) < Value.size():
		return int(value)
	var normalized := StringName(String(value).to_upper())
	for index in Value.size():
		if key(index) == normalized:
			return index
	return -1

