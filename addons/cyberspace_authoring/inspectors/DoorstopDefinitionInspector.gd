@tool
class_name DoorstopDefinitionInspector
extends VBoxContainer

signal definition_changed(patch: Dictionary)

var _entry: Dictionary


func set_definition(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	_build()


func _build() -> void:
	for child in get_children(): child.queue_free()
	_section("IDENTITY")
	_readonly("INTERNAL ID", _entry.get("id", &""), "Stable runtime identifier. Rename references deliberately rather than editing this value in place.")
	_text("DISPLAY NAME", "display_name", _entry.get("display_name", "Doorstop"), "Player-facing program name.")
	_text("VERSION", "version", _entry.get("version", "1.0"), "Version distinguishes variants that may coexist in inventory.")
	_text("DESCRIPTION", "description", _entry.get("description", ""), "Player-facing purpose and limitations.")
	_text("RARITY", "rarity", _entry.get("rarity", &"COMMON"), "Content rarity label; for example COMMON, UNCOMMON, or RARE.")
	_section("PROGRAMMING")
	_number("PROGRAMMING DURATION", "programming_duration", float(_entry.get("programming_duration", 0.0)), 0.0, 86400.0, "Realtime seconds; never cyberspace ticks.")
	_resource_costs(_entry.get("programming_recipe", {}))
	_text("REQUIRED CAPABILITY", "required_programming_capability", _entry.get("required_programming_capability", &""), "Capability required to start this build.")
	_text("REQUIRED TOOL", "required_programming_tool", _entry.get("required_programming_tool", &""), "Deck module or software tool required by the recipe.")
	_list("PREREQUISITES", "programming_prerequisites", _entry.get("programming_prerequisites", []), "Comma-separated prerequisite flag IDs.")
	_section("DEPLOYMENT")
	_list("ALLOWED NODE TYPES", "allowed_node_types", _entry.get("allowed_node_types", []), "Empty allows every valid node type.")
	_list("PROHIBITED ENCOUNTER TAGS", "prohibited_encounter_tags", _entry.get("prohibited_encounter_tags", []), "Deployment is denied when any listed encounter tag is active.")
	_toggle("BURN ON DEPLOYMENT", "burn_on_deploy", bool(_entry.get("burn_on_deploy", true)), "Destroys only the activated ProgramInstance.")
	_toggle("ONE ACTIVE ANCHOR PER INTRUSION", "one_active_anchor_per_intrusion", bool(_entry.get("one_active_anchor_per_intrusion", true)), "Required by the current Doorstop runtime model.")
	_section("SUSPENSION")
	var policy: Dictionary = _entry.get("suspension_policy", {})
	_nested_toggle("PRESERVE TRACE", "preserve_trace", policy, true, "Trace is retained rather than reset.")
	_nested_number("TRACE INCREASE / SECOND", "trace_increase_per_second", policy, 0.0, 0.0, 100.0, "Optional realtime trace pressure while away.")
	_nested_toggle("PRESERVE ALARM STATE", "alarms_remain_active", policy, true, "Existing alarms remain authoritative.")
	_nested_toggle("ALLOW ICE MOVEMENT", "ice_may_reposition", policy, false, "Allows policy-driven ICE repositioning while suspended.")
	_nested_toggle("ALLOW SECURITY ESCALATION", "security_may_escalate", policy, false, "Allows network security level to rise over realtime.")
	_nested_toggle("TEMPORARY EFFECTS MAY EXPIRE", "temporary_effects_may_expire", policy, true, "Individual temporary effects count down according to their own rules.")
	_section("RETURN")
	_toggle("RETURN TO EXACT NODE", "return_to_exact_node", bool(_entry.get("return_to_exact_node", true)), "Required: callers cannot select a different re-entry node.")
	_toggle("DESTROY ANCHOR ON RETURN", "destroy_anchor_on_return", bool(_entry.get("destroy_anchor_on_return", true)), "Consumes the one-shot return route after Jack Back In.")


func _section(text: String) -> void:
	var label := Label.new(); label.text = text; label.add_theme_color_override("font_color", Color("56e8ff")); add_child(label)


func _readonly(label_text: String, value: Variant, tooltip: String) -> void:
	var label := Label.new(); label.text = "%s\n%s" % [label_text, value]; label.tooltip_text = tooltip; add_child(label)


func _text(label_text: String, key: String, value: Variant, tooltip: String) -> void:
	var field := LineEdit.new(); field.text = String(value); field.placeholder_text = label_text; field.tooltip_text = tooltip; add_child(field)
	field.text_submitted.connect(func(next): _emit_patch(key, next))


func _number(label_text: String, key: String, value: float, minimum: float, maximum: float, tooltip: String) -> void:
	var label := Label.new(); label.text = label_text; label.tooltip_text = tooltip; add_child(label)
	var field := SpinBox.new(); field.min_value = minimum; field.max_value = maximum; field.step = 0.1; field.value = value; field.tooltip_text = tooltip; add_child(field)
	field.value_changed.connect(func(next): _emit_patch(key, next))


func _toggle(label_text: String, key: String, value: bool, tooltip: String) -> void:
	var field := CheckBox.new(); field.text = label_text; field.button_pressed = value; field.tooltip_text = tooltip; add_child(field)
	field.toggled.connect(func(next): _emit_patch(key, next))


func _list(label_text: String, key: String, values: Array, tooltip: String) -> void:
	var field := LineEdit.new(); field.text = ", ".join(values); field.placeholder_text = label_text; field.tooltip_text = tooltip; add_child(field)
	field.text_submitted.connect(func(next):
		var parsed: Array[StringName] = []
		for part in next.split(","):
			var value := StringName(part.strip_edges())
			if not value.is_empty(): parsed.append(value)
		_emit_patch(key, parsed)
	)


func _resource_costs(costs: Dictionary) -> void:
	var values: PackedStringArray = []
	for id in costs: values.append("%s:%d" % [id, int(costs[id])])
	var field := LineEdit.new(); field.text = ", ".join(values); field.placeholder_text = "REQUIRED RESOURCES (ID:AMOUNT)"; field.tooltip_text = "Comma-separated resource costs, for example MEMORY_SHARD:2, ROUTING_KERNEL:1."; add_child(field)
	field.text_submitted.connect(func(next):
		var parsed: Dictionary = {}
		for part in next.split(","):
			var pair: PackedStringArray = part.split(":")
			if pair.size() == 2 and pair[0].strip_edges() != "": parsed[StringName(pair[0].strip_edges())] = maxi(0, int(pair[1]))
		_emit_patch("programming_recipe", parsed)
	)


func _nested_toggle(label_text: String, key: String, policy: Dictionary, fallback: bool, tooltip: String) -> void:
	var field := CheckBox.new(); field.text = label_text; field.button_pressed = bool(policy.get(key, fallback)); field.tooltip_text = tooltip; add_child(field)
	field.toggled.connect(func(next): _set_policy(key, next))


func _nested_number(label_text: String, key: String, policy: Dictionary, fallback: float, minimum: float, maximum: float, tooltip: String) -> void:
	var label := Label.new(); label.text = label_text; label.tooltip_text = tooltip; add_child(label)
	var field := SpinBox.new(); field.min_value = minimum; field.max_value = maximum; field.step = 0.01; field.value = float(policy.get(key, fallback)); field.tooltip_text = tooltip; add_child(field)
	field.value_changed.connect(func(next): _set_policy(key, next))


func _emit_patch(key: String, value: Variant) -> void:
	_entry[key] = value
	definition_changed.emit({key: value})


func _set_policy(key: String, value: Variant) -> void:
	var policy: Dictionary = _entry.get("suspension_policy", {}).duplicate(true)
	policy[key] = value; _entry["suspension_policy"] = policy
	definition_changed.emit({"suspension_policy": policy})
