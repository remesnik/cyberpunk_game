class_name SANDefenseCatalog
extends RefCounted

const ICE_WALL := &"ICE_WALL"
const WATCHDOG := &"WATCHDOG"
const LINK_SHIELD := &"LINK_SHIELD"

static func create_defaults() -> Array[SANDefenseDefinition]:
	var wall := SANDefenseDefinition.new(ICE_WALL, "ICE Wall", "Hardens SAN access paths against hostile security processes and intruders.")
	wall.behavior_flags.assign([&"ACCESS_CONTROL", &"HOSTILE_HACKER_RESISTANCE", &"ICE_RESISTANCE"])
	wall.access_resistance = 2; wall.hostile_hacker_resistance = 2; wall.ice_resistance = 3
	var watchdog := SANDefenseDefinition.new(WATCHDOG, "Watchdog", "Alerts the owning hacker when another actor touches the SAN.")
	watchdog.behavior_flags.assign([&"DETECTION", &"OWNER_ALERT"]); watchdog.detection_strength = 3
	var shield := SANDefenseDefinition.new(LINK_SHIELD, "Link Shield", "Filters hostile feedback before it reaches the physical deck.")
	shield.behavior_flags.assign([&"DECK_LINK_PROTECTION"]); shield.deck_damage_reduction = 3
	return [wall, watchdog, shield]
