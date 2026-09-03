class_name DeckAccessibleStorage
extends RefCounted

## An explicit boundary containing only material currently available through a deck.
## Persistent inventory, remote storage, and meat-space possessions are never queried.
var deck_id: StringName
var owner_actor_id: StringName
var capacity := 32
var _entries: Dictionary = {}

func _init(p_deck_id: StringName = &"", p_owner_actor_id: StringName = &"") -> void:
	deck_id = p_deck_id
	owner_actor_id = p_owner_actor_id

func add_entry(entry: DeckStorageEntry) -> bool:
	if entry == null or entry.id.is_empty() or _entries.has(entry.id) or _entries.size() >= capacity:
		return false
	_entries[entry.id] = entry
	return true

func get_entry(entry_id: StringName) -> DeckStorageEntry:
	return _entries.get(entry_id) as DeckStorageEntry

func remove_entry(entry_id: StringName) -> DeckStorageEntry:
	var entry := get_entry(entry_id)
	if entry != null:
		_entries.erase(entry_id)
	return entry

func list_summaries(kind: int, access_level: int) -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for entry: DeckStorageEntry in _entries.values():
		if entry.kind == kind and access_level >= entry.required_access_level:
			visible.append(entry.safe_summary())
	return visible

func has_entry(entry_id: StringName) -> bool:
	return _entries.has(entry_id)

func size() -> int:
	return _entries.size()

func entries_of_kind(kind: int) -> Array[DeckStorageEntry]:
	var result: Array[DeckStorageEntry] = []
	for entry: DeckStorageEntry in _entries.values():
		if entry.kind == kind: result.append(entry)
	return result
