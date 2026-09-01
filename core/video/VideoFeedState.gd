class_name VideoFeedState
extends RefCounted

enum Value { LIVE, OFFLINE, FROZEN, LOOPED, SPOOFED, FAULT }


static func label(state: Value) -> String:
	return Value.keys()[state]

