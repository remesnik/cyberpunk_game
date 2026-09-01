class_name IceState
extends RefCounted

enum Value { DORMANT, PATROL, INVESTIGATE, SEARCH, HUNT, ENGAGE, RETURN }

static func label(state: Value) -> String:
	return Value.keys()[state]
