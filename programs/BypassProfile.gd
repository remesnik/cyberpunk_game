class_name BypassProfile
extends Resource

@export_range(0, 20, 1) var defense_roll_min := 0
@export_range(0, 20, 1) var defense_roll_max := 2
@export_range(0, 10, 1) var default_player_stat := 2
@export_range(0, 100, 1) var security_alert_increase := 25
@export_range(0, 10, 1) var sleeve_response_increase := 1

func roll_defense(rng: RandomNumberGenerator) -> int:
	var low := mini(defense_roll_min, defense_roll_max)
	var high := maxi(defense_roll_min, defense_roll_max)
	return rng.randi_range(low, high)
