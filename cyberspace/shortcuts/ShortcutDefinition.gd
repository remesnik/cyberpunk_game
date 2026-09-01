class_name ShortcutDefinition
extends RefCounted

enum ShortcutType { COMPROMISED_ROUTER, ENCRYPTED_TUNNEL, STOLEN_CREDENTIAL, ENABLED_GATEWAY }

var id: StringName
var shortcut_type: ShortcutType
var link_id: StringName
var reduced_traversal_cost: int
var credential_granted: StringName

func _init(p_id: StringName, p_type: ShortcutType, p_link_id: StringName, p_reduced_cost := 1, p_credential: StringName = &"") -> void:
	id = p_id
	shortcut_type = p_type
	link_id = p_link_id
	reduced_traversal_cost = maxi(p_reduced_cost, 0)
	credential_granted = p_credential
