class_name ActiveBypassProgramCatalog
extends RefCounted

const IDS: Array[StringName] = [&"SLEEZE", &"DISGUISE"]
const PATHS := {&"SLEEZE": "res://data/programs/sleeze.tres", &"DISGUISE": "res://data/programs/disguise.tres"}

static func definition(id: StringName) -> ProgramDefinition:
	return load(String(PATHS[id])) as ProgramDefinition if PATHS.has(id) else null

static func all() -> Array[ProgramDefinition]:
	var result: Array[ProgramDefinition] = []
	for id: StringName in IDS: result.append(definition(id))
	return result
