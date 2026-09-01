class_name ConfrontationActionCatalog
extends RefCounted

static func create_definitions() -> Dictionary:
	return {
		ActionRequest.ActionType.DISRUPT: ConfrontationActionDefinition.new(ActionRequest.ActionType.DISRUPT, "Disrupt", 2, 1, [], 2, 1, [&"ICE"]),
		ActionRequest.ActionType.HIDE: ConfrontationActionDefinition.new(ActionRequest.ActionType.HIDE, "Hide", 1, 0, [CapabilityCatalog.GHOST], 30, 0, [&"SELF"]),
		ActionRequest.ActionType.SPOOF: ConfrontationActionDefinition.new(ActionRequest.ActionType.SPOOF, "Spoof Identity", 2, 1, [CapabilityCatalog.SPOOF], 35, 1, [&"ICE"]),
		ActionRequest.ActionType.ATTACK_PROCESS: ConfrontationActionDefinition.new(ActionRequest.ActionType.ATTACK_PROCESS, "Attack Process", 2, 1, [], 3, 2, [&"ICE"]),
		ActionRequest.ActionType.BREAK_LOCK: ConfrontationActionDefinition.new(ActionRequest.ActionType.BREAK_LOCK, "Break Lock", 2, 0, [CapabilityCatalog.DECRYPT], 1, 2, [&"LINK"]),
		ActionRequest.ActionType.REDIRECT: ConfrontationActionDefinition.new(ActionRequest.ActionType.REDIRECT, "Redirect", 2, 1, [CapabilityCatalog.SPOOF], 1, 1, [&"ICE"]),
		ActionRequest.ActionType.TRACE_SCRAMBLE: ConfrontationActionDefinition.new(ActionRequest.ActionType.TRACE_SCRAMBLE, "Trace Scramble", 2, 0, [CapabilityCatalog.TRACE_SCRAMBLER], 4, 0, [&"SELF"]),
		ActionRequest.ActionType.RETREAT: ConfrontationActionDefinition.new(ActionRequest.ActionType.RETREAT, "Retreat", 1, 1, [], 0, 1, [&"NODE"]),
	}
