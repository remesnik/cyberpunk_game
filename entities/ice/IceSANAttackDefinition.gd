class_name IceSANAttackDefinition
extends RefCounted

## Ordinary ICE leaves both flags false.
var san_attack_enabled := false
var deck_attack_enabled := false
var action_interval := 1
var integrity_damage := 0
var deck_breach_power := 0
var deck_breach_integrity_threshold := 0
var physical_deck_damage := 0
var component_degradation := 0
var temporary_disable_id: StringName
var temporary_disable_duration := 0.0
var program_corruption_count := 0
var force_disconnect_integrity_threshold := 0
var force_disconnect_on_san_destroy := true
