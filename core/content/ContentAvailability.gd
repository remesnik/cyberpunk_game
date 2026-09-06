class_name ContentAvailability
extends RefCounted

var _rules: Dictionary = {}

func register_content(content_id: StringName, availability: StringName = &"AVAILABLE_IN_ALL_MODES", mode_variants: Dictionary = {}, metadata: Dictionary = {}) -> bool:
	if content_id.is_empty(): return false
	_rules[content_id] = {
		"condition": GameModeCondition.from_id(availability, mode_variants),
		"metadata": metadata.duplicate(true),
	}
	return true

func register_document(document: CyberspaceContentDocument) -> void:
	if document == null: return
	register_content(document.document_id, StringName(document.availability), document.mode_variants, {&"kind": &"AUTHORED_NETWORK", &"runtime_document_path": document.resource_path})
	for entry: Dictionary in document.all_entries():
		register_content(StringName(entry.id), StringName(entry.get("availability", document.availability)), entry.get("mode_variants", {}), {&"collection": entry.get("_collection", &"")})

func is_content_available(content_id: StringName, game_state: PersistentGameState) -> bool:
	var record: Dictionary = _rules.get(content_id, {})
	if record.is_empty(): return false
	return (record.condition as GameModeCondition).is_satisfied(game_state)

func resolve_content_id(content_id: StringName, game_state: PersistentGameState) -> StringName:
	var record: Dictionary = _rules.get(content_id, {})
	if record.is_empty(): return &""
	var condition := record.condition as GameModeCondition
	if not condition.is_satisfied(game_state): return &""
	return condition.resolve_variant(game_state, content_id)

func has_content(content_id: StringName) -> bool:
	return _rules.has(content_id)

func get_metadata(content_id: StringName) -> Dictionary:
	var record: Dictionary = _rules.get(content_id, {})
	return (record.get("metadata", {}) as Dictionary).duplicate(true)

func clear() -> void:
	_rules.clear()
