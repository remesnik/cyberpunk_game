class_name GameModeCondition
extends Resource

enum Availability { AVAILABLE_IN_ALL_MODES, STORY_ONLY, FREE_ROAM_ONLY, MODE_SPECIFIC_VARIANT }

@export var availability := Availability.AVAILABLE_IN_ALL_MODES
@export var mode_variants: Dictionary = {}

func is_satisfied(game_state: PersistentGameState) -> bool:
	if game_state == null: return false
	match availability:
		Availability.AVAILABLE_IN_ALL_MODES: return true
		Availability.STORY_ONLY: return game_state.get_game_mode() == GameMode.Value.STORY
		Availability.FREE_ROAM_ONLY: return game_state.get_game_mode() == GameMode.Value.FREE_ROAM
		Availability.MODE_SPECIFIC_VARIANT: return mode_variants.has(GameMode.to_id(game_state.get_game_mode())) or mode_variants.has(String(GameMode.to_id(game_state.get_game_mode())))
	return false

func resolve_variant(game_state: PersistentGameState, fallback: StringName = &"") -> StringName:
	if availability != Availability.MODE_SPECIFIC_VARIANT or game_state == null: return fallback
	var mode_id := GameMode.to_id(game_state.get_game_mode())
	return StringName(mode_variants.get(mode_id, mode_variants.get(String(mode_id), fallback)))

static func from_id(id: StringName, variants: Dictionary = {}) -> GameModeCondition:
	var condition := GameModeCondition.new()
	condition.availability = id_to_availability(id)
	condition.mode_variants = variants.duplicate(true)
	return condition

static func id_to_availability(id: StringName) -> Availability:
	match id:
		&"STORY_ONLY": return Availability.STORY_ONLY
		&"FREE_ROAM_ONLY": return Availability.FREE_ROAM_ONLY
		&"MODE_SPECIFIC_VARIANT": return Availability.MODE_SPECIFIC_VARIANT
		_: return Availability.AVAILABLE_IN_ALL_MODES

static func availability_to_id(value: Availability) -> StringName:
	return StringName(Availability.keys()[value])

