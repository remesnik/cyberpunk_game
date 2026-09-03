class_name SANInteractionRequest
extends RefCounted

const INSPECT := &"INSPECT"
const BREACH := &"BREACH"
const ACCESS_FILES := &"ACCESS_FILES"
const ACCESS_PROGRAMS := &"ACCESS_PROGRAMS"
const STEAL_FILE := &"STEAL_FILE"
const STEAL_PROGRAM := &"STEAL_PROGRAM"
const CORRUPT_PROGRAM := &"CORRUPT_PROGRAM"
const PLANT_PROGRAM := &"PLANT_PROGRAM"
const TRACE_OWNER := &"TRACE_OWNER"
const DUMP_OWNER := &"DUMP_OWNER"

var actor_id: StringName
var actor_kind: StringName = &"HOSTILE_HACKER"
var intrusion_id: StringName
var actor_node_id: StringName
var san_id: StringName
var action_type: StringName
var target_entry_id: StringName
var hacking_power := 0
var authority_level := 0
var program_id: StringName
var capabilities: Array[StringName] = []
var destination_storage: DeckAccessibleStorage
var planted_entry: DeckStorageEntry
var metadata: Dictionary = {}

func _init(p_actor_id: StringName = &"", p_san_id: StringName = &"", p_action_type: StringName = &"") -> void:
	actor_id = p_actor_id
	san_id = p_san_id
	action_type = p_action_type
