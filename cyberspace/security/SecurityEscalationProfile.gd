class_name SecurityEscalationProfile
extends Resource

@export var thresholds: Dictionary = {&"LOW": 0, &"GUARDED": 2, &"ALERT": 5, &"HOSTILE": 9, &"SEVERE": 14, &"CRITICAL": 20, &"SHUTDOWN": 28}
@export var effects_by_level: Dictionary = {}

func level_for(count: int) -> SecuritySleeve.EscalationLevel:
	var result := SecuritySleeve.EscalationLevel.LOW
	for level: int in SecuritySleeve.EscalationLevel.values():
		var name := StringName(SecuritySleeve.EscalationLevel.keys()[level])
		if count >= int(thresholds.get(name, 0)): result = level as SecuritySleeve.EscalationLevel
	return result

func effects_for(level: SecuritySleeve.EscalationLevel) -> Array:
	return (effects_by_level.get(StringName(SecuritySleeve.EscalationLevel.keys()[level]), []) as Array).duplicate(true)
