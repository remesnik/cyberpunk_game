class_name KnowledgeLevel
extends RefCounted

enum Value { UNKNOWN, DETECTED, IDENTIFIED, SCANNED, COMPROMISED }

static func label(level: Value) -> String:
	return Value.keys()[level]
