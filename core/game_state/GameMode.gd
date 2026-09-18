class_name GameMode
extends RefCounted

enum Value { STORY, FREE_ROAM }

static func from_frontend_id(mode_id: StringName) -> Value:
	return Value.FREE_ROAM if mode_id in [&"FREE_ROAM", &"FREE_ROAM_MODE"] else Value.STORY

static func to_id(mode: Value) -> StringName:
	return &"FREE_ROAM" if mode == Value.FREE_ROAM else &"STORY"

static func is_valid(value: int) -> bool:
	return value in Value.values()
