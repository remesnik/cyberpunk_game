class_name PassiveUtilityCatalog
extends RefCounted

const IDS: Array[StringName] = [&"CRYPT", &"CULTERLY", &"HERMES", &"TAMTAMA", &"DISINF3CT", &"HYPERPIPER", &"SHAKESPEARE", &"LOCKJAW_O", &"SIDECAR_O", &"LOCKJAW_P", &"SIDECAR_P"]
const PATHS := {
	&"CRYPT": "res://data/programs/utilities/crypt.tres",
	&"CULTERLY": "res://data/programs/utilities/culterly.tres",
	&"HERMES": "res://data/programs/utilities/hermes.tres",
	&"TAMTAMA": "res://data/programs/utilities/tamtama.tres",
	&"DISINF3CT": "res://data/programs/utilities/disinf3ct.tres",
	&"HYPERPIPER": "res://data/programs/utilities/hyperpiper.tres",
	&"SHAKESPEARE": "res://data/programs/utilities/shakespeare.tres",
	&"LOCKJAW_O": "res://data/programs/utilities/lockjaw_o.tres",
	&"SIDECAR_O": "res://data/programs/utilities/sidecar_o.tres",
	&"LOCKJAW_P": "res://data/programs/utilities/lockjaw_p.tres",
	&"SIDECAR_P": "res://data/programs/utilities/sidecar_p.tres",
}

static func definition(id: StringName) -> PassiveUtilityDefinition:
	return load(String(PATHS[id])) as PassiveUtilityDefinition if PATHS.has(id) else null

static func all() -> Array[PassiveUtilityDefinition]:
	var result: Array[PassiveUtilityDefinition] = []
	for id: StringName in IDS: result.append(definition(id))
	return result

static func supporting(operation: StringName, service: StringName = &"") -> Array[PassiveUtilityDefinition]:
	return all().filter(func(definition: PassiveUtilityDefinition): return definition.supports(operation, service))
