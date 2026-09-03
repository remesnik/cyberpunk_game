class_name SANInteractionResult
extends RefCounted

var success := false
var reason := ""
var access_level := SANAccessSession.AccessLevel.NONE
var visible_data: Dictionary = {}
var transferred_entry: DeckStorageEntry
var events: Array[Dictionary] = []
var attacker_feedback: Array[String] = []
var victim_feedback: Array[String] = []
var damage_result: Dictionary = {}

static func denied(message: String) -> SANInteractionResult:
	var result := SANInteractionResult.new()
	result.reason = message
	return result
