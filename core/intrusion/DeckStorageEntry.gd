class_name DeckStorageEntry
extends RefCounted

enum Kind { FILE, PROGRAM }

var id: StringName
var kind: Kind
var display_name := ""
## Runtime object or content handle explicitly staged on the connected deck.
## It is never populated by walking the owner's persistent inventory.
var content_reference: Variant
var security_level := 0
var required_access_level := 3
var stealable := true
var corruptible := true
var corrupted := false
var planted := false
var metadata: Dictionary = {}
var tags: Array[StringName] = []

func _init(p_id: StringName, p_kind: Kind, p_display_name := "", p_content_reference: Variant = null) -> void:
	id = p_id
	kind = p_kind
	display_name = p_display_name
	content_reference = p_content_reference

func safe_summary() -> Dictionary:
	return {
		"id": id,
		"kind": Kind.keys()[kind],
		"display_name": display_name,
		"security_level": security_level,
		"corrupted": corrupted,
		"planted": planted,
		"tags": tags.duplicate(),
	}
