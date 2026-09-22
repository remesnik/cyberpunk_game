class_name BypassResolver
extends RefCounted

enum Approach { CORRECT_EXPLOIT, STEALTH_PROGRAM, IDENTITY_PROGRAM, BARE_COMMAND }

var profile: BypassProfile

func _init(p_profile: BypassProfile = null) -> void:
	profile = p_profile if p_profile != null else BypassProfile.new()

func resolve(node: NetworkNodeDefinition, player_stat: int, selected: ProgramInstance, installed: bool, situational: Dictionary = {}, defense_roll: int = -1, rng: RandomNumberGenerator = null) -> Dictionary:
	var approach := _approach(node, selected, installed, situational)
	var rating := _effective_rating(node, selected, approach)
	var attack := maxi(0, player_stat) + rating + int(situational.get("attack_modifier", 0))
	var rolled := defense_roll
	if rolled < 0:
		var source := rng if rng != null else RandomNumberGenerator.new()
		if rng == null: source.randomize()
		rolled = profile.roll_defense(source)
	rolled = clampi(rolled, mini(profile.defense_roll_min, profile.defense_roll_max), maxi(profile.defense_roll_min, profile.defense_roll_max))
	var defense := maxi(0, node.difficulty_rating if node != null else 0) + rolled + int(situational.get("defense_modifier", 0))
	var succeeded := attack >= defense
	var noisy := approach == Approach.BARE_COMMAND or not succeeded
	var used := selected.instance_id if selected != null else &"BARE_COMMAND"
	var node_id := node.id if node != null else &""
	var reason := _reason(approach, succeeded)
	var security_event := _security_event(node_id, approach, succeeded, used) if noisy else {}
	return {
		"success": succeeded,
		"noisy": noisy,
		"attack_value": attack,
		"defense_value": defense,
		"defense_roll": rolled,
		"utility_or_program_used": used,
		"node": node_id,
		"reason": reason,
		"generated_security_event": security_event,
		"approach": Approach.keys()[approach],
		"player_stat": player_stat,
		"effective_rating": rating,
		"attack_modifier": int(situational.get("attack_modifier", 0)),
		"defense_modifier": int(situational.get("defense_modifier", 0)),
	}

func preview(node: NetworkNodeDefinition, player_stat: int, selected: ProgramInstance, installed: bool, situational: Dictionary = {}) -> Dictionary:
	var midpoint := roundi((profile.defense_roll_min + profile.defense_roll_max) * 0.5)
	var result := resolve(node, player_stat, selected, installed, situational, midpoint)
	result["preview"] = true
	result["defense_roll_range"] = [profile.defense_roll_min, profile.defense_roll_max]
	var fixed_defense := int(result.defense_value) - int(result.defense_roll)
	result["defense_value_range"] = [fixed_defense + profile.defense_roll_min, fixed_defense + profile.defense_roll_max]
	return result

func _approach(node: NetworkNodeDefinition, selected: ProgramInstance, installed: bool, situational: Dictionary) -> Approach:
	if not installed or selected == null or selected.definition == null: return Approach.BARE_COMMAND
	if selected.definition.is_passive_utility() and selected.definition.exploit_family_matches(node): return Approach.CORRECT_EXPLOIT
	if selected.definition.program_type == &"IDENTITY_BYPASS_PROGRAM":
		var operations: Array = situational.get("bypass_operations", [])
		for operation: Variant in operations:
			if selected.definition.supports_bypass_operation(StringName(operation)): return Approach.IDENTITY_PROGRAM
	if not selected.definition.is_passive_utility() and selected.definition.is_stealth_program(): return Approach.STEALTH_PROGRAM
	return Approach.BARE_COMMAND

func _effective_rating(node: NetworkNodeDefinition, selected: ProgramInstance, approach: Approach) -> int:
	if selected == null or selected.definition == null: return 0
	if approach == Approach.CORRECT_EXPLOIT: return selected.definition.effective_exploit_rating(node)
	if approach in [Approach.STEALTH_PROGRAM, Approach.IDENTITY_PROGRAM]: return maxi(0, selected.definition.utility_rating)
	return 0

func _reason(approach: Approach, succeeded: bool) -> String:
	if succeeded and approach == Approach.CORRECT_EXPLOIT: return "Compatible exploit bypassed node security quietly."
	if succeeded and approach == Approach.STEALTH_PROGRAM: return "Stealth program bypassed node security quietly."
	if succeeded and approach == Approach.IDENTITY_PROGRAM: return "Disguise established trusted identity quietly."
	if succeeded: return "Bare command bypass succeeded but exposed the intrusion."
	return "Bypass failed and node security reported the attempt."

func _security_event(node_id: StringName, approach: Approach, succeeded: bool, used: StringName) -> Dictionary:
	return {"type": &"BYPASS_SECURITY_EVENT", "node_id": node_id, "approach": Approach.keys()[approach], "bypass_succeeded": succeeded, "source_program_instance_id": used, "report_to_ice": true, "report_to_security_sleeve": true, "player_visible": true}
