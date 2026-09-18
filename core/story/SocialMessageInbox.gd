class_name SocialMessageInbox
extends RefCounted
## Persistent authored background contacts; dialogue sequences remain separate.
signal message_delivered(message: Dictionary)
signal inbox_changed(view: Dictionary)

enum Priority { AMBIENT, OPTIONAL, CRITICAL }

var game_state: PersistentGameState
var definitions: Array = []

func configure(state: PersistentGameState, authored: Array = []) -> void:
	game_state = state
	definitions = authored.duplicate(true)
	_store()

func evaluate(trigger: StringName, context: Dictionary = {}) -> Array[Dictionary]:
	var delivered: Array[Dictionary] = []
	for definition: Dictionary in definitions:
		if StringName(definition.get("trigger", &"")) != trigger or not _eligible(definition, context): continue
		var message := _deliver(definition, context)
		if not message.is_empty(): delivered.append(message)
	return delivered

func add_authored(id: StringName, actor_id: StringName, text: String, priority := Priority.OPTIONAL, repeatable := false, context: Dictionary = {}) -> Dictionary:
	return _deliver({"id": id, "actor_id": actor_id, "text": text, "priority": priority, "repeatable": repeatable}, context)

func mark_read(id: StringName) -> bool:
	var store := _store()
	var messages: Array = store.messages
	for index in messages.size():
		if StringName(messages[index].get("instance_id", messages[index].id)) != id and StringName(messages[index].id) != id: continue
		if bool(messages[index].get("read", false)): continue
		messages[index]["read"] = true
		store["messages"] = messages
		_commit(store)
		return true
	return false

func mark_next_read(maximum_priority := Priority.OPTIONAL) -> Dictionary:
	for message: Dictionary in unread_messages():
		if int(message.priority) <= maximum_priority:
			mark_read(StringName(message.instance_id)); return message
	return {}

func unread_messages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for message: Dictionary in _store().messages:
		if not bool(message.get("read", false)): result.append(message.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.priority) > int(b.priority) if int(a.priority) != int(b.priority) else float(a.delivered_at) < float(b.delivered_at))
	return result

func unread_count() -> int: return unread_messages().size()
func has_critical_unread() -> bool: return unread_messages().any(func(message: Dictionary) -> bool: return int(message.priority) == Priority.CRITICAL)

func view() -> Dictionary:
	return {"unread_count": unread_count(), "critical_unread": has_critical_unread(), "messages": (_store().messages as Array).duplicate(true)}

func _eligible(definition: Dictionary, context: Dictionary) -> bool:
	var flags: Dictionary = game_state.campaign_state.get("story_flags", {})
	for flag: Variant in definition.get("required_flags", []):
		if not bool(flags.get(flag, false)): return false
	for flag: Variant in definition.get("absent_flags", []):
		if bool(flags.get(flag, false)): return false
	if context.get("success", true) != definition.get("success", context.get("success", true)): return false
	if int(context.get("trace", 0)) < int(definition.get("minimum_trace", 0)): return false
	var store := _store()
	var delivered: Dictionary = store.delivered
	if not bool(definition.get("repeatable", false)) and delivered.has(String(definition.id)): return false
	var cooldown := int(definition.get("cooldown_progress", 0))
	if cooldown > 0 and int(context.get("progress", 0)) - int(delivered.get(String(definition.id), {}).get("progress", -cooldown)) < cooldown: return false
	return true

func _deliver(definition: Dictionary, context: Dictionary) -> Dictionary:
	if StringName(definition.get("id", &"")) == &"": return {}
	var store := _store()
	var delivered: Dictionary = store.delivered
	var sequence := int(store.get("sequence", 0)) + 1
	var message := {
		"id": StringName(definition.id), "instance_id": StringName("%s_%03d" % [definition.id, sequence]),
		"actor_id": StringName(definition.get("actor_id", &"SYSTEM")), "text": String(definition.get("text", "")),
		"priority": int(definition.get("priority", Priority.OPTIONAL)), "read": false,
		"delivered_at": Time.get_unix_time_from_system(), "trigger_context": context.duplicate(true),
	}
	var messages: Array = store.messages
	messages.append(message)
	while messages.size() > 32: messages.pop_front()
	delivered[String(definition.id)] = {"count": int(delivered.get(String(definition.id), {}).get("count", 0)) + 1, "progress": int(context.get("progress", 0))}
	store.merge({"messages": messages, "delivered": delivered, "sequence": sequence}, true)
	_commit(store)
	message_delivered.emit(message.duplicate(true))
	return message

func _store() -> Dictionary:
	if game_state == null: return {"messages": [], "delivered": {}, "sequence": 0}
	var store: Dictionary = game_state.world_state.get("social_inbox", {})
	if not store.has("messages"): store["messages"] = []
	if not store.has("delivered"): store["delivered"] = {}
	if not store.has("sequence"): store["sequence"] = 0
	game_state.world_state["social_inbox"] = store
	return store

func _commit(store: Dictionary) -> void:
	game_state.world_state["social_inbox"] = store
	game_state.emit_changed()
	inbox_changed.emit(view())
