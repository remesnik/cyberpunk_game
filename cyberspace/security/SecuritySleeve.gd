class_name SecuritySleeve
extends RefCounted

signal changed(sleeve: SecuritySleeve)

enum State { INTACT, BREACHED, SPLIT, BYPASSED, DISABLED }
enum EscalationLevel { LOW, GUARDED, ALERT, HOSTILE, SEVERE, CRITICAL, SHUTDOWN }

var id: StringName = &""
var display_name := "Security Sleeve"
var current_members: Array[StringName] = []
var state := State.INTACT
var metadata: Dictionary = {}
var security_count := 0
var escalation_level := EscalationLevel.LOW
var security_events: Array[Dictionary] = []

func _init(p_id: StringName = &"", p_display_name := "Security Sleeve", p_current_members: Array[StringName] = [], p_state := State.INTACT) -> void:
	id = p_id
	display_name = p_display_name
	current_members = p_current_members.duplicate()
	state = p_state

func contains_node(node_id: StringName) -> bool:
	return current_members.has(node_id)

func add_current_member(node_id: StringName) -> bool:
	if node_id == &"" or current_members.has(node_id): return false
	current_members.append(node_id)
	current_members.sort()
	changed.emit(self)
	return true

func remove_current_member(node_id: StringName) -> bool:
	if not current_members.has(node_id): return false
	current_members.erase(node_id)
	changed.emit(self)
	return true

func set_state(next_state: State) -> void:
	if state == next_state: return
	state = next_state
	changed.emit(self)

func receive_security_event(event: Dictionary, profile: SecurityEscalationProfile) -> Dictionary:
	security_events.append(event.duplicate(true))
	security_count += maxi(1, int(event.get("severity", 1)))
	var previous := escalation_level
	escalation_level = profile.level_for(security_count)
	metadata["security_count"] = security_count
	metadata["escalation_level"] = StringName(EscalationLevel.keys()[escalation_level])
	metadata["last_security_event"] = event.duplicate(true)
	changed.emit(self)
	var effects: Array = []
	if previous != escalation_level:
		for crossed_level in range(int(previous) + 1, int(escalation_level) + 1):
			for effect: Dictionary in profile.effects_for(crossed_level as EscalationLevel):
				var tagged := effect.duplicate(true); tagged["escalation_level"] = StringName(EscalationLevel.keys()[crossed_level]); effects.append(tagged)
	return {"changed": previous != escalation_level, "previous_level": previous, "level": escalation_level, "effects": effects}
