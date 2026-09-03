class_name SANAccessSession
extends RefCounted

enum AccessLevel { NONE, OBSERVED, BREACHED, DECK_ACCESS, CONTROL }

var actor_id: StringName
var san_id: StringName
var access_level: AccessLevel = AccessLevel.NONE
var discovered_entry_ids: Array[StringName] = []
var active := true

func _init(p_actor_id: StringName, p_san_id: StringName) -> void:
	actor_id = p_actor_id
	san_id = p_san_id

func grant(level: AccessLevel) -> void:
	access_level = maxi(access_level, level) as AccessLevel
